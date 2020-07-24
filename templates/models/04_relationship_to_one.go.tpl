{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- if $model.Table.IsJoinTable -}}
{{- else -}}
	{{- range $fkey := $model.Table.FKeys -}}
		{{- $ltable := $data.Aliases.Table $fkey.Table -}}
		{{- $ftable := $data.Aliases.Table $fkey.ForeignTable -}}
		{{- $rel := $ltable.Relationship $fkey.Name -}}
		{{- $canSoftDelete := (getTable $data.Tables $fkey.ForeignTable).CanSoftDelete }}
// {{$rel.Foreign}} pointed to by the foreign key.
func (o *{{$ltable.UpSingular}}) {{$rel.Foreign}}(mods ...queries.QueryMod) ({{$ftable.DownSingular}}Query) {
	queryMods := []queries.QueryMod{
		queries.Where("{{$fkey.ForeignColumn | $data.Quotes}} = ?", o.{{$ltable.Column $fkey.Column}}),
		{{if and $options.AddSoftDeletes $canSoftDelete -}}
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
