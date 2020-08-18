{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- $alias := $data.Aliases.Table $model.Table.Name -}}
{{- $schemaTable := $model.Table.Name | $data.SchemaTable -}}
{{- $canSoftDelete := $model.Table.CanSoftDelete }}
{{if $options.AddGlobal -}}
// ReloadG refetches the object from the database using the primary keys.
func (o *{{$alias.UpSingular}}) ReloadG({{if not $data.NoContext}}ctx context.Context{{end}}) error {
	if o == nil {
		return errors.New("{{$options.PkgName}}: no {{$alias.UpSingular}} provided for reload")
	}

	return o.Reload({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}})
}

{{end -}}

{{if $options.AddPanic -}}
// ReloadP refetches the object from the database with an executor. Panics on error.
func (o *{{$alias.UpSingular}}) ReloadP({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) {
	if err := o.Reload({{if not $data.NoContext}}ctx, {{end -}} exec); err != nil {
		panic(simmer.WrapErr(err))
	}
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// ReloadGP refetches the object from the database and panics on error.
func (o *{{$alias.UpSingular}}) ReloadGP({{if not $data.NoContext}}ctx context.Context{{end}}) {
	if err := o.Reload({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}); err != nil {
		panic(simmer.WrapErr(err))
	}
}

{{end -}}

// Reload refetches the object from the database
// using the primary keys with an executor.
func (o *{{$alias.UpSingular}}) Reload({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) error {
	ret, err := Find{{$alias.UpSingular}}({{if not $data.NoContext}}ctx, {{end -}} exec, {{$model.Table.PKey.Columns | stringMap (aliasCols $alias) | prefixStringSlice "o." | join ", "}})
	if err != nil {
		return err
	}

	*o = *ret
	return nil
}

{{if $options.AddGlobal -}}
// ReloadAllG refetches every row with matching primary key column values
// and overwrites the original object slice with the newly updated slice.
func (o *{{$alias.UpSingular}}Slice) ReloadAllG({{if not $data.NoContext}}ctx context.Context{{end}}) error {
	if o == nil {
		return errors.New("{{$options.PkgName}}: empty {{$alias.UpSingular}}Slice provided for reload all")
	}

	return o.ReloadAll({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}})
}

{{end -}}

{{if $options.AddPanic -}}
// ReloadAllP refetches every row with matching primary key column values
// and overwrites the original object slice with the newly updated slice.
// Panics on error.
func (o *{{$alias.UpSingular}}Slice) ReloadAllP({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) {
	if err := o.ReloadAll({{if not $data.NoContext}}ctx, {{end -}} exec); err != nil {
		panic(simmer.WrapErr(err))
	}
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// ReloadAllGP refetches every row with matching primary key column values
// and overwrites the original object slice with the newly updated slice.
// Panics on error.
func (o *{{$alias.UpSingular}}Slice) ReloadAllGP({{if not $data.NoContext}}ctx context.Context{{end}}) {
	if err := o.ReloadAll({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}); err != nil {
		panic(simmer.WrapErr(err))
	}
}

{{end -}}

// ReloadAll refetches every row with matching primary key column values
// and overwrites the original object slice with the newly updated slice.
func (o *{{$alias.UpSingular}}Slice) ReloadAll({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) error {
	if o == nil || len(*o) == 0 {
		return nil
	}

	slice := {{$alias.UpSingular}}Slice{}
	var args []interface{}
	for _, obj := range *o {
		pkeyArgs := queries.ValuesFromMapping(reflect.Indirect(reflect.ValueOf(obj)), {{$alias.DownSingular}}PrimaryKeyMapping)
		args = append(args, pkeyArgs...)
	}

	sql := "SELECT {{$schemaTable}}.* FROM {{$schemaTable}} WHERE " +
		strmangle.WhereClauseRepeated(string(dialect.LQ), string(dialect.RQ), {{if $data.Dialect.UseIndexPlaceholders}}1{{else}}0{{end}}, {{$alias.DownSingular}}PrimaryKeyColumns, len(*o)){{if and $data.AddSoftDeletes $canSoftDelete}} +
		"and {{"deleted_at" | $data.Quotes}} is null"
		{{- end}}

	q := queries.Raw(sql, args...)

	err := q.Bind({{if $data.NoContext}}nil{{else}}ctx{{end}}, exec, &slice)
	if err != nil {
		return errors.Wrap(err, "{{$options.PkgName}}: unable to reload all in {{$alias.UpSingular}}Slice")
	}

	*o = slice

	return nil
}
