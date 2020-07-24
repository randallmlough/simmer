{{- $alias := .Aliases.Table .Table.Name}}
{{- $schemaTable := .Table.Name | .SchemaTable}}
{{- $canSoftDelete := .Table.CanSoftDelete }}
// {{$alias.UpPlural}} retrieves all the records using an executor.
func {{$alias.UpPlural}}(mods ...queries.QueryMod) {{$alias.DownSingular}}Query {
    {{if and .AddSoftDeletes $canSoftDelete -}}
    mods = append(mods, queries.From("{{$schemaTable}}"), queries.WhereIsNull("{{$schemaTable}}.{{"deleted_at" | $.Quotes}}"))
    {{else -}}
	mods = append(mods, queries.From("{{$schemaTable}}"))
	{{end -}}
	return {{$alias.DownSingular}}Query{NewQuery(mods...)}
}
