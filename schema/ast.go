package schema

import (
	"github.com/pkg/errors"
	"github.com/vektah/gqlparser/v2"
	"github.com/vektah/gqlparser/v2/ast"
	"github.com/vektah/gqlparser/v2/gqlerror"
	"github.com/vektah/gqlparser/v2/parser"
	"github.com/vektah/gqlparser/v2/validator"
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

var path2regex = strings.NewReplacer(
	`.`, `\.`,
	`*`, `.+`,
	`\`, `[\\/]`,
	`/`, `[\\/]`,
)

// filesToAstSources parses the provided file list and returns a slice of sources
func filesToAstSources(files ...string) ([]*ast.Source, error) {

	var err error
	sourceList := list{}
	for _, f := range files {
		var matches []string

		// for ** we want to override default globbing patterns and walk all
		// subdirectories to match schema files.
		if strings.Contains(f, "**") {
			pathParts := strings.SplitN(f, "**", 2)
			rest := strings.TrimPrefix(strings.TrimPrefix(pathParts[1], `\`), `/`)
			// turn the rest of the glob into a regex, anchored only at the end because ** allows
			// for any number of dirs in between and walk will let us match against the full path name
			globRe := regexp.MustCompile(path2regex.Replace(rest) + `$`)

			if err := filepath.Walk(pathParts[0], func(path string, info os.FileInfo, err error) error {
				if err != nil {
					return err
				}

				if globRe.MatchString(strings.TrimPrefix(path, pathParts[0])) {
					matches = append(matches, path)
				}

				return nil
			}); err != nil {
				return nil, errors.Wrapf(err, "failed to walk schema at root %s", pathParts[0])
			}
		} else {
			matches, err = filepath.Glob(f)
			if err != nil {
				return nil, errors.Wrapf(err, "failed to glob schema filename %s", f)
			}
		}

		for _, m := range matches {
			if sourceList.has(m) {
				continue
			}
			sourceList = append(sourceList, m)
		}
	}

	sources := make([]*ast.Source, 0, len(sourceList))
	for _, filename := range sourceList {
		filename = filepath.ToSlash(filename)
		var err error
		var schemaRaw []byte
		schemaRaw, err = ioutil.ReadFile(filename)
		if err != nil {
			return nil, errors.Wrap(err, "unable to open schema")
		}

		sources = append(sources, &ast.Source{Name: filename, Input: string(schemaRaw)})
	}

	return sources, nil
}

type list []string

func (ff list) has(file string) bool {
	for _, existing := range ff {
		if existing == file {
			return true
		}
	}
	return false
}

type Source struct {
	source *ast.Source
}

func astSourceToAstSchema(sources ...*ast.Source) (*ast.Schema, error) {

	schema, err := gqlparser.LoadSchema(sources...)
	if err != nil {
		return nil, errors.Wrap(err, "failed to load schema")
	}

	if schema.Query == nil {
		schema.Query = &ast.Definition{
			Kind: ast.Object,
			Name: "Query",
		}
		schema.Types["Query"] = schema.Query
	}

	return schema, nil
}

func sourceToSchemaDoc(inputs ...*ast.Source) (*ast.SchemaDocument, error) {
	schemaDoc, err := parser.ParseSchemas(append([]*ast.Source{validator.Prelude}, inputs...)...)
	if err != nil {
		return nil, errors.Wrap(err, "failed to parse source")
	}
	return schemaDoc, nil
}

func astSchemaDocToAstSchema(doc *ast.SchemaDocument) (*ast.Schema, error) {
	schema := ast.Schema{
		Types:         map[string]*ast.Definition{},
		Directives:    map[string]*ast.DirectiveDefinition{},
		PossibleTypes: map[string][]*ast.Definition{},
		Implements:    map[string][]*ast.Definition{},
	}

	for i, def := range doc.Definitions {
		if schema.Types[def.Name] != nil {
			return nil, gqlerror.ErrorPosf(def.Position, "Cannot redeclare type %s.", def.Name)
		}
		schema.Types[def.Name] = doc.Definitions[i]
	}

	defs := append(ast.DefinitionList{}, doc.Definitions...)

	for _, ext := range doc.Extensions {
		def := schema.Types[ext.Name]
		if def == nil {
			schema.Types[ext.Name] = &ast.Definition{
				Kind:     ext.Kind,
				Name:     ext.Name,
				Position: ext.Position,
			}
			def = schema.Types[ext.Name]
			defs = append(defs, def)
		}

		if def.Kind != ext.Kind {
			return nil, gqlerror.ErrorPosf(ext.Position, "Cannot extend type %s because the base type is a %s, not %s.", ext.Name, def.Kind, ext.Kind)
		}

		def.Directives = append(def.Directives, ext.Directives...)
		def.Interfaces = append(def.Interfaces, ext.Interfaces...)
		def.Fields = append(def.Fields, ext.Fields...)
		def.Types = append(def.Types, ext.Types...)
		def.EnumValues = append(def.EnumValues, ext.EnumValues...)
	}

	for _, def := range defs {
		switch def.Kind {
		case ast.Union:
			for _, t := range def.Types {
				schema.AddPossibleType(def.Name, schema.Types[t])
				schema.AddImplements(t, def)
			}
		case ast.InputObject, ast.Object:
			for _, intf := range def.Interfaces {
				schema.AddPossibleType(intf, def)
				schema.AddImplements(def.Name, schema.Types[intf])
			}
			schema.AddPossibleType(def.Name, def)
		}
	}

	for i, dir := range doc.Directives {
		if schema.Directives[dir.Name] != nil {
			return nil, gqlerror.ErrorPosf(dir.Position, "Cannot redeclare directive %s.", dir.Name)
		}
		schema.Directives[dir.Name] = doc.Directives[i]
	}

	if len(doc.Schema) > 1 {
		return nil, gqlerror.ErrorPosf(doc.Schema[1].Position, "Cannot have multiple schema entry points, consider schema extensions instead.")
	}

	if len(doc.Schema) == 1 {
		for _, entrypoint := range doc.Schema[0].OperationTypes {
			def := schema.Types[entrypoint.Type]
			if def == nil {
				return nil, gqlerror.ErrorPosf(entrypoint.Position, "Schema root %s refers to a type %s that does not exist.", entrypoint.Operation, entrypoint.Type)
			}
			switch entrypoint.Operation {
			case ast.Query:
				schema.Query = def
			case ast.Mutation:
				schema.Mutation = def
			case ast.Subscription:
				schema.Subscription = def
			}
		}
	}

	for _, ext := range doc.SchemaExtension {
		for _, entrypoint := range ext.OperationTypes {
			def := schema.Types[entrypoint.Type]
			if def == nil {
				return nil, gqlerror.ErrorPosf(entrypoint.Position, "Schema root %s refers to a type %s that does not exist.", entrypoint.Operation, entrypoint.Type)
			}
			switch entrypoint.Operation {
			case ast.Query:
				schema.Query = def
			case ast.Mutation:
				schema.Mutation = def
			case ast.Subscription:
				schema.Subscription = def
			}
		}
	}

	if schema.Query == nil && schema.Types["Query"] != nil {
		schema.Query = schema.Types["Query"]
	}

	if schema.Mutation == nil && schema.Types["Mutation"] != nil {
		schema.Mutation = schema.Types["Mutation"]
	}

	if schema.Subscription == nil && schema.Types["Subscription"] != nil {
		schema.Subscription = schema.Types["Subscription"]
	}

	if schema.Query != nil {
		schema.Query.Fields = append(
			schema.Query.Fields,
			&ast.FieldDefinition{
				Name: "__schema",
				Type: ast.NonNullNamedType("__Schema", nil),
			},
			&ast.FieldDefinition{
				Name: "__type",
				Type: ast.NamedType("__Type", nil),
				Arguments: ast.ArgumentDefinitionList{
					{Name: "name", Type: ast.NonNullNamedType("String", nil)},
				},
			},
		)
	}

	return &schema, nil
}
