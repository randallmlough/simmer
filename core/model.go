package core

import (
	"github.com/iancoleman/strcase"
	"github.com/randallmlough/simmer/database"
	"github.com/randallmlough/simmer/schema"
	"github.com/volatiletech/strmangle"
	"strings"
)

type Model struct {
	Name   string
	Table  database.Table
	Schema schema.Type
}

func (m *Model) HasObject() bool {
	return m.Table.Name != "" && m.Schema.Type != nil
}

func (m *Model) Object() Object {
	obj := Object{Name: m.Name}
	fields := translateFields(m.Table.Columns, m.Schema.Type.Fields)
	obj.Fields = fields
	return obj
}

func translateFields(columns database.ColumnList, schemaFields []*schema.Field) FieldList {
	fieldMap := make(map[string]Field)
	for _, column := range columns {
		field := &DataField{
			Name:       column.Name,
			IsRequired: !column.Nullable,
			Type:       column.Type,
		}
		name := strmangle.CamelCase(field.Name)
		if f, exists := fieldMap[name]; exists {
			f.TableField = field
		} else {
			fieldMap[name] = Field{
				TableField: field,
			}
		}
	}
	for _, schemaField := range schemaFields {
		field := &DataField{
			Name:       schemaField.Name,
			IsRequired: schemaField.IsRequired,
			Type:       schemaField.Type.String(),
		}
		if f, exists := fieldMap[field.Name]; exists {
			f.SchemaField = field
			fieldMap[field.Name] = f
		} else {
			fieldMap[field.Name] = Field{
				SchemaField: field,
			}
		}
	}
	var fields []Field
	for _, field := range fieldMap {
		if field.TableField == nil || field.SchemaField == nil {
			continue
		} else {
			toColumn := getToTableColumn(getColumnTypeAsText(field.TableField.Type), getObjectFieldAsText(field.SchemaField.Type))
			toObject := getToObjectField(getColumnTypeAsText(field.TableField.Type), getObjectFieldAsText(field.SchemaField.Type))
			toColumn = "gqlutils." + toColumn
			toObject = "gqlutils." + toObject
			// Make these go-friendly for the helper/convert.go package
			field.ToTableField = toColumn
			field.ToObjectField = toObject
			fields = append(fields, field)
		}
	}
	return fields
}

// Object will exist if a model has both a matching table and schema
type Object struct {
	Name   string
	Fields FieldList
}

// Object will exist if a model has both a matching table and schema
type Field struct {
	IsRequired bool
	IsRelation bool

	SchemaField *DataField
	TableField  *DataField

	ToTableField  string
	ToObjectField string
}

type DataField struct {
	Name       string
	IsRequired bool
	IsRelation bool
	Type       string
}

type FieldList []Field

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
