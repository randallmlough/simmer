{{- $model := .Model -}}
{{- $schema := $model.Schema -}}

{{ if and $schema }}
{{ range $object := $schema.Objects }}
type {{$object.Name | go }} struct {
	{{- range $field := $object.Fields }}
	{{$field.Name | go }} {{$field.Type}} `json:"{{$field.Name | snakeCase}}" gql:"{{$field.Name | camelCase}}"`
	{{- end -}}
}
{{end}}
{{end}}