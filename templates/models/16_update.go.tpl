{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- $alias := $data.Aliases.Table $model.Table.Name -}}
{{- $schemaTable := $model.Table.Name | $data.SchemaTable}}
{{if $options.AddGlobal -}}
// UpdateG a single {{$alias.UpSingular}} record using the global executor.
// See Update for more documentation.
func (o *{{$alias.UpSingular}}) UpdateG({{if not $options.NoContext}}ctx context.Context, {{end -}} columns simmer.Columns) {{if $options.NoRowsAffected}}error{{else}}(int64, error){{end -}} {
	return o.Update({{if $options.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, columns)
}

{{end -}}

{{if $options.AddPanic -}}
// UpdateP uses an executor to update the {{$alias.UpSingular}}, and panics on error.
// See Update for more documentation.
func (o *{{$alias.UpSingular}}) UpdateP({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, columns simmer.Columns) {{if not $options.NoRowsAffected}}int64{{end -}} {
	{{if not $options.NoRowsAffected}}rowsAff, {{end}}err := o.Update({{if not $options.NoContext}}ctx, {{end -}} exec, columns)
	if err != nil {
		panic(simmer.WrapErr(err))
	}
	{{- if not $options.NoRowsAffected}}

	return rowsAff
	{{end -}}
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// UpdateGP a single {{$alias.UpSingular}} record using the global executor. Panics on error.
// See Update for more documentation.
func (o *{{$alias.UpSingular}}) UpdateGP({{if not $options.NoContext}}ctx context.Context, {{end -}} columns simmer.Columns) {{if not $options.NoRowsAffected}}int64{{end -}} {
	{{if not $options.NoRowsAffected}}rowsAff, {{end}}err := o.Update({{if $options.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, columns)
	if err != nil {
		panic(simmer.WrapErr(err))
	}
	{{- if not $options.NoRowsAffected}}

	return rowsAff
	{{end -}}
}

{{end -}}

// Update uses an executor to update the {{$alias.UpSingular}}.
// See simmer.Columns.UpdateColumnSet documentation to understand column list inference for updates.
// Update does not automatically update the record in case of default values. Use .Reload() to refresh the records.
func (o *{{$alias.UpSingular}}) Update({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, columns simmer.Columns) {{if $options.NoRowsAffected}}error{{else}}(int64, error){{end -}} {
	{{- template "timestamp_update_helper" . -}}

	var err error
	{{if not $options.NoHooks -}}
	if err = o.doBeforeUpdateHooks({{if not $options.NoContext}}ctx, {{end -}} exec); err != nil {
		return {{if not $options.NoRowsAffected}}0, {{end -}} err
	}
	{{end -}}

	key := makeCacheKey(columns, nil)
	{{$alias.DownSingular}}UpdateCacheMut.RLock()
	cache, cached := {{$alias.DownSingular}}UpdateCache[key]
	{{$alias.DownSingular}}UpdateCacheMut.RUnlock()

	if !cached {
		wl := columns.UpdateColumnSet(
			{{$alias.DownSingular}}AllColumns,
			{{$alias.DownSingular}}PrimaryKeyColumns,
		)
		{{if $data.Dialect.UseAutoColumns -}}
		wl = strmangle.SetComplement(wl, {{$alias.DownSingular}}ColumnsWithAuto)
		{{end}}
		{{if not $options.NoAutoTimestamps}}
		if !columns.IsWhitelist() {
			wl = strmangle.SetComplement(wl, []string{"created_at"})
		}
		{{end -}}
		if len(wl) == 0 {
			return {{if not $options.NoRowsAffected}}0, {{end -}} errors.New("{{$options.PkgName}}: unable to update {{$model.Table.Name}}, could not build whitelist")
		}

		cache.query = fmt.Sprintf("UPDATE {{$schemaTable}} SET %s WHERE %s",
			strmangle.SetParamNames("{{$data.LQ}}", "{{$data.RQ}}", {{if $data.Dialect.UseIndexPlaceholders}}1{{else}}0{{end}}, wl),
			strmangle.WhereClause("{{$data.LQ}}", "{{$data.RQ}}", {{if $data.Dialect.UseIndexPlaceholders}}len(wl)+1{{else}}0{{end}}, {{$alias.DownSingular}}PrimaryKeyColumns),
		)
		cache.valueMapping, err = queries.BindMapping({{$alias.DownSingular}}Type, {{$alias.DownSingular}}Mapping, append(wl, {{$alias.DownSingular}}PrimaryKeyColumns...))
		if err != nil {
			return {{if not $options.NoRowsAffected}}0, {{end -}} err
		}
	}

	values := queries.ValuesFromMapping(reflect.Indirect(reflect.ValueOf(o)), cache.valueMapping)

	{{if $options.NoContext -}}
	if simmer.DebugMode {
		fmt.Fprintln(simmer.DebugWriter, cache.query)
		fmt.Fprintln(simmer.DebugWriter, values)
	}
	{{else -}}
	if simmer.IsDebug(ctx) {
		writer := simmer.DebugWriterFrom(ctx)
		fmt.Fprintln(writer, cache.query)
		fmt.Fprintln(writer, values)
	}
	{{end -}}

	{{if $options.NoRowsAffected -}}
		{{if $options.NoContext -}}
	_, err = exec.Exec(cache.query, values...)
		{{else -}}
	_, err = exec.ExecContext(ctx, cache.query, values...)
		{{end -}}
	{{else -}}
	var result sql.Result
		{{if $options.NoContext -}}
	result, err = exec.Exec(cache.query, values...)
		{{else -}}
	result, err = exec.ExecContext(ctx, cache.query, values...)
		{{end -}}
	{{end -}}
	if err != nil {
		return {{if not $options.NoRowsAffected}}0, {{end -}} errors.Wrap(err, "{{$options.PkgName}}: unable to update {{$model.Table.Name}} row")
	}

	{{if not $options.NoRowsAffected -}}
	rowsAff, err := result.RowsAffected()
	if err != nil {
		return 0, errors.Wrap(err, "{{$options.PkgName}}: failed to get rows affected by update for {{$model.Table.Name}}")
	}

	{{end -}}

	if !cached {
		{{$alias.DownSingular}}UpdateCacheMut.Lock()
		{{$alias.DownSingular}}UpdateCache[key] = cache
		{{$alias.DownSingular}}UpdateCacheMut.Unlock()
	}

	{{if not $options.NoHooks -}}
	return {{if not $options.NoRowsAffected}}rowsAff, {{end -}} o.doAfterUpdateHooks({{if not $options.NoContext}}ctx, {{end -}} exec)
	{{- else -}}
	return {{if not $options.NoRowsAffected}}rowsAff, {{end -}} nil
	{{- end}}
}

{{if $options.AddPanic -}}
// UpdateAllP updates all rows with matching column names, and panics on error.
func (q {{$alias.DownSingular}}Query) UpdateAllP({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, cols M) {{if not $options.NoRowsAffected}}int64{{end -}} {
	{{if not $options.NoRowsAffected}}rowsAff, {{end -}} err := q.UpdateAll({{if not $options.NoContext}}ctx, {{end -}} exec, cols)
	if err != nil {
		panic(simmer.WrapErr(err))
	}
	{{- if not $options.NoRowsAffected}}

	return rowsAff
	{{end -}}
}

{{end -}}


{{if $options.AddGlobal -}}
// UpdateAllG updates all rows with the specified column values.
func (q {{$alias.DownSingular}}Query) UpdateAllG({{if not $options.NoContext}}ctx context.Context, {{end -}} cols M) {{if $options.NoRowsAffected}}error{{else}}(int64, error){{end -}} {
	return q.UpdateAll({{if $options.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, cols)
}

{{end -}}


// UpdateAll updates all rows with the specified column values.
func (q {{$alias.DownSingular}}Query) UpdateAll({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, cols M) {{if $options.NoRowsAffected}}error{{else}}(int64, error){{end -}} {
	queries.SetUpdate(q.Query, cols)

	{{if $options.NoRowsAffected -}}
		{{if $options.NoContext -}}
	_, err := q.Query.Exec(exec)
		{{else -}}
	_, err := q.Query.ExecContext(ctx, exec)
		{{end -}}
	{{else -}}
		{{if $options.NoContext -}}
	result, err := q.Query.Exec(exec)
		{{else -}}
	result, err := q.Query.ExecContext(ctx, exec)
		{{end -}}
	{{end -}}
	if err != nil {
		return {{if not $options.NoRowsAffected}}0, {{end -}} errors.Wrap(err, "{{$options.PkgName}}: unable to update all for {{$model.Table.Name}}")
	}

	{{if not $options.NoRowsAffected -}}
	rowsAff, err := result.RowsAffected()
	if err != nil {
		return 0, errors.Wrap(err, "{{$options.PkgName}}: unable to retrieve rows affected for {{$model.Table.Name}}")
	}

	{{end -}}

	return {{if not $options.NoRowsAffected}}rowsAff, {{end -}} nil
}

{{if $options.AddGlobal -}}
// UpdateAllG updates all rows with the specified column values.
func (o {{$alias.UpSingular}}Slice) UpdateAllG({{if not $options.NoContext}}ctx context.Context, {{end -}} cols M) {{if $options.NoRowsAffected}}error{{else}}(int64, error){{end -}} {
	return o.UpdateAll({{if $options.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, cols)
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// UpdateAllGP updates all rows with the specified column values, and panics on error.
func (o {{$alias.UpSingular}}Slice) UpdateAllGP({{if not $options.NoContext}}ctx context.Context, {{end -}} cols M) {{if not $options.NoRowsAffected}}int64{{end -}} {
	{{if not $options.NoRowsAffected}}rowsAff, {{end -}} err := o.UpdateAll({{if $options.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, cols)
	if err != nil {
		panic(simmer.WrapErr(err))
	}
	{{- if not $options.NoRowsAffected}}

	return rowsAff
	{{end -}}
}

{{end -}}

{{if $options.AddPanic -}}
// UpdateAllP updates all rows with the specified column values, and panics on error.
func (o {{$alias.UpSingular}}Slice) UpdateAllP({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, cols M) {{if not $options.NoRowsAffected}}int64{{end -}} {
	{{if not $options.NoRowsAffected}}rowsAff, {{end -}} err := o.UpdateAll({{if not $options.NoContext}}ctx, {{end -}} exec, cols)
	if err != nil {
		panic(simmer.WrapErr(err))
	}
	{{- if not $options.NoRowsAffected}}

	return rowsAff
	{{end -}}
}

{{end -}}

// UpdateAll updates all rows with the specified column values, using an executor.
func (o {{$alias.UpSingular}}Slice) UpdateAll({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, cols M) {{if $options.NoRowsAffected}}error{{else}}(int64, error){{end -}} {
	ln := int64(len(o))
	if ln == 0 {
		return {{if not $options.NoRowsAffected}}0, {{end -}} nil
	}

	if len(cols) == 0 {
		return {{if not $options.NoRowsAffected}}0, {{end -}} errors.New("{{$options.PkgName}}: update all requires at least one column argument")
	}

	colNames := make([]string, len(cols))
	args := make([]interface{}, len(cols))

	i := 0
	for name, value := range cols {
		colNames[i] = name
		args[i] = value
		i++
	}

	// Append all of the primary key values for each column
	for _, obj := range o {
		pkeyArgs := queries.ValuesFromMapping(reflect.Indirect(reflect.ValueOf(obj)), {{$alias.DownSingular}}PrimaryKeyMapping)
		args = append(args, pkeyArgs...)
	}

	sql := fmt.Sprintf("UPDATE {{$schemaTable}} SET %s WHERE %s",
		strmangle.SetParamNames("{{$data.LQ}}", "{{$data.RQ}}", {{if $data.Dialect.UseIndexPlaceholders}}1{{else}}0{{end}}, colNames),
		strmangle.WhereClauseRepeated(string(dialect.LQ), string(dialect.RQ), {{if $data.Dialect.UseIndexPlaceholders}}len(colNames)+1{{else}}0{{end}}, {{$alias.DownSingular}}PrimaryKeyColumns, len(o)))

	{{if $options.NoContext -}}
	if simmer.DebugMode {
		fmt.Fprintln(simmer.DebugWriter, sql)
		fmt.Fprintln(simmer.DebugWriter, args...)
	}
	{{else -}}
	if simmer.IsDebug(ctx) {
		writer := simmer.DebugWriterFrom(ctx)
		fmt.Fprintln(writer, sql)
		fmt.Fprintln(writer, args...)
	}
	{{end -}}

	{{if $options.NoRowsAffected -}}
		{{if $options.NoContext -}}
	_, err := exec.Exec(sql, args...)
		{{else -}}
	_, err := exec.ExecContext(ctx, sql, args...)
		{{end -}}
	{{else -}}
		{{if $options.NoContext -}}
	result, err := exec.Exec(sql, args...)
		{{else -}}
	result, err := exec.ExecContext(ctx, sql, args...)
		{{end -}}
	{{end -}}
	if err != nil {
		return {{if not $options.NoRowsAffected}}0, {{end -}} errors.Wrap(err, "{{$options.PkgName}}: unable to update all in {{$alias.DownSingular}} slice")
	}

	{{if not $options.NoRowsAffected -}}
	rowsAff, err := result.RowsAffected()
	if err != nil {
		return 0, errors.Wrap(err, "{{$options.PkgName}}: unable to retrieve rows affected all in update all {{$alias.DownSingular}}")
	}
	{{end -}}

	return {{if not $options.NoRowsAffected}}rowsAff, {{end -}} nil
}
