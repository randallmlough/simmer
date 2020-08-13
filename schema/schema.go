package schema

import (
	"github.com/pkg/errors"
	"github.com/vektah/gqlparser/v2/ast"
	"strings"
)

type Schema struct {
	Methods    []*Method
	Interfaces []*Interface
	Objects    []*Object
	Inputs     []*Object
	Enums      []*Enum
	Scalars    Scalars

	Types   Types
	sources []*ast.Source
	schema  *ast.Schema
}

func New(schemaFiles []string) (*Schema, error) {

	s, err := loadSchema(schemaFiles)
	if err != nil {
		return nil, errors.Wrap(err, "failed to parse schema file(s)")
	}

	s.Types, err = gatherTypes(s)
	if err != nil {
		return nil, errors.Wrap(err, "failed to gather schema types")
	}

	return s, nil
}

func loadSchema(files []string) (*Schema, error) {

	sources, err := filesToAstSources(files...)
	if err != nil {
		return nil, errors.Wrap(err, "failed to parse schema file(s)")
	}

	schema, err := astSourceToAstSchema(sources...)
	if err != nil {
		return nil, errors.Wrap(err, "failed to load schema")
	}

	interfaces, enums, scalars := getExtrasFromSchema(schema)
	return &Schema{
		Interfaces: interfaces,
		Enums:      enums,
		Scalars:    scalars,
		sources:    sources,
		schema:     schema,
	}, nil
}

func (s *Schema) separateTypes() (types []*ast.Source) {
	for _, source := range s.sources {
		if strings.Contains(source.Name, "types") {
			types = append(types, source)
		}
	}
	return
}

func getExtrasFromSchema(schema *ast.Schema) (interfaces []*Interface, enums []*Enum, scalars []*Scalar) {
	for _, schemaType := range schema.Types {
		switch schemaType.Kind {
		case ast.Interface, ast.Union:
			interfaces = append(interfaces, &Interface{
				Description: schemaType.Description,
				Name:        schemaType.Name,
			})
		case ast.Enum:
			it := &Enum{
				Name:        schemaType.Name,
				Description: schemaType.Description,
			}
			for _, v := range schemaType.EnumValues {
				it.Values = append(it.Values, &EnumValue{
					Name:        v.Name,
					Description: v.Description,
				})
			}
			if strings.HasPrefix(it.Name, "_") {
				continue
			}
			enums = append(enums, it)
		case ast.Scalar:
			it := &Scalar{
				IsCustom:    scalarIsCustom(schemaType.Name),
				Name:        schemaType.Name,
				Description: schemaType.Description,
			}
			if strings.HasPrefix(it.Name, "_") {
				continue
			}
			scalars = append(scalars, it)
		}
	}
	return
}
func scalarIsCustom(scalar string) bool {
	switch scalar {
	case "Float", "Int", "Any", "Boolean", "String", "Time", "Map", "Upload", "ID":
		return false
	}
	return true
}
