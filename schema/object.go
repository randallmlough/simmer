package schema

import (
	"github.com/iancoleman/strcase"
	"strings"
)

type Object struct {
	Description string
	Name        string
	Fields      []*Field
	Implements  []string
	isInput     bool
}

type Objects []*Object

func (o Objects) split(anchorTypeName string) (anchorType *Object, objects []*Object, inputs []*Object) {
	for _, object := range o {
		if strings.ToLower(object.Name) == anchorTypeName {
			anchorType = object
		} else if object.isInput {
			inputs = append(inputs, object)
		} else {
			objects = append(objects, object)

		}
	}
	return anchorType, objects, inputs
}

//func (o Objects) imports() *importers.Set {
//	set := new(importers.Set)
//	for _, object := range o {
//		for _, field := range object.Fields {
//			if imp := field.imports; imp != nil {
//				if imp.Package != nil {
//					pkg := fmt.Sprintf(`"%s"`, imp.Package.Path())
//					if imp.isStandardLib {
//						set.Standard = append(set.Standard, pkg)
//					} else {
//						set.ThirdParty = append(set.ThirdParty, pkg)
//					}
//				}
//			}
//		}
//	}
//	return set
//}

func getGraphTypeAsText(graphType string) string {
	if strings.HasPrefix(graphType, "*") {
		graphType = strings.TrimPrefix(graphType, "*")
		graphType = strcase.ToCamel(graphType)
		graphType = "Pointer" + graphType
	}
	return strcase.ToCamel(graphType)
}
