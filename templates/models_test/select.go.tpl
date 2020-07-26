{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- $alias := $data.Aliases.Table $model.Table.Name}}
func test{{$alias.UpPlural}}Select(t *testing.T) {
	t.Parallel()

	seed := randomize.NewSeed()
	var err error
	o := &{{$alias.UpSingular}}{}
	if err = randomize.Struct(seed, o, {{$alias.DownSingular}}DBTypes, true, {{$alias.DownSingular}}ColumnsWithDefault...); err != nil {
		t.Errorf("Unable to randomize {{$alias.UpSingular}} struct: %s", err)
	}

	{{if not $options.NoContext}}ctx := context.Background(){{end}}
	tx := MustTx({{if $options.NoContext}}simmer.Begin(){{else}}simmer.BeginTx(ctx, nil){{end}})
	defer func() { _ = tx.Rollback() }()
	if err = o.Insert({{if not $options.NoContext}}ctx, {{end -}} tx, simmer.Infer()); err != nil {
		t.Error(err)
	}

	slice, err := {{$alias.UpPlural}}().All({{if not $options.NoContext}}ctx, {{end -}} tx)
	if err != nil {
		t.Error(err)
	}

	if len(slice) != 1 {
		t.Error("want one record, got:", len(slice))
	}
}
