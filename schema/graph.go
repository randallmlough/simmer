package schema

import (
	"github.com/randallmlough/simmer/importers"
	"go/types"
)

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

type Scalars []*Scalar

func (s Scalars) Scalar(name string) *Scalar {
	for _, scalar := range s {
		if scalar.Name == name {
			return scalar
		}
	}
	return nil
}

type Field struct {
	Name               string
	PluralName         string
	TypeWithoutPointer string
	IsPrimaryKey       bool
	IsRequired         bool
	IsPlural           bool
	// relation stuff
	IsRelation bool
	// boiler relation stuff is inside this field
	//BoilerField model.Field
	// graphql relation ship can be found here
	//Relationship *typ

	// Some stuff
	Description string
	Tag         string
	type_       types.Type
	package_    *types.Package
	imports     *importers.Set
}

func (f *Field) Type() string {
	if f.package_ != nil {
		f.imports.Add(f.package_.Path())
	}
	return f.type_.String()
}

func (f *Field) UnderlyingType() string {
	return f.type_.String()
}

type Imports struct {
	isStandardLib bool
	Package       *types.Package
}

func (i *Imports) String() string {
	if i.Package == nil {
		return ""
	}
	return i.Package.Path()
}
