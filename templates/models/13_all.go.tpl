{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- $alias := $data.Aliases.Table $model.Table.Name}}
{{- $schemaTable := $model.Table.Name | $data.SchemaTable}}
{{- $canSoftDelete := $model.Table.CanSoftDelete }}
// {{$alias.UpPlural}} retrieves all the records using an executor.
func {{$alias.UpPlural}}(mods ...queries.QueryMod) {{$alias.DownSingular}}Query {
    {{if and $data.AddSoftDeletes $canSoftDelete -}}
    mods = append(mods, queries.From("{{$schemaTable}}"), queries.WhereIsNull("{{$schemaTable}}.{{"deleted_at" | $data.Quotes}}"))
    {{else -}}
	mods = append(mods, queries.From("{{$schemaTable}}"))
	{{end -}}
	return {{$alias.DownSingular}}Query{NewQuery(mods...)}
}
