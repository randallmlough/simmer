{{ if .Model.HasModel }}
{{- $model := .Model -}}
{{- $modelName := .Model.Name | singular -}}
{{- $modelUppercase := $modelName | titleCase }}
{{- $pk := .Model.Table.Constraints.PrimaryKey}}

// {{$modelName }}  DB constraints
var Err{{$modelUppercase}}{{$pk.Name | titleCase}}Exists = errors.New("{{$pk.Name }} already exists")
{{- range $column := .Model.Table.Constraints.Uniques }}
	{{- $columnUppercase := .ColumnName | titleCase }}
	var Err{{$modelUppercase}}{{$columnUppercase}}Exists = errors.New("{{.ColumnName}} already exists")
{{- end }}
{{ end }}