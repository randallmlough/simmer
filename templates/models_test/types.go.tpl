{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $alias := $data.Aliases.Table $model.Table.Name}}
var (
	{{$alias.DownSingular}}DBTypes = map[string]string{{"{"}}{{range $i, $col := $model.Table.Columns -}}{{- if ne $i 0}},{{end}}`{{$alias.Column $col.Name}}`: `{{$col.DBType}}`{{end}}{{"}"}}
	_ = bytes.MinRead
)
