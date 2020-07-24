{{- if .Table.IsJoinTable -}}
{{- else -}}
	{{- range $rel := .Table.ToOneRelationships -}}
		{{- $ltable := $.Aliases.Table $rel.Table -}}
		{{- $ftable := $.Aliases.Table $rel.ForeignTable -}}
		{{- $relAlias := $ftable.Relationship $rel.Name -}}
		{{- $canSoftDelete := (getTable $.Tables $rel.ForeignTable).CanSoftDelete }}
// {{$relAlias.Local}} pointed to by the foreign key.
func (o *{{$ltable.UpSingular}}) {{$relAlias.Local}}(mods ...queries.QueryMod) ({{$ftable.DownSingular}}Query) {
	queryMods := []queries.QueryMod{
		queries.Where("{{$rel.ForeignColumn | $.Quotes}} = ?", o.{{$ltable.Column $rel.Column}}),
        {{if and $.AddSoftDeletes $canSoftDelete -}}
        queries.WhereIsNull("deleted_at"),
        {{- end}}
	}

	queryMods = append(queryMods, mods...)

	query := {{$ftable.UpPlural}}(queryMods...)
	queries.SetFrom(query.Query, "{{.ForeignTable | $.SchemaTable}}")

	return query
}
{{- end -}}
{{- end -}}
