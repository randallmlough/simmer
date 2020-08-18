{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- $alias := $data.Aliases.Table $model.Table.Name -}}
{{- $colDefs := sqlColDefinitions $model.Table.Columns $model.Table.PKey.Columns -}}
{{- $pkNames := $colDefs.Names | stringMap (aliasCols $alias) | stringMap (stringFuncs "camelCase") | stringMap (stringFuncs "replaceReserved") -}}
{{- $pkArgs := joinSlices " " $pkNames $colDefs.Types | join ", " -}}
{{- $schemaTable := $model.Table.Name | $data.SchemaTable -}}
{{- $canSoftDelete := $model.Table.CanSoftDelete }}
{{if $options.AddGlobal -}}
// {{$alias.UpSingular}}ExistsG checks if the {{$alias.UpSingular}} row exists.
func {{$alias.UpSingular}}ExistsG({{if not $data.NoContext}}ctx context.Context, {{end -}} {{$pkArgs}}) (bool, error) {
	return {{$alias.UpSingular}}Exists({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, {{$pkNames | join ", "}})
}

{{end -}}

{{if $options.AddPanic -}}
// {{$alias.UpSingular}}ExistsP checks if the {{$alias.UpSingular}} row exists. Panics on error.
func {{$alias.UpSingular}}ExistsP({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, {{$pkArgs}}) bool {
	e, err := {{$alias.UpSingular}}Exists({{if not $data.NoContext}}ctx, {{end -}} exec, {{$pkNames | join ", "}})
	if err != nil {
		panic(simmer.WrapErr(err))
	}

	return e
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// {{$alias.UpSingular}}ExistsGP checks if the {{$alias.UpSingular}} row exists. Panics on error.
func {{$alias.UpSingular}}ExistsGP({{if not $data.NoContext}}ctx context.Context, {{end -}} {{$pkArgs}}) bool {
	e, err := {{$alias.UpSingular}}Exists({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, {{$pkNames | join ", "}})
	if err != nil {
		panic(simmer.WrapErr(err))
	}

	return e
}

{{end -}}

// {{$alias.UpSingular}}Exists checks if the {{$alias.UpSingular}} row exists.
func {{$alias.UpSingular}}Exists({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, {{$pkArgs}}) (bool, error) {
	var exists bool
	{{if $data.Dialect.UseCaseWhenExistsClause -}}
	sql := "select case when exists(select top(1) 1 from {{$schemaTable}} where {{if $data.Dialect.UseIndexPlaceholders}}{{whereClause $data.LQ $data.RQ 1 $model.Table.PKey.Columns}}{{else}}{{whereClause $data.LQ $data.RQ 0 $model.Table.PKey.Columns}}{{end}}) then 1 else 0 end"
	{{- else -}}
	sql := "select exists(select 1 from {{$schemaTable}} where {{if $data.Dialect.UseIndexPlaceholders}}{{whereClause $data.LQ $data.RQ 1 $model.Table.PKey.Columns}}{{else}}{{whereClause $data.LQ $data.RQ 0 $model.Table.PKey.Columns}}{{end}}{{if and $data.AddSoftDeletes $canSoftDelete}} and {{"deleted_at" | $data.Quotes}} is null{{end}} limit 1)"
	{{- end}}

	{{if $data.NoContext -}}
	if simmer.DebugMode {
		fmt.Fprintln(simmer.DebugWriter, sql)
		fmt.Fprintln(simmer.DebugWriter, {{$pkNames | join ", "}})
	}
	{{else -}}
	if simmer.IsDebug(ctx) {
		writer := simmer.DebugWriterFrom(ctx)
		fmt.Fprintln(writer, sql)
		fmt.Fprintln(writer, {{$pkNames | join ", "}})
	}
	{{end -}}

	{{if $data.NoContext -}}
	row := exec.QueryRow(sql, {{$pkNames | join ", "}})
	{{else -}}
	row := exec.QueryRowContext(ctx, sql, {{$pkNames | join ", "}})
	{{- end}}

	err := row.Scan(&exists)
	if err != nil {
		return false, errors.Wrap(err, "{{$options.PkgName}}: unable to check if {{$model.Table.Name}} exists")
	}

	return exists, nil
}
