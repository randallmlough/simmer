package graph

import (
	"github.com/vektah/gqlparser/v2/ast"
	"go/types"
	"strings"
)

type Schema struct {
	Type     Object
	Inputs   []Object
	Payloads []Object
}

type Object struct {
	Description string
	Name        string
	Fields      []*Field
	Implements  []string
}

type Interface struct {
	Description string
	Name        string
}

type Enum struct {
	Description string
	Name        string
	Values      []*EnumValue
}

type EnumValue struct {
	Description string
	Name        string
	NameLower   string
}

type Scalar struct {
	IsCustom    bool
	Description string
	Name        string
}

type Field struct {
	Name               string
	PluralName         string
	TypeWithoutPointer string
	IsNumberID         bool
	IsPrimaryNumberID  bool
	IsPrimaryID        bool
	IsRequired         bool
	IsPlural           bool
	// relation stuff
	IsRelation bool
	// boiler relation stuff is inside this field
	//BoilerField model.Field
	// graphql relation ship can be found here
	Relationship *Type
	IsOr         bool
	IsAnd        bool

	// Some stuff
	Description string
	Type        types.Type
	Tag         string
}

type Type struct {
	Name                  string
	PluralName            string
	PrimaryKeyType        string
	Fields                []*Field
	IsNormal              bool
	IsInput               bool
	IsCreateInput         bool
	IsUpdateInput         bool
	IsNormalInput         bool
	IsPayload             bool
	IsWhere               bool
	IsFilter              bool
	IsPreloadable         bool
	HasOrganizationID     bool
	HasUserOrganizationID bool
	HasUserID             bool
	HasStringPrimaryID    bool
	// other stuff
	Description string
	PureFields  []*ast.FieldDefinition
	Implements  []string
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
