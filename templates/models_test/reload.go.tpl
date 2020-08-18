{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- $alias := $data.Aliases.Table $model.Table.Name}}
func test{{$alias.UpPlural}}Reload(t *testing.T) {
	t.Parallel()

	seed := randomize.NewSeed()
	var err error
	o := &{{$alias.UpSingular}}{}
	if err = randomize.Struct(seed, o, {{$alias.DownSingular}}DBTypes, true, {{$alias.DownSingular}}ColumnsWithDefault...); err != nil {
		t.Errorf("Unable to randomize {{$alias.UpSingular}} struct: %s", err)
	}

	{{if not $data.NoContext}}ctx := context.Background(){{end}}
	tx := MustTx({{if $data.NoContext}}simmer.Begin(){{else}}simmer.BeginTx(ctx, nil){{end}})
	defer func() { _ = tx.Rollback() }()
	if err = o.Insert({{if not $data.NoContext}}ctx, {{end -}} tx, simmer.Infer()); err != nil {
		t.Error(err)
	}

	if err = o.Reload({{if not $data.NoContext}}ctx, {{end -}} tx); err != nil {
		t.Error(err)
	}
}

func test{{$alias.UpPlural}}ReloadAll(t *testing.T) {
	t.Parallel()

	seed := randomize.NewSeed()
	var err error
	o := &{{$alias.UpSingular}}{}
	if err = randomize.Struct(seed, o, {{$alias.DownSingular}}DBTypes, true, {{$alias.DownSingular}}ColumnsWithDefault...); err != nil {
		t.Errorf("Unable to randomize {{$alias.UpSingular}} struct: %s", err)
	}

	{{if not $data.NoContext}}ctx := context.Background(){{end}}
	tx := MustTx({{if $data.NoContext}}simmer.Begin(){{else}}simmer.BeginTx(ctx, nil){{end}})
	defer func() { _ = tx.Rollback() }()
	if err = o.Insert({{if not $data.NoContext}}ctx, {{end -}} tx, simmer.Infer()); err != nil {
		t.Error(err)
	}

	slice := {{$alias.UpSingular}}Slice{{"{"}}o{{"}"}}

	if err = slice.ReloadAll({{if not $data.NoContext}}ctx, {{end -}} tx); err != nil {
		t.Error(err)
	}
}
