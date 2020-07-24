package data

import (
	"fmt"
	"github.com/volatiletech/strmangle"
	"text/template"
)

var DataFuncs = template.FuncMap{
	"aliasCols": func(ta TableAlias) func(string) string { return ta.Column },
}

// templateStringMappers are placed into the data to make it easy to use the
// stringMap function.
var templateStringMappers = map[string]func(string) string{
	// String ops
	"quoteWrap":       func(a string) string { return fmt.Sprintf(`"%s"`, a) },
	"replaceReserved": strmangle.ReplaceReservedWords,

	// Casing
	"titleCase": strmangle.TitleCase,
	"camelCase": strmangle.CamelCase,
}
