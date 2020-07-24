package domaingen

import (
	"fmt"
	"github.com/99designs/gqlgen/codegen/config"
	"github.com/99designs/gqlgen/codegen/templates"
	"github.com/99designs/gqlgen/plugin"
	"github.com/randallmlough/simmer/graph"
	"github.com/vektah/gqlparser/v2/ast"
	"go/types"
	"path"
	"path/filepath"
	"sort"
)

type BuildMutateHook = func(b *ModelBuild) *ModelBuild

func defaultBuildMutateHook(b *ModelBuild) *ModelBuild {
	return b
}

type ModelBuild struct {
	PackageName string
	Interfaces  []*graph.Interface
	Models      []*graph.Object
	Enums       []*graph.Enum
	Scalars     []string
}

func New(cfg Config, mutateHook BuildMutateHook) plugin.Plugin {
	if mutateHook == nil {
		mutateHook = defaultBuildMutateHook
	}
	return &Plugin{
		Cfg:        &cfg,
		MutateHook: mutateHook,
	}
}

type Config struct {
	IsModel          bool
	DirectiveName    string // domain or model
	Directory        string
	PackageName      string
	DefaultGroupName string
}

type Plugin struct {
	Cfg        *Config
	MutateHook BuildMutateHook
}

var _ plugin.ConfigMutator = &Plugin{}

func (m *Plugin) Name() string {
	return "domaingen"
}

type Groups map[string]*ModelBuild

func (g Groups) newGroup(groupName, packageName string) {
	g[groupName] = &ModelBuild{
		PackageName: packageName,
	}
}
func (m *Plugin) MutateConfig(cfg *config.Config) error {
	binder := cfg.NewBinder()
	var (
		modelDir,
		defaultGroup,
		packageName string
	)
	if m.Cfg != nil {
		modelDir = m.Cfg.Directory
		defaultGroup = m.Cfg.DefaultGroupName
		packageName = m.Cfg.PackageName
	} else {
		modelDir, defaultGroup = filepath.Split(cfg.Model.Filename)
		packageName = cfg.Model.Package
	}
	groups := make(Groups)

	hasEntity := false
	for _, schemaType := range cfg.Schema.Types {
		if cfg.Models.UserDefined(schemaType.Name) {
			continue
		}
		dirs := schemaType.Directives
		group := defaultGroup
		if dir := dirs.ForName("simmer"); dir != nil && dir.Arguments != nil {
			if m.Cfg.IsModel && dir.Arguments.ForName("skipModel") != nil {
				if dir.Arguments.ForName("skipModel").Value.Raw == "true" {
					continue
				}
			}
			if v := dir.Arguments.ForName("group"); v != nil {
				group = v.Value.Raw
			}
		}

		if _, ok := groups[group]; !ok {
			groups.newGroup(group, packageName)
		}

		switch schemaType.Kind {
		case ast.Interface, ast.Union:
			it := &graph.Interface{
				Description: schemaType.Description,
				Name:        schemaType.Name,
				//Directives:  dirs,
			}
			groups[group].Interfaces = append(groups[group].Interfaces, it)
		case ast.Object, ast.InputObject:
			if schemaType == cfg.Schema.Query || schemaType == cfg.Schema.Mutation || schemaType == cfg.Schema.Subscription {
				continue
			}

			it := &graph.Object{
				Description: schemaType.Description,
				Name:        schemaType.Name,
				//Directives:  schemaType.Directives,
			}

			for _, implementor := range cfg.Schema.GetImplements(schemaType) {
				it.Implements = append(it.Implements, implementor.Name)
			}

			for _, field := range schemaType.Fields {
				var typ types.Type
				fieldDef := cfg.Schema.Types[field.Type.Name()]

				if cfg.Models.UserDefined(field.Type.Name()) {
					var err error
					typ, err = binder.FindTypeFromName(cfg.Models[field.Type.Name()].Model[0])
					if err != nil {
						return err
					}
				} else {
					switch fieldDef.Kind {
					case ast.Scalar:
						// no user defined model, referencing a default scalar
						typ = types.NewNamed(
							types.NewTypeName(0, cfg.Model.Pkg(), "string", nil),
							nil,
							nil,
						)

					case ast.Interface, ast.Union:
						// no user defined model, referencing a generated interface type
						typ = types.NewNamed(
							types.NewTypeName(0, cfg.Model.Pkg(), templates.ToGo(field.Type.Name()), nil),
							types.NewInterfaceType([]*types.Func{}, []types.Type{}),
							nil,
						)

					case ast.Enum:
						// no user defined model, must reference a generated enum
						typ = types.NewNamed(
							types.NewTypeName(0, cfg.Model.Pkg(), templates.ToGo(field.Type.Name()), nil),
							nil,
							nil,
						)

					case ast.Object, ast.InputObject:
						// no user defined model, must reference a generated struct
						typ = types.NewNamed(
							types.NewTypeName(0, cfg.Model.Pkg(), templates.ToGo(field.Type.Name()), nil),
							types.NewStruct(nil, nil),
							nil,
						)

					default:
						panic(fmt.Errorf("unknown ast type %s", fieldDef.Kind))
					}
				}

				name := field.Name
				if nameOveride := cfg.Models[schemaType.Name].Fields[field.Name].FieldName; nameOveride != "" {
					name = nameOveride
				}

				typ = binder.CopyModifiersFromAst(field.Type, typ)

				if isStruct(typ) && (fieldDef.Kind == ast.Object || fieldDef.Kind == ast.InputObject) {
					typ = types.NewPointer(typ)
				}

				it.Fields = append(it.Fields, &graph.Field{
					Name:        name,
					Type:        typ,
					Description: field.Description,
					Tag:         `json:"` + field.Name + `"`,
				})
			}

			groups[group].Models = append(groups[group].Models, it)
		case ast.Enum:
			it := &graph.Enum{
				Name:        schemaType.Name,
				Description: schemaType.Description,
				//Directives:  schemaType.Directives,
			}

			for _, v := range schemaType.EnumValues {
				it.Values = append(it.Values, &graph.EnumValue{
					Name:        v.Name,
					Description: v.Description,
				})
			}

			groups[group].Enums = append(groups[group].Enums, it)
		case ast.Scalar:
			groups[defaultGroup].Scalars = append(groups[defaultGroup].Scalars, schemaType.Name)
		}
	}

	for group, build := range groups {
		if hasEntity {
			it := &graph.Interface{
				Description: "_Entity represents all types with @key",
				Name:        "_Entity",
			}
			build.Interfaces = append(build.Interfaces, it)
		}
		sort.Slice(build.Enums, func(i, j int) bool { return build.Enums[i].Name < build.Enums[j].Name })
		sort.Slice(build.Models, func(i, j int) bool { return build.Models[i].Name < build.Models[j].Name })
		sort.Slice(build.Interfaces, func(i, j int) bool { return build.Interfaces[i].Name < build.Interfaces[j].Name })

		for _, it := range build.Enums {
			cfg.Models.Add(it.Name, cfg.Model.ImportPath()+"."+templates.ToGo(it.Name))
		}
		for _, it := range build.Models {
			cfg.Models.Add(it.Name, cfg.Model.ImportPath()+"."+templates.ToGo(it.Name))
		}
		for _, it := range build.Interfaces {
			cfg.Models.Add(it.Name, cfg.Model.ImportPath()+"."+templates.ToGo(it.Name))
		}
		for _, it := range build.Scalars {
			cfg.Models.Add(it, "github.com/99designs/gqlgen/graphql.String")
		}

		if len(build.Models) == 0 && len(build.Enums) == 0 && len(build.Interfaces) == 0 && len(build.Scalars) == 0 {
			return nil
		}

		if m.MutateHook != nil {
			build = m.MutateHook(build)
		}

		filename := group
		if path.Ext(group) == "" {
			filename += ".go"
		}
		if err := templates.Render(templates.Options{
			PackageName:     packageName,
			Filename:        path.Join(modelDir, filename),
			Data:            build,
			GeneratedHeader: false,
			Packages:        cfg.Packages,
		}); err != nil {
			return err
		}
	}
	return nil
}

func isStruct(t types.Type) bool {
	_, is := t.Underlying().(*types.Struct)
	return is
}
