{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- $alias := $data.Aliases.Table $model.Table.Name}}
{{- $schemaTable := $model.Table.Name | $data.SchemaTable}}
{{if $options.AddGlobal -}}
// InsertG a single record. See Insert for whitelist behavior description.
func (o *{{$alias.UpSingular}}) InsertG({{if not $options.NoContext}}ctx context.Context, {{end -}} columns simmer.Columns) error {
	return o.Insert({{if $options.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, columns)
}

{{end -}}

{{if $options.AddPanic -}}
// InsertP a single record using an executor, and panics on error. See Insert
// for whitelist behavior description.
func (o *{{$alias.UpSingular}}) InsertP({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, columns simmer.Columns) {
	if err := o.Insert({{if not $options.NoContext}}ctx, {{end -}} exec, columns); err != nil {
		panic(simmer.WrapErr(err))
	}
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// InsertGP a single record, and panics on error. See Insert for whitelist
// behavior description.
func (o *{{$alias.UpSingular}}) InsertGP({{if not $options.NoContext}}ctx context.Context, {{end -}} columns simmer.Columns) {
	if err := o.Insert({{if $options.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, columns); err != nil {
		panic(simmer.WrapErr(err))
	}
}

{{end -}}

// Insert a single record using an executor.
// See simmer.Columns.InsertColumnSet documentation to understand column list inference for inserts.
func (o *{{$alias.UpSingular}}) Insert({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, columns simmer.Columns) error {
	if o == nil {
		return errors.New("{{$options.PkgName}}: no {{$model.Table.Name}} provided for insertion")
	}

	var err error
	{{- template "timestamp_insert_helper" . }}

	{{if not $options.NoHooks -}}
	if err := o.doBeforeInsertHooks({{if not $options.NoContext}}ctx, {{end -}} exec); err != nil {
		return err
	}
	{{- end}}

	nzDefaults := queries.NonZeroDefaultSet({{$alias.DownSingular}}ColumnsWithDefault, o)

	key := makeCacheKey(columns, nzDefaults)
	{{$alias.DownSingular}}InsertCacheMut.RLock()
	cache, cached := {{$alias.DownSingular}}InsertCache[key]
	{{$alias.DownSingular}}InsertCacheMut.RUnlock()

	if !cached {
		wl, returnColumns := columns.InsertColumnSet(
			{{$alias.DownSingular}}AllColumns,
			{{$alias.DownSingular}}ColumnsWithDefault,
			{{$alias.DownSingular}}ColumnsWithoutDefault,
			nzDefaults,
		)

		cache.valueMapping, err = queries.BindMapping({{$alias.DownSingular}}Type, {{$alias.DownSingular}}Mapping, wl)
		if err != nil {
			return err
		}
		cache.retMapping, err = queries.BindMapping({{$alias.DownSingular}}Type, {{$alias.DownSingular}}Mapping, returnColumns)
		if err != nil {
			return err
		}
		if len(wl) != 0 {
			cache.query = fmt.Sprintf("INSERT INTO {{$schemaTable}} ({{$data.LQ}}%s{{$data.RQ}}) %%sVALUES (%s)%%s", strings.Join(wl, "{{$data.RQ}},{{$data.LQ}}"), strmangle.Placeholders(dialect.UseIndexPlaceholders, len(wl), 1, 1))
		} else {
			{{if $data.Dialect.UseDefaultKeyword -}}
			cache.query = "INSERT INTO {{$schemaTable}} %sDEFAULT VALUES%s"
			{{else -}}
			cache.query = "INSERT INTO {{$schemaTable}} () VALUES ()%s%s"
			{{end -}}
		}

		var queryOutput, queryReturning string

		if len(cache.retMapping) != 0 {
			{{if $data.Dialect.UseLastInsertID -}}
			cache.retQuery = fmt.Sprintf("SELECT {{$data.LQ}}%s{{$data.RQ}} FROM {{$schemaTable}} WHERE %s", strings.Join(returnColumns, "{{$data.RQ}},{{$data.LQ}}"), strmangle.WhereClause("{{$data.LQ}}", "{{$data.RQ}}", {{if .Dialect.UseIndexPlaceholders}}1{{else}}0{{end}}, {{$alias.DownSingular}}PrimaryKeyColumns))
			{{else -}}
				{{if $data.Dialect.UseOutputClause -}}
			queryOutput = fmt.Sprintf("OUTPUT INSERTED.{{$data.LQ}}%s{{$data.RQ}} ", strings.Join(returnColumns, "{{$data.RQ}},INSERTED.{{$data.LQ}}"))
				{{else -}}
			queryReturning = fmt.Sprintf(" RETURNING {{$data.LQ}}%s{{$data.RQ}}", strings.Join(returnColumns, "{{$data.RQ}},{{$data.LQ}}"))
				{{end -}}
			{{end -}}
		}

		cache.query = fmt.Sprintf(cache.query, queryOutput, queryReturning)
	}

	value := reflect.Indirect(reflect.ValueOf(o))
	vals := queries.ValuesFromMapping(value, cache.valueMapping)

	{{if $options.NoContext -}}
	if simmer.DebugMode {
		fmt.Fprintln(simmer.DebugWriter, cache.query)
		fmt.Fprintln(simmer.DebugWriter, vals)
	}
	{{else -}}
	if simmer.IsDebug(ctx) {
		writer := simmer.DebugWriterFrom(ctx)
		fmt.Fprintln(writer, cache.query)
		fmt.Fprintln(writer, vals)
	}
	{{end -}}

	{{if $data.Dialect.UseLastInsertID -}}
	{{- $canLastInsertID := $model.Table.CanLastInsertID -}}
	{{if $canLastInsertID -}}
		{{if $options.NoContext -}}
	result, err := exec.Exec(cache.query, vals...)
		{{else -}}
	result, err := exec.ExecContext(ctx, cache.query, vals...)
		{{end -}}
	{{else -}}
		{{if $options.NoContext -}}
	_, err = exec.Exec(cache.query, vals...)
		{{else -}}
	_, err = exec.ExecContext(ctx, cache.query, vals...)
		{{end -}}
	{{- end}}
	if err != nil {
		return errors.Wrap(err, "{{$options.PkgName}}: unable to insert into {{$model.Table.Name}}")
	}

	{{if $canLastInsertID -}}
	var lastID int64
	{{- end}}
	var identifierCols []interface{}

	if len(cache.retMapping) == 0 {
		goto CacheNoHooks
	}

	{{if $canLastInsertID -}}
	lastID, err = result.LastInsertId()
	if err != nil {
		return ErrSyncFail
	}

	{{$colName := index $model.Table.PKey.Columns 0 -}}
	{{- $col := $model.Table.GetColumn $colName -}}
	{{- $colTitled := $colName | titleCase}}
	o.{{$colTitled}} = {{$col.Type}}(lastID)
	if lastID != 0 && len(cache.retMapping) == 1 && cache.retMapping[0] == {{$alias.DownSingular}}Mapping["{{$colName}}"] {
		goto CacheNoHooks
	}
	{{- end}}

	identifierCols = []interface{}{
		{{range $model.Table.PKey.Columns -}}
		o.{{$alias.Column .}},
		{{end -}}
	}

	{{if $options.NoContext -}}
	if simmer.DebugMode {
		fmt.Fprintln(simmer.DebugWriter, cache.retQuery)
		fmt.Fprintln(simmer.DebugWriter, identifierCols...)
	}
	{{else -}}
	if simmer.IsDebug(ctx) {
		writer := simmer.DebugWriterFrom(ctx)
		fmt.Fprintln(writer, cache.retQuery)
		fmt.Fprintln(writer, identifierCols...)
	}
	{{end -}}

	{{if $options.NoContext -}}
	err = exec.QueryRow(cache.retQuery, identifierCols...).Scan(queries.PtrsFromMapping(value, cache.retMapping)...)
	{{else -}}
	err = exec.QueryRowContext(ctx, cache.retQuery, identifierCols...).Scan(queries.PtrsFromMapping(value, cache.retMapping)...)
	{{end -}}
	if err != nil {
		return errors.Wrap(err, "{{$options.PkgName}}: unable to populate default values for {{$model.Table.Name}}")
	}
	{{else}}
	if len(cache.retMapping) != 0 {
		{{if $options.NoContext -}}
		err = exec.QueryRow(cache.query, vals...).Scan(queries.PtrsFromMapping(value, cache.retMapping)...)
		{{else -}}
		err = exec.QueryRowContext(ctx, cache.query, vals...).Scan(queries.PtrsFromMapping(value, cache.retMapping)...)
		{{end -}}
	} else {
		{{if $options.NoContext -}}
		_, err = exec.Exec(cache.query, vals...)
		{{else -}}
		_, err = exec.ExecContext(ctx, cache.query, vals...)
		{{end -}}
	}

	if err != nil {
		return errors.Wrap(err, "{{$options.PkgName}}: unable to insert into {{$model.Table.Name}}")
	}
	{{end}}

{{if $data.Dialect.UseLastInsertID -}}
CacheNoHooks:
{{- end}}
	if !cached {
		{{$alias.DownSingular}}InsertCacheMut.Lock()
		{{$alias.DownSingular}}InsertCache[key] = cache
		{{$alias.DownSingular}}InsertCacheMut.Unlock()
	}

	{{if not $options.NoHooks -}}
	return o.doAfterInsertHooks({{if not $options.NoContext}}ctx, {{end -}} exec)
	{{- else -}}
	return nil
	{{- end}}
}
