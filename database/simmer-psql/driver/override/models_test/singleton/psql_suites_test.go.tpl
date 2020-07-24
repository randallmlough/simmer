func TestUpsert(t *testing.T) {
  {{- range $index, $table := .Data.Tables}}
  {{- if $table.IsJoinTable -}}
  {{- else -}}
  {{- $alias := $.Data.Aliases.Table $table.Name}}
  t.Run("{{$alias.UpPlural}}", test{{$alias.UpPlural}}Upsert)
  {{end -}}
  {{- end -}}
}
