{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- if $model.Table.IsJoinTable -}}
{{- else -}}
	{{- range $rel := $model.Table.ToManyRelationships -}}
		{{- $ltable := $data.Aliases.Table $rel.Table -}}
		{{- $ftable := $data.Aliases.Table $rel.ForeignTable -}}
		{{- $relAlias := $data.Aliases.ManyRelationship $rel.ForeignTable $rel.Name $rel.JoinTable $rel.JoinLocalFKeyName -}}
		{{- $schemaForeignTable := .ForeignTable | $data.SchemaTable -}}
		{{- $canSoftDelete := (getTable $data.Tables .ForeignTable).CanSoftDelete }}
// {{$relAlias.Local}} retrieves all the {{.ForeignTable | singular}}'s {{$ftable.UpPlural}} with an executor
{{- if not (eq $relAlias.Local $ftable.UpPlural)}} via {{$rel.ForeignColumn}} column{{- end}}.
func (o *{{$ltable.UpSingular}}) {{$relAlias.Local}}(mods ...queries.QueryMod) {{$ftable.DownSingular}}Query {
	var queryMods []queries.QueryMod
	if len(mods) != 0 {
		queryMods = append(queryMods, mods...)
	}

		{{if $rel.ToJoinTable -}}
	queryMods = append(queryMods,
		{{$schemaJoinTable := $rel.JoinTable | $data.SchemaTable -}}
		queries.InnerJoin("{{$schemaJoinTable}} on {{$schemaForeignTable}}.{{$rel.ForeignColumn | $data.Quotes}} = {{$schemaJoinTable}}.{{$rel.JoinForeignColumn | $.Quotes}}"),
		queries.Where("{{$schemaJoinTable}}.{{$rel.JoinLocalColumn | $data.Quotes}}=?", o.{{$ltable.Column $rel.Column}}),
	)
		{{else -}}
	queryMods = append(queryMods,
		queries.Where("{{$schemaForeignTable}}.{{$rel.ForeignColumn | $data.Quotes}}=?", o.{{$ltable.Column $rel.Column}}),
		{{if and $options.AddSoftDeletes $canSoftDelete -}}
		queries.WhereIsNull("{{$schemaForeignTable}}.{{"deleted_at" | $data.Quotes}}"),
		{{- end}}
	)
		{{end}}

	query := {{$ftable.UpPlural}}(queryMods...)
	queries.SetFrom(query.Query, "{{$schemaForeignTable}}")

	if len(queries.GetSelect(query.Query)) == 0 {
		queries.SetSelect(query.Query, []string{"{{$schemaForeignTable}}.*"})
	}

	return query
}

{{end -}}{{- /* range relationships */ -}}
{{- end -}}{{- /* if isJoinTable */ -}}
