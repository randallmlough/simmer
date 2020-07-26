{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- $alias := $data.Aliases.Table $model.Table.Name -}}
{{- $canSoftDelete := $model.Table.CanSoftDelete -}}
{{- $soft := and $options.AddSoftDeletes $canSoftDelete }}
{{if $soft -}}
func test{{$alias.UpPlural}}SoftDelete(t *testing.T) {
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

	{{if $options.NoRowsAffected -}}
	if err = o.Delete({{if not $options.NoContext}}ctx, {{end -}} tx, false); err != nil {
		t.Error(err)
	}

	{{else -}}
	if rowsAff, err := o.Delete({{if not $options.NoContext}}ctx, {{end -}} tx, false); err != nil {
		t.Error(err)
	} else if rowsAff != 1 {
		t.Error("should only have deleted one row, but affected:", rowsAff)
	}

	{{end -}}

	count, err := {{$alias.UpPlural}}().Count({{if not $options.NoContext}}ctx, {{end -}} tx)
	if err != nil {
		t.Error(err)
	}

	if count != 0 {
		t.Error("want zero records, got:", count)
	}
}

func test{{$alias.UpPlural}}QuerySoftDeleteAll(t *testing.T) {
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

	{{if $options.NoRowsAffected -}}
	if err = {{$alias.UpPlural}}().DeleteAll({{if not $options.NoContext}}ctx, {{end -}} tx, false); err != nil {
		t.Error(err)
	}

	{{else -}}
	if rowsAff, err := {{$alias.UpPlural}}().DeleteAll({{if not $options.NoContext}}ctx, {{end -}} tx, false); err != nil {
		t.Error(err)
	} else if rowsAff != 1 {
		t.Error("should only have deleted one row, but affected:", rowsAff)
	}

	{{end -}}

	count, err := {{$alias.UpPlural}}().Count({{if not $options.NoContext}}ctx, {{end -}} tx)
	if err != nil {
		t.Error(err)
	}

	if count != 0 {
		t.Error("want zero records, got:", count)
	}
}

func test{{$alias.UpPlural}}SliceSoftDeleteAll(t *testing.T) {
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

	slice := {{$alias.UpSingular}}Slice{{"{"}}o{{"}"}}

	{{if $options.NoRowsAffected -}}
	if err = slice.DeleteAll({{if not $options.NoContext}}ctx, {{end -}} tx, false); err != nil {
		t.Error(err)
	}

	{{else -}}
	if rowsAff, err := slice.DeleteAll({{if not $options.NoContext}}ctx, {{end -}} tx, false); err != nil {
		t.Error(err)
	} else if rowsAff != 1 {
		t.Error("should only have deleted one row, but affected:", rowsAff)
	}

	{{end -}}

	count, err := {{$alias.UpPlural}}().Count({{if not $options.NoContext}}ctx, {{end -}} tx)
	if err != nil {
		t.Error(err)
	}

	if count != 0 {
		t.Error("want zero records, got:", count)
	}
}

{{end -}}

func test{{$alias.UpPlural}}Delete(t *testing.T) {
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

	{{if $options.NoRowsAffected -}}
	if err = o.Delete({{if not $options.NoContext}}ctx, {{end -}} tx {{- if $soft}}, true{{end}}); err != nil {
		t.Error(err)
	}

	{{else -}}
	if rowsAff, err := o.Delete({{if not $options.NoContext}}ctx, {{end -}} tx {{- if $soft}}, true{{end}}); err != nil {
		t.Error(err)
	} else if rowsAff != 1 {
		t.Error("should only have deleted one row, but affected:", rowsAff)
	}

	{{end -}}

	count, err := {{$alias.UpPlural}}().Count({{if not $options.NoContext}}ctx, {{end -}} tx)
	if err != nil {
		t.Error(err)
	}

	if count != 0 {
		t.Error("want zero records, got:", count)
	}
}

func test{{$alias.UpPlural}}QueryDeleteAll(t *testing.T) {
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

	{{if $options.NoRowsAffected -}}
	if err = {{$alias.UpPlural}}().DeleteAll({{if not $options.NoContext}}ctx, {{end -}} tx {{- if $soft}}, true{{end}}); err != nil {
		t.Error(err)
	}

	{{else -}}
	if rowsAff, err := {{$alias.UpPlural}}().DeleteAll({{if not $options.NoContext}}ctx, {{end -}} tx {{- if $soft}}, true{{end}}); err != nil {
		t.Error(err)
	} else if rowsAff != 1 {
		t.Error("should only have deleted one row, but affected:", rowsAff)
	}

	{{end -}}

	count, err := {{$alias.UpPlural}}().Count({{if not $options.NoContext}}ctx, {{end -}} tx)
	if err != nil {
		t.Error(err)
	}

	if count != 0 {
		t.Error("want zero records, got:", count)
	}
}

func test{{$alias.UpPlural}}SliceDeleteAll(t *testing.T) {
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

	slice := {{$alias.UpSingular}}Slice{{"{"}}o{{"}"}}

	{{if $options.NoRowsAffected -}}
	if err = slice.DeleteAll({{if not $options.NoContext}}ctx, {{end -}} tx {{- if $soft}}, true{{end}}); err != nil {
		t.Error(err)
	}

	{{else -}}
	if rowsAff, err := slice.DeleteAll({{if not $options.NoContext}}ctx, {{end -}} tx {{- if $soft}}, true{{end}}); err != nil {
		t.Error(err)
	} else if rowsAff != 1 {
		t.Error("should only have deleted one row, but affected:", rowsAff)
	}

	{{end -}}

	count, err := {{$alias.UpPlural}}().Count({{if not $options.NoContext}}ctx, {{end -}} tx)
	if err != nil {
		t.Error(err)
	}

	if count != 0 {
		t.Error("want zero records, got:", count)
	}
}
