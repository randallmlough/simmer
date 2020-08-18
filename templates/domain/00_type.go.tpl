{{- $model := .Model -}}
{{- $schema := $model.Schema -}}

{{ if and $schema }}
{{- $type := $schema.Type -}}
type {{$type.Name | go }} struct {
	{{- range $field := $type.Fields -}}
	{{$field.Name | go }} {{$field.Type}} `json:"{{$field.Name | snakeCase}}" gql:"{{$field.Name | camelCase}}"`
	{{ end -}}
}
{{end}}