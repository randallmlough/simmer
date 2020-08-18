package schema

import (
	"fmt"
	"github.com/pkg/errors"
	"github.com/randallmlough/simmer/importers"
	"github.com/randallmlough/simmer/templates"
	"github.com/vektah/gqlparser/v2/ast"
	"go/types"
	"path/filepath"
	"sort"
	"strings"
)

type Type struct {
	Type       *Object
	Methods    []Method
	Interfaces []*Interface
	Objects    []*Object
	Inputs     []*Object
	Enums      []*Enum
	Scalars    []*Scalar

	source   *ast.Source
	schema   *ast.Schema
	Imports  *importers.Set
	package_ types.Package
}

type Method struct {
	Name       string
	Type       string
	Args       []FuncType
	Return     FuncType
	definition *ast.Definition
}

type FuncType struct {
	Name       string
	Type       string
	IsRequired bool
	IsSlice    bool
}

type Types []Type

func (t Types) Type(name string) *Type {
	for _, t := range t {
		if t.Type != nil {
			if strings.ToLower(t.Type.Name) == strings.ToLower(name) {
				return &t
			}
		}

	}
	return nil
}

func gatherTypes(schema *Schema) ([]Type, error) {

	typesSources := schema.separateTypes()

	var typs []Type
	for _, source := range typesSources {
		t := &Type{Imports: schema.imports, source: source}
		err := t.construct(schema)
		if err != nil {
			return nil, errors.Wrap(err, "failed to build type")
		}
		typs = append(typs, *t)
	}
	return typs, nil
}

func (t *Type) construct(parentSchema *Schema) error {
	ast, err := sourceToSchemaDoc(t.source)
	if err != nil {
		return errors.Wrapf(err, "failed to parse schema source %s", t.source.Name)
	}
	schema, err := astSchemaDocToAstSchema(ast)
	if err != nil {
		return errors.Wrapf(err, "failed to validate %s", t.source.Name)
	}

	objs := t.objects(parentSchema.schema, schema)

	_, anchorTypeName := filepath.Split(t.source.Name)
	anchorTypeName = strings.ReplaceAll(anchorTypeName, ".graphql", "")

	anchorObject, objects, inputs := objs.split(anchorTypeName)
	interfaces, enums, scalars := getExtrasFromSchema(schema)

	sort.Slice(enums, func(i, j int) bool { return enums[i].Name < enums[j].Name })
	sort.Slice(objects, func(i, j int) bool { return objects[i].Name < objects[j].Name })
	sort.Slice(inputs, func(i, j int) bool { return inputs[i].Name < inputs[j].Name })
	sort.Slice(interfaces, func(i, j int) bool { return interfaces[i].Name < interfaces[j].Name })

	methods := getMethods(schema)

	t.Type = anchorObject
	t.Methods = methods
	t.Interfaces = interfaces
	t.Objects = objects
	t.Inputs = inputs
	t.Enums = enums
	t.Scalars = scalars
	t.schema = schema
	return nil
}

func (t *Type) objects(parentSchema, schema *ast.Schema) (objects Objects) {
	for _, schemaType := range schema.Types {
		if schemaType == schema.Query || schemaType == schema.Mutation || schemaType == schema.Subscription {
			continue
		}
		objectName := schemaType.Name

		if strings.HasPrefix(objectName, "_") {
			continue
		}

		switch schemaType.Kind {
		case ast.Object, ast.InputObject:

			object := &Object{
				Description: schemaType.Description,
				Name:        objectName,
			}

			for _, implementor := range schema.GetImplements(schemaType) {
				object.Implements = append(object.Implements, implementor.Name)
			}

			object.Fields = t.fields(parentSchema, schemaType.Fields)

			if schemaType.Kind == ast.InputObject {
				object.isInput = true
			}
			objects = append(objects, object)

		}
	}
	return
}

func (t *Type) fields(schema *ast.Schema, fields ast.FieldList) []*Field {
	f := make([]*Field, 0, len(fields))
	for _, field := range fields {
		var typ types.Type
		var pkg *types.Package
		fieldDef := schema.Types[field.Type.Name()]
		fieldType := templates.ToGo(field.Type.Name())
		pkg, fieldType = gqlToGoPackage(fieldType)

		switch fieldDef.Kind {
		case ast.Scalar:
			// no user defined model, referencing a default scalar
			typ = types.NewNamed(
				types.NewTypeName(0, pkg, fieldType, nil),
				nil,
				nil,
			)

		case ast.Interface, ast.Union:
			// no user defined model, referencing a generated interface type
			typ = types.NewNamed(
				types.NewTypeName(0, pkg, fieldType, nil),
				types.NewInterfaceType([]*types.Func{}, []types.Type{}),
				nil,
			)

		case ast.Enum:
			// no user defined model, must reference a generated enum
			typ = types.NewNamed(
				types.NewTypeName(0, pkg, fieldType, nil),
				nil,
				nil,
			)

		case ast.Object, ast.InputObject:
			// no user defined model, must reference a generated struct
			typ = types.NewNamed(
				types.NewTypeName(0, pkg, fieldType, nil),
				types.NewStruct(nil, nil),
				nil,
			)

		default:
			panic(fmt.Errorf("unknown ast type %s", fieldDef.Kind))
		}

		if isStruct(typ) && (fieldDef.Kind == ast.Object || fieldDef.Kind == ast.InputObject) {
			typ = types.NewPointer(typ)
		} else if !field.Type.NonNull {
			typ = types.NewPointer(typ)
		}

		name := field.Name
		f = append(f, &Field{
			Name:         name,
			type_:        typ,
			IsPrimaryKey: templates.ToGo(field.Type.Name()) == "ID",
			IsRelation:   fieldDef.Kind == ast.Object || fieldDef.Kind == ast.InputObject,
			IsRequired:   field.Type.NonNull,
			Description:  field.Description,
			package_:     pkg,
			imports:      t.Imports,
		})
	}
	return f
}

func gqlToGoPackage(field string) (pkg *types.Package, typ string) {
	switch field {
	case "Float":
		typ = "float64"
	case "Any":
		typ = "interface{}"
	case "Map":
		typ = "map[string]interface{}"
	case "ID":
		typ = "string"
	case "Time":
		pkg = types.NewPackage("time", "time")
		typ = "Time"
	case "String":
		typ = "string"
	case "Boolean":
		typ = "bool"
	case "Int":
		typ = "int"
	default:
		return nil, field
	}
	return
}

func isBuiltin(typ string) bool {
	switch typ {
	case "bool",
		"int",
		"int8",
		"int16",
		"int32",
		"int64",
		"uint",
		"uint8",
		"uint16",
		"uint32",
		"uint64",
		"float32",
		"float64",
		"string",
		"time":
		return true
	}
	return false
}
func isStruct(t types.Type) bool {
	_, is := t.Underlying().(*types.Struct)
	return is
}

func getMethods(schema *ast.Schema) []Method {
	var mm []Method

	// query methods
	if q := schema.Query; q != nil {
		mm = append(mm, methods(q)...)
	}

	// mutation methods
	if m := schema.Mutation; m != nil {
		mm = append(mm, methods(m)...)
	}

	// subscription methods
	if s := schema.Subscription; s != nil {
		mm = append(mm, methods(s)...)
	}

	return mm
}

func methods(def *ast.Definition) []Method {
	var methods []Method
	for _, f := range def.Fields {
		if f.Name == "__schema" || f.Name == "__type" {
			continue
		}

		methods = append(methods, Method{
			Name:       f.Name,
			Type:       def.Name,
			Args:       methodArgs(f.Arguments),
			Return:     methodReturnTypes(f.Type),
			definition: def,
		})
	}
	return methods
}

func methodArgs(argList ast.ArgumentDefinitionList) []FuncType {
	var args []FuncType
	for _, arg := range argList {
		args = append(args, FuncType{
			Name:       strings.ToLower(arg.Name),
			Type:       arg.Type.NamedType,
			IsRequired: arg.Type.NonNull,
			IsSlice:    isSlice(arg.Name),
		})
	}
	return args
}

func isSlice(value string) bool {
	value = strings.Trim(value, "!")
	return strings.HasPrefix(value, "[") &&
		strings.HasSuffix(value, "]")
}

func methodReturnTypes(v *ast.Type) FuncType {
	isSlice := isSlice(v.String())
	typ := v.NamedType
	if isSlice {
		typ = v.Elem.NamedType
	}
	return FuncType{
		Name:       strings.ToLower(v.Name()),
		Type:       typ,
		IsRequired: v.NonNull,
		IsSlice:    isSlice,
	}
}
