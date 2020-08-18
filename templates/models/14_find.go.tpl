{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- $alias := $data.Aliases.Table $model.Table.Name -}}
{{- $colDefs := sqlColDefinitions $model.Table.Columns $model.Table.PKey.Columns -}}
{{- $pkNames := $colDefs.Names | stringMap (aliasCols $alias) | stringMap (stringFuncs "camelCase") | stringMap (stringFuncs "replaceReserved") -}}
{{- $pkArgs := joinSlices " " $pkNames $colDefs.Types | join ", " -}}
{{- $canSoftDelete := $model.Table.CanSoftDelete }}
{{if $options.AddGlobal -}}
// Find{{$alias.UpSingular}}G retrieves a single record by ID.
func Find{{$alias.UpSingular}}G({{if not $data.NoContext}}ctx context.Context, {{end -}} {{$pkArgs}}, selectCols ...string) (*{{$alias.UpSingular}}, error) {
	return Find{{$alias.UpSingular}}({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, {{$pkNames | join ", "}}, selectCols...)
}

{{end -}}

{{if $options.AddPanic -}}
// Find{{$alias.UpSingular}}P retrieves a single record by ID with an executor, and panics on error.
func Find{{$alias.UpSingular}}P({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, {{$pkArgs}}, selectCols ...string) *{{$alias.UpSingular}} {
	retobj, err := Find{{$alias.UpSingular}}({{if not $data.NoContext}}ctx, {{end -}} exec, {{$pkNames | join ", "}}, selectCols...)
	if err != nil {
		panic(simmer.WrapErr(err))
	}

	return retobj
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// Find{{$alias.UpSingular}}GP retrieves a single record by ID, and panics on error.
func Find{{$alias.UpSingular}}GP({{if not $data.NoContext}}ctx context.Context, {{end -}} {{$pkArgs}}, selectCols ...string) *{{$alias.UpSingular}} {
	retobj, err := Find{{$alias.UpSingular}}({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, {{$pkNames | join ", "}}, selectCols...)
	if err != nil {
		panic(simmer.WrapErr(err))
	}

	return retobj
}

{{end -}}

// Find{{$alias.UpSingular}} retrieves a single record by ID with an executor.
// If selectCols is empty Find will return all columns.
func Find{{$alias.UpSingular}}({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, {{$pkArgs}}, selectCols ...string) (*{{$alias.UpSingular}}, error) {
	{{$alias.DownSingular}}Obj := &{{$alias.UpSingular}}{}

	sel := "*"
	if len(selectCols) > 0 {
		sel = strings.Join(strmangle.IdentQuoteSlice(dialect.LQ, dialect.RQ, selectCols), ",")
	}
	query := fmt.Sprintf(
		"select %s from {{$model.Table.Name | $data.SchemaTable}} where {{if $data.Dialect.UseIndexPlaceholders}}{{whereClause $data.LQ $data.RQ 1 $model.Table.PKey.Columns}}{{else}}{{whereClause $data.LQ $data.RQ 0 $model.Table.PKey.Columns}}{{end}}{{if and $data.AddSoftDeletes $canSoftDelete}} and {{"deleted_at" | $data.Quotes}} is null{{end}}", sel,
	)

	q := queries.Raw(query, {{$pkNames | join ", "}})

	err := q.Bind({{if not $data.NoContext}}ctx{{else}}nil{{end}}, exec, {{$alias.DownSingular}}Obj)
	if err != nil {
		if errors.Cause(err) == sql.ErrNoRows {
			return nil, sql.ErrNoRows
		}
		return nil, errors.Wrap(err, "{{$options.PkgName}}: unable to select from {{$model.Table.Name}}")
	}

	return {{$alias.DownSingular}}Obj, nil
}
