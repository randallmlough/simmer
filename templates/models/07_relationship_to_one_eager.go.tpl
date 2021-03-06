{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- if $model.Table.IsJoinTable -}}
{{- else -}}
	{{- range $fkey := $model.Table.FKeys -}}
		{{- $ltable := $data.Aliases.Table $fkey.Table -}}
		{{- $ftable := $data.Aliases.Table $fkey.ForeignTable -}}
		{{- $rel := $ltable.Relationship $fkey.Name -}}
		{{- $arg := printf "maybe%s" $ltable.UpSingular -}}
		{{- $col := $ltable.Column $fkey.Column -}}
		{{- $fcol := $ftable.Column $fkey.ForeignColumn -}}
		{{- $usesPrimitives := usesPrimitives $data.Tables $fkey.Table $fkey.Column $fkey.ForeignTable $fkey.ForeignColumn -}}
		{{- $canSoftDelete := (getTable $data.Tables $fkey.ForeignTable).CanSoftDelete }}
// Load{{$rel.Foreign}} allows an eager lookup of values, cached into the
// loaded structs of the objects. This is for an N-1 relationship.
func ({{$ltable.DownSingular}}L) Load{{$rel.Foreign}}({{if $options.NoContext}}e simmer.Executor{{else}}ctx context.Context, e simmer.ContextExecutor{{end}}, singular bool, {{$arg}} interface{}, mods queries.Applicator) error {
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
		{{if $usesPrimitives -}}
		args = append(args, object.{{$col}})
		{{else -}}
		if !queries.IsNil(object.{{$col}}) {
			args = append(args, object.{{$col}})
		}
		{{end}}
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

			{{if $usesPrimitives -}}
			args = append(args, obj.{{$col}})
			{{else -}}
			if !queries.IsNil(obj.{{$col}}) {
				args = append(args, obj.{{$col}})
			}
			{{end}}
		}
	}

	if len(args) == 0 {
		return nil
	}

	query := NewQuery(
	    queries.From(`{{if $data.Dialect.UseSchema}}{{$data.Schema}}.{{end}}{{.ForeignTable}}`),
	    queries.WhereIn(`{{if $data.Dialect.UseSchema}}{{$data.Schema}}.{{end}}{{.ForeignTable}}.{{.ForeignColumn}} in ?`, args...),
	    {{if and $options.AddSoftDeletes $canSoftDelete -}}
	    queries.WhereIsNull(`{{if $data.Dialect.UseSchema}}{{$data.Schema}}.{{end}}{{.ForeignTable}}.deleted_at`),
	    {{- end}}
    )
	if mods != nil {
		mods.Apply(query)
	}

	{{if $options.NoContext -}}
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

	{{if not $options.NoHooks -}}
	if len({{$ltable.DownSingular}}AfterSelectHooks) != 0 {
		for _, obj := range resultSlice {
			if err := obj.doAfterSelectHooks({{if $options.NoContext}}e{{else}}ctx, e{{end}}); err != nil {
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
		object.R.{{$rel.Foreign}} = foreign
		{{if not $options.NoBackReferencing -}}
		if foreign.R == nil {
			foreign.R = &{{$ftable.DownSingular}}R{}
		}
			{{if $fkey.Unique -}}
		foreign.R.{{$rel.Local}} = object
			{{else -}}
		foreign.R.{{$rel.Local}} = append(foreign.R.{{$rel.Local}}, object)
			{{end -}}
		{{end -}}
		return nil
	}

	for _, local := range slice {
		for _, foreign := range resultSlice {
			{{if $usesPrimitives -}}
			if local.{{$col}} == foreign.{{$fcol}} {
			{{else -}}
			if queries.Equal(local.{{$col}}, foreign.{{$fcol}}) {
			{{end -}}
				local.R.{{$rel.Foreign}} = foreign
				{{if not $options.NoBackReferencing -}}
				if foreign.R == nil {
					foreign.R = &{{$ftable.DownSingular}}R{}
				}
					{{if $fkey.Unique -}}
				foreign.R.{{$rel.Local}} = local
					{{else -}}
				foreign.R.{{$rel.Local}} = append(foreign.R.{{$rel.Local}}, local)
					{{end -}}
				{{end -}}
				break
			}
		}
	}

	return nil
}
{{end -}}{{/* range */}}
{{end}}{{/* join table */}}
