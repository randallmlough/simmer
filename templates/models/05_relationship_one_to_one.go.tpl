{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- if $model.Table.IsJoinTable -}}
{{- else -}}
	{{- range $rel := $model.Table.ToOneRelationships -}}
		{{- $ltable := $data.Aliases.Table $rel.Table -}}
		{{- $ftable := $data.Aliases.Table $rel.ForeignTable -}}
		{{- $relAlias := $ftable.Relationship $rel.Name -}}
		{{- $canSoftDelete := (getTable $data.Tables $rel.ForeignTable).CanSoftDelete }}
// {{$relAlias.Local}} pointed to by the foreign key.
func (o *{{$ltable.UpSingular}}) {{$relAlias.Local}}(mods ...queries.QueryMod) ({{$ftable.DownSingular}}Query) {
	queryMods := []queries.QueryMod{
		queries.Where("{{$rel.ForeignColumn | $data.Quotes}} = ?", o.{{$ltable.Column $rel.Column}}),
        {{if and $data.AddSoftDeletes $canSoftDelete -}}
        queries.WhereIsNull("deleted_at"),
        {{- end}}
	}

	queryMods = append(queryMods, mods...)

	query := {{$ftable.UpPlural}}(queryMods...)
	queries.SetFrom(query.Query, "{{.ForeignTable | $data.SchemaTable}}")

	return query
}
{{- end -}}
{{- end -}}
