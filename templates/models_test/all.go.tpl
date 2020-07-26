{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $alias := $data.Aliases.Table $model.Table.Name -}}
func test{{$alias.UpPlural}}(t *testing.T) {
	t.Parallel()

	query := {{$alias.UpPlural}}()

	if query.Query == nil {
		t.Error("expected a query, got nothing")
	}
}
