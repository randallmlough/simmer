{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- if $model.Table.IsJoinTable -}}
{{- else -}}
	{{- $table := $model.Table }}
	{{- range $rel := $model.Table.ToManyRelationships -}}
		{{- $ltable := $data.Aliases.Table $rel.Table -}}
		{{- $ftable := $data.Aliases.Table $rel.ForeignTable -}}
		{{- $relAlias := $data.Aliases.ManyRelationship $rel.ForeignTable $rel.Name $rel.JoinTable $rel.JoinLocalFKeyName -}}
		{{- $colField := $ltable.Column $rel.Column -}}
		{{- $fcolField := $ftable.Column $rel.ForeignColumn -}}
		{{- $usesPrimitives := usesPrimitives $data.Tables $rel.Table $rel.Column $rel.ForeignTable $rel.ForeignColumn -}}
		{{- $schemaForeignTable := .ForeignTable | $data.SchemaTable }}
func test{{$ltable.UpSingular}}ToMany{{$relAlias.Local}}(t *testing.T) {
	var err error
	{{if not $options.NoContext}}ctx := context.Background(){{end}}
	tx := MustTx({{if $options.NoContext}}simmer.Begin(){{else}}simmer.BeginTx(ctx, nil){{end}})
	defer func() { _ = tx.Rollback() }()

	var a {{$ltable.UpSingular}}
	var b, c {{$ftable.UpSingular}}

	seed := randomize.NewSeed()
	if err = randomize.Struct(seed, &a, {{$ltable.DownSingular}}DBTypes, true, {{$ltable.DownSingular}}ColumnsWithDefault...); err != nil {
		t.Errorf("Unable to randomize {{$ltable.UpSingular}} struct: %s", err)
	}

	if err := a.Insert({{if not $options.NoContext}}ctx, {{end -}} tx, simmer.Infer()); err != nil {
		t.Fatal(err)
	}

	if err = randomize.Struct(seed, &b, {{$ftable.DownSingular}}DBTypes, false, {{$ftable.DownSingular}}ColumnsWithDefault...); err != nil {
		t.Fatal(err)
	}
	if err = randomize.Struct(seed, &c, {{$ftable.DownSingular}}DBTypes, false, {{$ftable.DownSingular}}ColumnsWithDefault...); err != nil {
		t.Fatal(err)
	}

	{{if not .ToJoinTable -}}
		{{if $usesPrimitives}}
	b.{{$fcolField}} = a.{{$colField}}
	c.{{$fcolField}} = a.{{$colField}}
		{{else -}}
	queries.Assign(&b.{{$fcolField}}, a.{{$colField}})
	queries.Assign(&c.{{$fcolField}}, a.{{$colField}})
		{{- end}}
	{{- end}}
	if err = b.Insert({{if not $options.NoContext}}ctx, {{end -}} tx, simmer.Infer()); err != nil {
		t.Fatal(err)
	}
	if err = c.Insert({{if not $options.NoContext}}ctx, {{end -}} tx, simmer.Infer()); err != nil {
		t.Fatal(err)
	}

	{{if .ToJoinTable -}}
	_, err = tx.Exec("insert into {{.JoinTable | $data.SchemaTable}} ({{.JoinLocalColumn | $.Quotes}}, {{.JoinForeignColumn | $.Quotes}}) values {{if $.Dialect.UseIndexPlaceholders}}($1, $2){{else}}(?, ?){{end}}", a.{{$colField}}, b.{{$fcolField}})
	if err != nil {
		t.Fatal(err)
	}
	_, err = tx.Exec("insert into {{.JoinTable | $data.SchemaTable}} ({{.JoinLocalColumn | $.Quotes}}, {{.JoinForeignColumn | $.Quotes}}) values {{if $.Dialect.UseIndexPlaceholders}}($1, $2){{else}}(?, ?){{end}}", a.{{$colField}}, c.{{$fcolField}})
	if err != nil {
		t.Fatal(err)
	}
	{{end}}

	check, err := a.{{$relAlias.Local}}().All({{if not $options.NoContext}}ctx, {{end -}} tx)
	if err != nil {
		t.Fatal(err)
	}

	bFound, cFound := false, false
	for _, v := range check {
		{{if $usesPrimitives -}}
		if v.{{$fcolField}} == b.{{$fcolField}} {
			bFound = true
		}
		if v.{{$fcolField}} == c.{{$fcolField}} {
			cFound = true
		}
		{{else -}}
		if queries.Equal(v.{{$fcolField}}, b.{{$fcolField}}) {
			bFound = true
		}
		if queries.Equal(v.{{$fcolField}}, c.{{$fcolField}}) {
			cFound = true
		}
		{{end -}}
	}

	if !bFound {
		t.Error("expected to find b")
	}
	if !cFound {
		t.Error("expected to find c")
	}

	slice := {{$ltable.UpSingular}}Slice{&a}
	if err = a.L.Load{{$relAlias.Local}}({{if not $options.NoContext}}ctx, {{end -}} tx, false, (*[]*{{$ltable.UpSingular}})(&slice), nil); err != nil {
		t.Fatal(err)
	}
	if got := len(a.R.{{$relAlias.Local}}); got != 2 {
		t.Error("number of eager loaded records wrong, got:", got)
	}

	a.R.{{$relAlias.Local}} = nil
	if err = a.L.Load{{$relAlias.Local}}({{if not $options.NoContext}}ctx, {{end -}} tx, true, &a, nil); err != nil {
		t.Fatal(err)
	}
	if got := len(a.R.{{$relAlias.Local}}); got != 2 {
		t.Error("number of eager loaded records wrong, got:", got)
	}

	if t.Failed() {
		t.Logf("%#v", check)
	}
}

{{end -}}{{- /* range */ -}}
{{- end -}}{{- /* outer if join table */ -}}
