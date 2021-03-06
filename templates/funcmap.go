package templates

import (
	"fmt"
	"github.com/iancoleman/strcase"
	"github.com/randallmlough/simmer/database"
	"github.com/randallmlough/simmer/importers"
	"github.com/volatiletech/strmangle"
	"strings"
	"text/template"
)

// set is to stop duplication from named enums, allowing a template loop
// to keep some state
type Once map[string]struct{}

func newOnce() Once {
	return make(Once)
}

func (o Once) Has(s string) bool {
	_, ok := o[s]
	return ok
}

func (o Once) Put(s string) bool {
	if _, ok := o[s]; ok {
		return false
	}

	o[s] = struct{}{}
	return true
}

var goVarnameReplacer = strings.NewReplacer("[", "_", "]", "_", ".", "_")

var templateStringMappers = map[string]func(string) string{
	// String ops
	"quoteWrap":       func(a string) string { return fmt.Sprintf(`"%s"`, a) },
	"replaceReserved": strmangle.ReplaceReservedWords,

	// Casing
	"titleCase": strmangle.TitleCase,
	"camelCase": strmangle.CamelCase,
}

// templateFunctions is a map of all the functions that get passed into the
// templates. If you wish to pass a new function into your own template,
// add a function pointer here.
var TemplateFunctions = TemplateFuncs{
	"stringFuncs": func(funcName string) func(string) string {
		return templateStringMappers[funcName]
	},
	// String ops
	"quoteWrap": func(s string) string { return fmt.Sprintf(`"%s"`, s) },
	"id":        strmangle.Identifier,
	"goVarname": goVarnameReplacer.Replace,

	// Pluralization
	"singular": strmangle.Singular,
	"plural":   strmangle.Plural,

	// Casing
	"titleCase": strmangle.TitleCase,
	"camelCase": strmangle.CamelCase,
	"snakeCase": strcase.ToSnake,
	"ignore":    strmangle.Ignore,

	// String Slice ops
	"join":               func(sep string, slice []string) string { return strings.Join(slice, sep) },
	"joinSlices":         strmangle.JoinSlices,
	"stringMap":          strmangle.StringMap,
	"prefixStringSlice":  strmangle.PrefixStringSlice,
	"containsAny":        strmangle.ContainsAny,
	"generateTags":       strmangle.GenerateTags,
	"generateIgnoreTags": strmangle.GenerateIgnoreTags,

	// Enum ops
	"parseEnumName":       strmangle.ParseEnumName,
	"parseEnumVals":       strmangle.ParseEnumVals,
	"isEnumNormal":        strmangle.IsEnumNormal,
	"stripWhitespace":     strmangle.StripWhitespace,
	"shouldTitleCaseEnum": strmangle.ShouldTitleCaseEnum,
	"onceNew":             newOnce,
	"oncePut":             Once.Put,
	"onceHas":             Once.Has,

	// String Map ops
	"makeStringMap": strmangle.MakeStringMap,

	// Set operations
	"setInclude": strmangle.SetInclude,

	// Database related mangling
	"whereClause": strmangle.WhereClause,

	// Alias and text helping

	"usesPrimitives": usesPrimitives,
	"isPrimitive":    isPrimitive,
	"isBuiltin":      isBuiltin,

	// dbdrivers ops
	"filterColumnsByAuto":    database.FilterColumnsByAuto,
	"filterColumnsByDefault": database.FilterColumnsByDefault,
	"filterColumnsByEnum":    database.FilterColumnsByEnum,
	"sqlColDefinitions":      database.SQLColDefinitions,
	"columnNames":            database.ColumnNames,
	"columnDBTypes":          database.ColumnDBTypes,
	"getTable":               database.GetTable,

	// Go specific
	"go":          ToGo,
	"goPrivate":   ToGoPrivate,
	"prefixLines": prefixLines,
	//"ref":       ref,

	// models
	"modelTypeAsText": getModelTypeAsText,
}

type reserveImportFunc func(path string, aliases ...string) string

func reserveImport(set *importers.Set, typ string) reserveImportFunc {
	return func(path string, aliases ...string) string {
		if path == "" {
			return ""
		}
		path = fmt.Sprintf("%q", path)
		if len(aliases) > 0 {
			path = aliases[0] + " " + path
		}
		if typ == "thirdParty" {
			set.Standard = append(set.Standard, path)
		} else {
			set.ThirdParty = append(set.ThirdParty, path)
		}
		return ""
	}
}

type TemplateFuncs template.FuncMap

func (f TemplateFuncs) Append(funcMap template.FuncMap) {
	for key, fn := range funcMap {
		f[key] = fn
	}
}

func (f TemplateFuncs) AppendFunc(name string, fn interface{}) {
	f[name] = fn
}

// usesPrimitives checks to see if relationship between two models (ie the foreign key column
// and referred to column) both are primitive Go types we can compare or assign with == and =
// in a template.
func usesPrimitives(tables []database.Table, table, column, foreignTable, foreignColumn string) bool {
	local := database.GetTable(tables, table)
	foreign := database.GetTable(tables, foreignTable)

	col := local.GetColumn(column)
	foreignCol := foreign.GetColumn(foreignColumn)

	return isPrimitive(col.Type) && isPrimitive(foreignCol.Type)
}

var identifierSuffixes = []string{"_id", "_uuid", "_guid", "_oid"}

// trimSuffixes from the identifier
func trimSuffixes(str string) string {
	ln := len(str)
	for _, s := range identifierSuffixes {
		str = strings.TrimSuffix(str, s)
		if len(str) != ln {
			break
		}
	}

	return str
}

func isPrimitive(typ string) bool {
	switch typ {
	// Numeric
	case "int", "int8", "int16", "int32", "int64":
		return true
	case "uint", "uint8", "uint16", "uint32", "uint64":
		return true
	case "float32", "float64":
		return true
	case "byte", "rune", "string":
		return true
	}

	return false
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
		"string":
		return true
	}
	return false
}

//func ref(p types.Type) string {
//	return CurrentImports.LookupType(p)
//}
func getModelTypeAsText(boilType string) string {

	// backward compatible missed Dot
	if strings.HasPrefix(boilType, "types.") {
		boilType = strings.TrimPrefix(boilType, "types.")
		boilType = strcase.ToCamel(boilType)
		boilType = "Types" + boilType
	}

	// if strings.HasPrefix(boilType, "null.") {
	// 	boilType = strings.TrimPrefix(boilType, "null.")
	// 	boilType = strcase.ToCamel(boilType)
	// 	boilType = "NullDot" + boilType
	// }
	boilType = strings.Replace(boilType, ".", "Dot", -1)

	return strcase.ToCamel(boilType)
}

func prefixLines(prefix, s string) string {
	return prefix + strings.Replace(s, "\n", "\n"+prefix, -1)
}
