{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- if $model.Table.IsJoinTable -}}
{{- else -}}
	{{- range $rel := $model.Table.ToOneRelationships -}}
		{{- $ltable := $data.Aliases.Table $rel.Table -}}
		{{- $ftable := $data.Aliases.Table $rel.ForeignTable -}}
		{{- $relAlias := $ftable.Relationship $rel.Name -}}
		{{- $col := $ltable.Column $rel.Column -}}
		{{- $fcol := $ftable.Column $rel.ForeignColumn -}}
		{{- $usesPrimitives := usesPrimitives $data.Tables $rel.Table $rel.Column $rel.ForeignTable $rel.ForeignColumn -}}
		{{- $arg := printf "maybe%s" $ltable.UpSingular -}}
		{{- $canSoftDelete := (getTable $data.Tables $rel.ForeignTable).CanSoftDelete }}
// Load{{$relAlias.Local}} allows an eager lookup of values, cached into the
// loaded structs of the objects. This is for a 1-1 relationship.
func ({{$ltable.DownSingular}}L) Load{{$relAlias.Local}}({{if $data.NoContext}}e simmer.Executor{{else}}ctx context.Context, e simmer.ContextExecutor{{end}}, singular bool, {{$arg}} interface{}, mods queries.Applicator) error {
	var slice []*{{$ltable.UpSingular}}
	var object *{{$ltable.UpSingular}}

	if singular {
		object = {{$arg}}.(*{{$ltable.UpSingular}})
	} else {
		slice = *{{$arg}}.(*[]*{{$ltable.UpSingular}})
	}

	args := make([]interface{}, 0, 1)
	if singular {
		if object.R == nil {
			object.R = &{{$ltable.DownSingular}}R{}
		}
		args = append(args, object.{{$col}})
	} else {
		Outer:
		for _, obj := range slice {
			if obj.R == nil {
				obj.R = &{{$ltable.DownSingular}}R{}
			}

			for _, a := range args {
				{{if $usesPrimitives -}}
				if a == obj.{{$col}} {
				{{else -}}
				if queries.Equal(a, obj.{{$col}}) {
				{{end -}}
					continue Outer
				}
			}

			args = append(args, obj.{{$col}})
		}
	}

	if len(args) == 0 {
		return nil
	}

	query := NewQuery(
	    queries.From(`{{if $data.Dialect.UseSchema}}{{$data.Schema}}.{{end}}{{.ForeignTable}}`),
        queries.WhereIn(`{{if $data.Dialect.UseSchema}}{{$data.Schema}}.{{end}}{{.ForeignTable}}.{{.ForeignColumn}} in ?`, args...),
	    {{if and $data.AddSoftDeletes $canSoftDelete -}}
	    queries.WhereIsNull(`{{if $data.Dialect.UseSchema}}{{$data.Schema}}.{{end}}{{.ForeignTable}}.deleted_at`),
	    {{- end}}
    )
	if mods != nil {
		mods.Apply(query)
	}

	{{if $data.NoContext -}}
	results, err := query.Query(e)
	{{else -}}
	results, err := query.QueryContext(ctx, e)
	{{end -}}
	if err != nil {
		return errors.Wrap(err, "failed to eager load {{$ftable.UpSingular}}")
	}

	var resultSlice []*{{$ftable.UpSingular}}
	if err = queries.Bind(results, &resultSlice); err != nil {
		return errors.Wrap(err, "failed to bind eager loaded slice {{$ftable.UpSingular}}")
	}

	if err = results.Close(); err != nil {
		return errors.Wrap(err, "failed to close results of eager load for {{.ForeignTable}}")
	}
	if err = results.Err(); err != nil {
		return errors.Wrap(err, "error occurred during iteration of eager loaded relations for {{.ForeignTable}}")
	}

	{{if not $data.NoHooks -}}
	if len({{$ltable.DownSingular}}AfterSelectHooks) != 0 {
		for _, obj := range resultSlice {
			if err := obj.doAfterSelectHooks({{if $data.NoContext}}e{{else}}ctx, e{{end}}); err != nil {
				return err
			}
		}
	}
	{{- end}}

	if len(resultSlice) == 0 {
		return nil
	}

	if singular {
		foreign := resultSlice[0]
		object.R.{{$relAlias.Local}} = foreign
		{{if not $options.NoBackReferencing -}}
		if foreign.R == nil {
			foreign.R = &{{$ftable.DownSingular}}R{}
		}
		foreign.R.{{$relAlias.Foreign}} = object
		{{end -}}
	}

	for _, local := range slice {
		for _, foreign := range resultSlice {
			{{if $usesPrimitives -}}
			if local.{{$col}} == foreign.{{$fcol}} {
			{{else -}}
			if queries.Equal(local.{{$col}}, foreign.{{$fcol}}) {
			{{end -}}
				local.R.{{$relAlias.Local}} = foreign
				{{if not $options.NoBackReferencing -}}
				if foreign.R == nil {
					foreign.R = &{{$ftable.DownSingular}}R{}
				}
				foreign.R.{{$relAlias.Foreign}} = local
				{{end -}}
				break
			}
		}
	}

	return nil
}
{{end -}}{{/* range */}}
{{end}}{{/* join table */}}
