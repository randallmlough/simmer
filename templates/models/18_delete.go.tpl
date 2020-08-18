{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- $alias := $data.Aliases.Table $model.Table.Name -}}
{{- $schemaTable := $model.Table.Name | $data.SchemaTable -}}
{{- $canSoftDelete := $model.Table.CanSoftDelete -}}
{{- $soft := and $data.AddSoftDeletes $canSoftDelete }}
{{if $options.AddGlobal -}}
// DeleteG deletes a single {{$alias.UpSingular}} record.
// DeleteG will match against the primary key column to find the record to delete.
func (o *{{$alias.UpSingular}}) DeleteG({{if not $data.NoContext}}ctx context.Context{{if $soft}}, hardDelete bool{{end}}{{else}}{{if $soft}}hardDelete bool{{end}}{{end}}) {{if $data.NoRowsAffected}}error{{else}}(int64, error){{end -}} {
	return o.Delete({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}{{if $soft}}, hardDelete{{end}})
}

{{end -}}

{{if $options.AddPanic -}}
// DeleteP deletes a single {{$alias.UpSingular}} record with an executor.
// DeleteP will match against the primary key column to find the record to delete.
// Panics on error.
func (o *{{$alias.UpSingular}}) DeleteP({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}{{if $soft}}, hardDelete bool{{end}}) {{if not $data.NoRowsAffected}}int64{{end -}} {
	{{if not $data.NoRowsAffected}}rowsAff, {{end}}err := o.Delete({{if not $data.NoContext}}ctx, {{end -}} exec{{if $soft}}, hardDelete{{end}})
	if err != nil {
		panic(simmer.WrapErr(err))
	}
	{{- if not $data.NoRowsAffected}}

	return rowsAff
	{{end -}}
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// DeleteGP deletes a single {{$alias.UpSingular}} record.
// DeleteGP will match against the primary key column to find the record to delete.
// Panics on error.
func (o *{{$alias.UpSingular}}) DeleteGP({{if not $data.NoContext}}ctx context.Context{{if $soft}}, hardDelete bool{{end}}{{else}}{{if $soft}}hardDelete bool{{end}}{{end}}) {{if not $data.NoRowsAffected}}int64{{end -}} {
	{{if not $data.NoRowsAffected}}rowsAff, {{end}}err := o.Delete({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}{{if $soft}}, hardDelete{{end}})
	if err != nil {
		panic(simmer.WrapErr(err))
	}
	{{- if not $data.NoRowsAffected}}

	return rowsAff
	{{end -}}
}

{{end -}}

// Delete deletes a single {{$alias.UpSingular}} record with an executor.
// Delete will match against the primary key column to find the record to delete.
func (o *{{$alias.UpSingular}}) Delete({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}{{if $soft}}, hardDelete bool{{end}}) {{if $data.NoRowsAffected}}error{{else}}(int64, error){{end -}} {
	if o == nil {
		return {{if not $data.NoRowsAffected}}0, {{end -}} errors.New("{{$options.PkgName}}: no {{$alias.UpSingular}} provided for delete")
	}

	{{if not $data.NoHooks -}}
	if err := o.doBeforeDeleteHooks({{if not $data.NoContext}}ctx, {{end -}} exec); err != nil {
		return {{if not $data.NoRowsAffected}}0, {{end -}} err
	}
	{{- end}}

	{{if $soft -}}
	var (
		sql string
		args []interface{}
	)
	if hardDelete {
		args = queries.ValuesFromMapping(reflect.Indirect(reflect.ValueOf(o)), {{$alias.DownSingular}}PrimaryKeyMapping)
		sql = "DELETE FROM {{$schemaTable}} WHERE {{if $data.Dialect.UseIndexPlaceholders}}{{whereClause $data.LQ $data.RQ 1 $model.Table.PKey.Columns}}{{else}}{{whereClause $data.LQ $data.RQ 0 $model.Table.PKey.Columns}}{{end}}"
	} else {
		currTime := time.Now().In(simmer.GetLocation())
		o.DeletedAt = null.TimeFrom(currTime)
		wl := []string{"deleted_at"}
		sql = fmt.Sprintf("UPDATE {{$schemaTable}} SET %s WHERE {{if $data.Dialect.UseIndexPlaceholders}}{{whereClause $data.LQ $data.RQ 2 $model.Table.PKey.Columns}}{{else}}{{whereClause $data.LQ $data.RQ 0 $model.Table.PKey.Columns}}{{end}}",
			strmangle.SetParamNames("{{$data.LQ}}", "{{$data.RQ}}", {{if $data.Dialect.UseIndexPlaceholders}}1{{else}}0{{end}}, wl),
		)
		valueMapping, err := queries.BindMapping({{$alias.DownSingular}}Type, {{$alias.DownSingular}}Mapping, append(wl, {{$alias.DownSingular}}PrimaryKeyColumns...))
		if err != nil {
			return {{if not $data.NoRowsAffected}}0, {{end -}} err
		}
		args = queries.ValuesFromMapping(reflect.Indirect(reflect.ValueOf(o)), valueMapping)
	}
	{{else -}}
	args := queries.ValuesFromMapping(reflect.Indirect(reflect.ValueOf(o)), {{$alias.DownSingular}}PrimaryKeyMapping)
	sql := "DELETE FROM {{$schemaTable}} WHERE {{if $data.Dialect.UseIndexPlaceholders}}{{whereClause $data.LQ $data.RQ 1 $model.Table.PKey.Columns}}{{else}}{{whereClause $data.LQ $data.RQ 0 $model.Table.PKey.Columns}}{{end}}"
	{{- end}}

	{{if $data.NoContext -}}
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

	{{if $data.NoRowsAffected -}}
		{{if $data.NoContext -}}
	_, err := exec.Exec(sql, args...)
		{{else -}}
	_, err := exec.ExecContext(ctx, sql, args...)
		{{end -}}
	{{else -}}
		{{if $data.NoContext -}}
	result, err := exec.Exec(sql, args...)
		{{else -}}
	result, err := exec.ExecContext(ctx, sql, args...)
		{{end -}}
	{{end -}}
	if err != nil {
		return {{if not $data.NoRowsAffected}}0, {{end -}} errors.Wrap(err, "{{$options.PkgName}}: unable to delete from {{$model.Table.Name}}")
	}

	{{if not $data.NoRowsAffected -}}
	rowsAff, err := result.RowsAffected()
	if err != nil {
		return 0, errors.Wrap(err, "{{$options.PkgName}}: failed to get rows affected by delete for {{$model.Table.Name}}")
	}

	{{end -}}

	{{if not $data.NoHooks -}}
	if err := o.doAfterDeleteHooks({{if not $data.NoContext}}ctx, {{end -}} exec); err != nil {
		return {{if not $data.NoRowsAffected}}0, {{end -}} err
	}
	{{- end}}

	return {{if not $data.NoRowsAffected}}rowsAff, {{end -}} nil
}

{{if $options.AddGlobal -}}
func (q {{$alias.DownSingular}}Query) DeleteAllG({{if not $data.NoContext}}ctx context.Context{{end}}{{if $soft}}, hardDelete bool{{end}}) {{if $data.NoRowsAffected}}error{{else}}(int64, error){{end -}} {
	return q.DeleteAll({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}{{if $soft}}, hardDelete{{end}})
}

{{end -}}

{{if $options.AddPanic -}}
// DeleteAllP deletes all rows, and panics on error.
func (q {{$alias.DownSingular}}Query) DeleteAllP({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}{{if $soft}}, hardDelete bool{{end}}) {{if not $data.NoRowsAffected}}int64{{end -}} {
	{{if not $data.NoRowsAffected}}rowsAff, {{end -}} err := q.DeleteAll({{if not $data.NoContext}}ctx, {{end -}} exec{{if $soft}}, hardDelete{{end}})
	if err != nil {
		panic(simmer.WrapErr(err))
	}
	{{- if not $data.NoRowsAffected}}

	return rowsAff
	{{end -}}
}

{{end -}}

// DeleteAll deletes all matching rows.
func (q {{$alias.DownSingular}}Query) DeleteAll({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}{{if $soft}}, hardDelete bool{{end}}) {{if $data.NoRowsAffected}}error{{else}}(int64, error){{end -}} {
	if q.Query == nil {
		return {{if not $data.NoRowsAffected}}0, {{end -}} errors.New("{{$options.PkgName}}: no {{$alias.DownSingular}}Query provided for delete all")
	}

	{{if $soft -}}
	if hardDelete {
		queries.SetDelete(q.Query)
	} else {
		currTime := time.Now().In(simmer.GetLocation())
		queries.SetUpdate(q.Query, M{"deleted_at": currTime})
	}
	{{else -}}
	queries.SetDelete(q.Query)
	{{- end}}

	{{if $data.NoRowsAffected -}}
		{{if $data.NoContext -}}
	_, err := q.Query.Exec(exec)
		{{else -}}
	_, err := q.Query.ExecContext(ctx, exec)
		{{end -}}
	{{else -}}
		{{if $data.NoContext -}}
	result, err := q.Query.Exec(exec)
		{{else -}}
	result, err := q.Query.ExecContext(ctx, exec)
		{{end -}}
	{{end -}}
	if err != nil {
		return {{if not $data.NoRowsAffected}}0, {{end -}} errors.Wrap(err, "{{$options.PkgName}}: unable to delete all from {{$model.Table.Name}}")
	}

	{{if not $data.NoRowsAffected -}}
	rowsAff, err := result.RowsAffected()
	if err != nil {
		return 0, errors.Wrap(err, "{{$options.PkgName}}: failed to get rows affected by deleteall for {{$model.Table.Name}}")
	}

	{{end -}}

	return {{if not $data.NoRowsAffected}}rowsAff, {{end -}} nil
}

{{if $options.AddGlobal -}}
// DeleteAllG deletes all rows in the slice.
func (o {{$alias.UpSingular}}Slice) DeleteAllG({{if not $data.NoContext}}ctx context.Context{{if $soft}}, hardDelete bool{{end}}{{else}}{{if $soft}}hardDelete bool{{end}}{{end}}) {{if $data.NoRowsAffected}}error{{else}}(int64, error){{end -}} {
	return o.DeleteAll({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}{{if $soft}}, hardDelete{{end}})
}

{{end -}}

{{if $options.AddPanic -}}
// DeleteAllP deletes all rows in the slice, using an executor, and panics on error.
func (o {{$alias.UpSingular}}Slice) DeleteAllP({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}{{if $soft}}, hardDelete bool{{end}}) {{if not $data.NoRowsAffected}}int64{{end -}} {
	{{if not $data.NoRowsAffected}}rowsAff, {{end -}} err := o.DeleteAll({{if not $data.NoContext}}ctx, {{end -}} exec{{if $soft}}, hardDelete{{end}})
	if err != nil {
		panic(simmer.WrapErr(err))
	}
	{{- if not $data.NoRowsAffected}}

	return rowsAff
	{{end -}}
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// DeleteAllGP deletes all rows in the slice, and panics on error.
func (o {{$alias.UpSingular}}Slice) DeleteAllGP({{if not $data.NoContext}}ctx context.Context{{if $soft}}, hardDelete bool{{end}}{{else}}{{if $soft}}hardDelete bool{{end}}{{end}}) {{if not $data.NoRowsAffected}}int64{{end -}} {
	{{if not $data.NoRowsAffected}}rowsAff, {{end -}} err := o.DeleteAll({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}{{if $soft}}, hardDelete{{end}})
	if err != nil {
		panic(simmer.WrapErr(err))
	}
	{{- if not $data.NoRowsAffected}}

	return rowsAff
	{{end -}}
}

{{end -}}

// DeleteAll deletes all rows in the slice, using an executor.
func (o {{$alias.UpSingular}}Slice) DeleteAll({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}{{if $soft}}, hardDelete bool{{end}}) {{if $data.NoRowsAffected}}error{{else}}(int64, error){{end -}} {
	if len(o) == 0 {
		return {{if not $data.NoRowsAffected}}0, {{end -}} nil
	}

	{{if not $data.NoHooks -}}
	if len({{$alias.DownSingular}}BeforeDeleteHooks) != 0 {
		for _, obj := range o {
			if err := obj.doBeforeDeleteHooks({{if not $data.NoContext}}ctx, {{end -}} exec); err != nil {
				return {{if not $data.NoRowsAffected}}0, {{end -}} err
			}
		}
	}
	{{- end}}

	{{if $soft -}}
	var (
		sql string
		args []interface{}
	)
	if hardDelete {
		for _, obj := range o {
    		pkeyArgs := queries.ValuesFromMapping(reflect.Indirect(reflect.ValueOf(obj)), {{$alias.DownSingular}}PrimaryKeyMapping)
    		args = append(args, pkeyArgs...)
    	}
		sql = "DELETE FROM {{$schemaTable}} WHERE " +
			strmangle.WhereClauseRepeated(string(dialect.LQ), string(dialect.RQ), {{if $data.Dialect.UseIndexPlaceholders}}1{{else}}0{{end}}, {{$alias.DownSingular}}PrimaryKeyColumns, len(o))
	} else {
		currTime := time.Now().In(simmer.GetLocation())
		for _, obj := range o {
			pkeyArgs := queries.ValuesFromMapping(reflect.Indirect(reflect.ValueOf(obj)), {{$alias.DownSingular}}PrimaryKeyMapping)
			args = append(args, pkeyArgs...)
			obj.DeletedAt = null.TimeFrom(currTime)
		}
		wl := []string{"deleted_at"}
		sql = fmt.Sprintf("UPDATE {{$schemaTable}} SET %s WHERE " +
			strmangle.WhereClauseRepeated(string(dialect.LQ), string(dialect.RQ), {{if $data.Dialect.UseIndexPlaceholders}}2{{else}}0{{end}}, {{$alias.DownSingular}}PrimaryKeyColumns, len(o)),
			strmangle.SetParamNames("{{$data.LQ}}", "{{$data.RQ}}", {{if $data.Dialect.UseIndexPlaceholders}}1{{else}}0{{end}}, wl),
		)
		args = append([]interface{}{currTime}, args...)
	}
	{{else -}}
	var args []interface{}
	for _, obj := range o {
		pkeyArgs := queries.ValuesFromMapping(reflect.Indirect(reflect.ValueOf(obj)), {{$alias.DownSingular}}PrimaryKeyMapping)
		args = append(args, pkeyArgs...)
	}

	sql := "DELETE FROM {{$schemaTable}} WHERE " +
		strmangle.WhereClauseRepeated(string(dialect.LQ), string(dialect.RQ), {{if $data.Dialect.UseIndexPlaceholders}}1{{else}}0{{end}}, {{$alias.DownSingular}}PrimaryKeyColumns, len(o))
	{{- end}}

	{{if $data.NoContext -}}
	if simmer.DebugMode {
		fmt.Fprintln(simmer.DebugWriter, sql)
		fmt.Fprintln(simmer.DebugWriter, args)
	}
	{{else -}}
	if simmer.IsDebug(ctx) {
		writer := simmer.DebugWriterFrom(ctx)
		fmt.Fprintln(writer, sql)
		fmt.Fprintln(writer, args)
	}
	{{end -}}

	{{if $data.NoRowsAffected -}}
		{{if $data.NoContext -}}
	_, err := exec.Exec(sql, args...)
		{{else -}}
	_, err := exec.ExecContext(ctx, sql, args...)
		{{end -}}
	{{else -}}
		{{if $data.NoContext -}}
	result, err := exec.Exec(sql, args...)
		{{else -}}
	result, err := exec.ExecContext(ctx, sql, args...)
		{{end -}}
	{{end -}}
	if err != nil {
		return {{if not $data.NoRowsAffected}}0, {{end -}} errors.Wrap(err, "{{$options.PkgName}}: unable to delete all from {{$alias.DownSingular}} slice")
	}

	{{if not $data.NoRowsAffected -}}
	rowsAff, err := result.RowsAffected()
	if err != nil {
		return 0, errors.Wrap(err, "{{$options.PkgName}}: failed to get rows affected by deleteall for {{$model.Table.Name}}")
	}

	{{end -}}

	{{if not $data.NoHooks -}}
	if len({{$alias.DownSingular}}AfterDeleteHooks) != 0 {
		for _, obj := range o {
			if err := obj.doAfterDeleteHooks({{if not $data.NoContext}}ctx, {{end -}} exec); err != nil {
				return {{if not $data.NoRowsAffected}}0, {{end -}} err
			}
		}
	}
	{{- end}}

	return {{if not $data.NoRowsAffected}}rowsAff, {{end -}} nil
}
