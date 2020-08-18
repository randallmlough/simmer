{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- $alias := $data.Aliases.Table $model.Table.Name}}

{{if $options.AddGlobal -}}
// OneG returns a single {{$alias.DownSingular}} record from the query using the global executor.
func (q {{$alias.DownSingular}}Query) OneG({{if not $data.NoContext}}ctx context.Context{{end}}) (*{{$alias.UpSingular}}, error) {
	return q.One({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end -}})
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// OneGP returns a single {{$alias.DownSingular}} record from the query using the global executor, and panics on error.
func (q {{$alias.DownSingular}}Query) OneGP({{if not $data.NoContext}}ctx context.Context{{end}}) *{{$alias.UpSingular}} {
	o, err := q.One({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end -}})
	if err != nil {
		panic(simmer.WrapErr(err))
	}

	return o
}

{{end -}}

{{if $options.AddPanic -}}
// OneP returns a single {{$alias.DownSingular}} record from the query, and panics on error.
func (q {{$alias.DownSingular}}Query) OneP({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) (*{{$alias.UpSingular}}) {
	o, err := q.One({{if not $data.NoContext}}ctx, {{end -}} exec)
	if err != nil {
		panic(simmer.WrapErr(err))
	}

	return o
}

{{end -}}

// One returns a single {{$alias.DownSingular}} record from the query.
func (q {{$alias.DownSingular}}Query) One({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) (*{{$alias.UpSingular}}, error) {
	o := &{{$alias.UpSingular}}{}

	queries.SetLimit(q.Query, 1)

	err := q.Bind({{if $data.NoContext}}nil{{else}}ctx{{end}}, exec, o)
	if err != nil {
		if errors.Cause(err) == sql.ErrNoRows {
			return nil, sql.ErrNoRows
		}
		return nil, errors.Wrap(err, "{{$options.PkgName}}: failed to execute a one query for {{$model.Table.Name}}")
	}

	{{if not $data.NoHooks -}}
	if err := o.doAfterSelectHooks({{if not $data.NoContext}}ctx, {{end -}} exec); err != nil {
		return o, err
	}
	{{- end}}

	return o, nil
}

{{if $options.AddGlobal -}}
// AllG returns all {{$alias.UpSingular}} records from the query using the global executor.
func (q {{$alias.DownSingular}}Query) AllG({{if not $data.NoContext}}ctx context.Context{{end}}) ({{$alias.UpSingular}}Slice, error) {
	return q.All({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end -}})
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// AllGP returns all {{$alias.UpSingular}} records from the query using the global executor, and panics on error.
func (q {{$alias.DownSingular}}Query) AllGP({{if not $data.NoContext}}ctx context.Context{{end}}) {{$alias.UpSingular}}Slice {
	o, err := q.All({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end -}})
	if err != nil {
		panic(simmer.WrapErr(err))
	}

	return o
}

{{end -}}

{{if $options.AddPanic -}}
// AllP returns all {{$alias.UpSingular}} records from the query, and panics on error.
func (q {{$alias.DownSingular}}Query) AllP({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) {{$alias.UpSingular}}Slice {
	o, err := q.All({{if not $data.NoContext}}ctx, {{end -}} exec)
	if err != nil {
		panic(simmer.WrapErr(err))
	}

	return o
}

{{end -}}

// All returns all {{$alias.UpSingular}} records from the query.
func (q {{$alias.DownSingular}}Query) All({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) ({{$alias.UpSingular}}Slice, error) {
	var o []*{{$alias.UpSingular}}

	err := q.Bind({{if $data.NoContext}}nil{{else}}ctx{{end}}, exec, &o)
	if err != nil {
		return nil, errors.Wrap(err, "{{$options.PkgName}}: failed to assign all query results to {{$alias.UpSingular}} slice")
	}

	{{if not $data.NoHooks -}}
	if len({{$alias.DownSingular}}AfterSelectHooks) != 0 {
		for _, obj := range o {
			if err := obj.doAfterSelectHooks({{if not $data.NoContext}}ctx, {{end -}} exec); err != nil {
				return o, err
			}
		}
	}
	{{- end}}

	return o, nil
}

{{if $options.AddGlobal -}}
// CountG returns the count of all {{$alias.UpSingular}} records in the query, and panics on error.
func (q {{$alias.DownSingular}}Query) CountG({{if not $data.NoContext}}ctx context.Context{{end}}) (int64, error) {
	return q.Count({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end -}})
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// CountGP returns the count of all {{$alias.UpSingular}} records in the query using the global executor, and panics on error.
func (q {{$alias.DownSingular}}Query) CountGP({{if not $data.NoContext}}ctx context.Context{{end}}) int64 {
	c, err := q.Count({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end -}})
	if err != nil {
		panic(simmer.WrapErr(err))
	}

	return c
}

{{end -}}

{{if $options.AddPanic -}}
// CountP returns the count of all {{$alias.UpSingular}} records in the query, and panics on error.
func (q {{$alias.DownSingular}}Query) CountP({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) int64 {
	c, err := q.Count({{if not $data.NoContext}}ctx, {{end -}} exec)
	if err != nil {
		panic(simmer.WrapErr(err))
	}

	return c
}

{{end -}}

// Count returns the count of all {{$alias.UpSingular}} records in the query.
func (q {{$alias.DownSingular}}Query) Count({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) (int64, error) {
	var count int64

	queries.SetSelect(q.Query, nil)
	queries.SetCount(q.Query)

	{{if $data.NoContext -}}
	err := q.Query.QueryRow(exec).Scan(&count)
	{{else -}}
	err := q.Query.QueryRowContext(ctx, exec).Scan(&count)
	{{end -}}
	if err != nil {
		return 0, errors.Wrap(err, "{{$options.PkgName}}: failed to count {{$model.Table.Name}} rows")
	}

	return count, nil
}

{{if $options.AddGlobal -}}
// ExistsG checks if the row exists in the table, and panics on error.
func (q {{$alias.DownSingular}}Query) ExistsG({{if not $data.NoContext}}ctx context.Context{{end}}) (bool, error) {
	return q.Exists({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end -}})
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// ExistsGP checks if the row exists in the table using the global executor, and panics on error.
func (q {{$alias.DownSingular}}Query) ExistsGP({{if not $data.NoContext}}ctx context.Context{{end}}) bool {
	e, err := q.Exists({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end -}})
	if err != nil {
		panic(simmer.WrapErr(err))
	}

	return e
}

{{end -}}

{{if $options.AddPanic -}}
// ExistsP checks if the row exists in the table, and panics on error.
func (q {{$alias.DownSingular}}Query) ExistsP({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) bool {
	e, err := q.Exists({{if not $data.NoContext}}ctx, {{end -}} exec)
	if err != nil {
		panic(simmer.WrapErr(err))
	}

	return e
}

{{end -}}

// Exists checks if the row exists in the table.
func (q {{$alias.DownSingular}}Query) Exists({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) (bool, error) {
	var count int64

	queries.SetSelect(q.Query, nil)
	queries.SetCount(q.Query)
	queries.SetLimit(q.Query, 1)

	{{if $data.NoContext -}}
	err := q.Query.QueryRow(exec).Scan(&count)
	{{else -}}
	err := q.Query.QueryRowContext(ctx, exec).Scan(&count)
	{{end -}}
	if err != nil {
		return false, errors.Wrap(err, "{{$options.PkgName}}: failed to check if {{$model.Table.Name}} exists")
	}

	return count > 0, nil
}
