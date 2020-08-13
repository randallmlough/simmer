{{- $model := .Model -}}
{{- $schema := $model.Schema -}}

{{ if and $schema }}
{{- $type := $schema.Type -}}
type {{$type.Name | go }} struct {
	{{- range $field := $type.Fields }}
	{{- reserveImport $field.Imports.String }}
	{{$field.Name | go }} {{$field.Type.String}} `json:"{{$field.Name | snakeCase}}" gql:"{{$field.Name | camelCase}}"`
	{{- end -}}
}
{{end}}