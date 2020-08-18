{{- $model := .Model -}}
{{- $schema := $model.Schema -}}

{{ if and $schema }}
{{ range $input := $schema.Inputs }}
type {{$input.Name | go }} struct {
	{{- range $field := $input.Fields -}}
	{{$field.Name | go }} {{$field.Type}} `json:"{{$field.Name | snakeCase}}" gql:"{{$field.Name | camelCase}}"`
	{{ end -}}
}
{{end}}
{{end}}