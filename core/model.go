package core

import (
	"fmt"
	"github.com/iancoleman/strcase"
	"github.com/randallmlough/simmer/database"
	"github.com/randallmlough/simmer/importers"
	"github.com/randallmlough/simmer/schema"
	"github.com/randallmlough/simmer/templates"
	"github.com/volatiletech/strmangle"
	"strings"
)

type Model struct {
	Name    string
	Table   database.Table
	Schema  schema.Type
	imports *importers.Set
}

func (m *Model) HasModel() bool {
	return m.Table.Name != ""
}

func (m *Model) HasObject() bool {
	return m.Table.Name != "" && m.Schema.Type != nil
}

func (m *Model) Object() *Object {
	obj := &Object{Name: m.Name, imports: m.imports}
	obj.translateFields(m.Table.Columns, m.Schema.Type.Fields)
	return obj
}

// Object will exist if a model has both a matching table and schema
type Object struct {
	Name    string
	Fields  []ObjectField
	imports *importers.Set
}

func (o *Object) translateFields(columns database.ColumnList, schemaFields []*schema.Field) {
	fieldMap := make(map[string]ObjectField)
	for _, column := range columns {
		name := strmangle.CamelCase(column.Name)
		if f, exists := fieldMap[name]; exists {
			f.TableField = column
			fieldMap[name] = f
		} else {
			fieldMap[name] = ObjectField{
				TableField: column,
			}
		}
	}
	for _, schemaField := range schemaFields {
		if f, exists := fieldMap[schemaField.Name]; exists {
			f.SchemaField = *schemaField
			fieldMap[schemaField.Name] = f
		} else {
			fieldMap[schemaField.Name] = ObjectField{
				SchemaField: *schemaField,
			}
		}
	}
	var fields []ObjectField
	for _, field := range fieldMap {
		if field.TableField.Name == "" || field.SchemaField.Name == "" {
			continue
		} else {
			field.imports = o.imports
			fields = append(fields, field)
		}
	}
	o.Fields = fields
}

// Object will exist if a model has both a matching table and schema
type ObjectField struct {
	SchemaField schema.Field
	TableField  database.Column
	imports     *importers.Set
}

func (f ObjectField) ToTableField(variable string) string {
	var fieldConversion string
	if isBuiltin(f.TableField.Type) && f.SchemaField.IsRequired {
		return fmt.Sprintf("%s.%s", variable, templates.ToGo(f.SchemaField.Name))
	} else {
		funcName := getToTableColumn(getColumnTypeAsText(f.TableField.Type), getObjectFieldAsText(f.SchemaField.UnderlyingType()))
		fieldConversion = "utils." + fmt.Sprintf("%s(%s.%s)", funcName, variable, templates.ToGo(f.SchemaField.Name))
		f.imports.Add("github.com/randallmlough/simmer/utils")
	}
	return fieldConversion
}

func (f ObjectField) ToObjectField(variable string) string {
	var fieldConversion string
	if isBuiltin(f.TableField.Type) {
		if f.SchemaField.IsRequired {
			return fmt.Sprintf("%s.%s", variable, templates.ToGo(f.TableField.Name))
		} else {
			return fmt.Sprintf("&%s.%s", variable, templates.ToGo(f.TableField.Name))
		}
	} else {
		funcName := getToObjectField(getColumnTypeAsText(f.TableField.Type), getObjectFieldAsText(f.SchemaField.UnderlyingType()))
		fieldConversion = "utils." + fmt.Sprintf("%s(%s.%s)", funcName, variable, templates.ToGo(f.TableField.Name))
		f.imports.Add("github.com/randallmlough/simmer/utils")
	}
	return fieldConversion
}

type Field struct {
	Name       string
	IsRequired bool
	IsRelation bool
	Type       string
}

type FieldList []ObjectField

func getToTableColumn(columnFieldType, objectFieldType string) string {
	return getObjectFieldAsText(objectFieldType) + "To" + getColumnTypeAsText(columnFieldType)
}

func getToObjectField(columnFieldType, objectFieldType string) string {
	return getColumnTypeAsText(columnFieldType) + "To" + getObjectFieldAsText(objectFieldType)
}

func getColumnTypeAsText(columnType string) string {
	columnType = strings.Replace(columnType, ".", "Dot", -1)

	return strcase.ToCamel(columnType)
}

func getObjectFieldAsText(objectType string) string {
	if strings.HasPrefix(objectType, "*") {
		objectType = strings.TrimPrefix(objectType, "*")
		objectType = strcase.ToCamel(objectType)
		objectType = "Pointer" + objectType
	}
	return strcase.ToCamel(objectType)
}

func isBuiltin(typ string) bool {
	if strings.HasPrefix(typ, "*") {
		typ = strings.Replace(typ, "*", "", 1)
	}
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
		"string":
		return true
	}
	return false
}
