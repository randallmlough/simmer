{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- if $model.Table.IsJoinTable -}}
{{- else -}}
	{{- range $rel := $model.Table.ToManyRelationships -}}
		{{- $ltable := $data.Aliases.Table $rel.Table -}}
		{{- $ftable := $data.Aliases.Table $rel.ForeignTable -}}
		{{- $relAlias := $data.Aliases.ManyRelationship $rel.ForeignTable $rel.Name $rel.JoinTable $rel.JoinLocalFKeyName -}}
		{{- $col := $ltable.Column $rel.Column -}}
		{{- $fcol := $ftable.Column $rel.ForeignColumn -}}
		{{- $usesPrimitives := usesPrimitives $data.Tables $rel.Table $rel.Column $rel.ForeignTable $rel.ForeignColumn -}}
		{{- $arg := printf "maybe%s" $ltable.UpSingular -}}
		{{- $schemaForeignTable := $rel.ForeignTable | $data.SchemaTable -}}
		{{- $canSoftDelete := (getTable $data.Tables $rel.ForeignTable).CanSoftDelete }}
// Load{{$relAlias.Local}} allows an eager lookup of values, cached into the
// loaded structs of the objects. This is for a 1-M or N-M relationship.
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
		args = append(args, object.{{.Column | titleCase}})
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

			args = append(args, obj.{{.Column | titleCase}})
		}
	}

	if len(args) == 0 {
		return nil
	}

		{{if .ToJoinTable -}}
			{{- $schemaJoinTable := .JoinTable | $data.SchemaTable -}}
	query := NewQuery(
		queries.Select("{{$schemaForeignTable}}.*, {{id 0 | $data.Quotes}}.{{.JoinLocalColumn | $data.Quotes}}"),
		queries.From("{{$schemaForeignTable}}"),
		queries.InnerJoin("{{$schemaJoinTable}} as {{id 0 | $data.Quotes}} on {{$schemaForeignTable}}.{{.ForeignColumn | $data.Quotes}} = {{id 0 | $data.Quotes}}.{{.JoinForeignColumn | $data.Quotes}}"),
		queries.WhereIn("{{id 0 | $data.Quotes}}.{{.JoinLocalColumn | $data.Quotes}} in ?", args...),
		{{if and $data.AddSoftDeletes $canSoftDelete -}}
		queries.WhereIsNull("{{$schemaForeignTable}}.{{"deleted_at" | $data.Quotes}}"),
		{{- end}}
	)
		{{else -}}
	query := NewQuery(
	    queries.From(`{{if $data.Dialect.UseSchema}}{{$data.Schema}}.{{end}}{{.ForeignTable}}`),
	    queries.WhereIn(`{{if $data.Dialect.UseSchema}}{{$data.Schema}}.{{end}}{{.ForeignTable}}.{{.ForeignColumn}} in ?`, args...),
	    {{if and $data.AddSoftDeletes $canSoftDelete -}}
	    queries.WhereIsNull(`{{if $data.Dialect.UseSchema}}{{$data.Schema}}.{{end}}{{.ForeignTable}}.deleted_at`),
	    {{- end}}
    )
		{{end -}}
	if mods != nil {
		mods.Apply(query)
	}

	{{if $data.NoContext -}}
	results, err := query.Query(e)
	{{else -}}
	results, err := query.QueryContext(ctx, e)
	{{end -}}
	if err != nil {
		return errors.Wrap(err, "failed to eager load {{.ForeignTable}}")
	}

	var resultSlice []*{{$ftable.UpSingular}}
	{{if .ToJoinTable -}}
	{{- $foreignTable := getTable $data.Tables .ForeignTable -}}
	{{- $joinTable := getTable $data.Tables .JoinTable -}}
	{{- $localCol := $joinTable.GetColumn .JoinLocalColumn}}
	var localJoinCols []{{$localCol.Type}}
	for results.Next() {
		one := new({{$ftable.UpSingular}})
		var localJoinCol {{$localCol.Type}}

		err = results.Scan({{$foreignTable.Columns | columnNames | stringMap (aliasCols $ftable) | prefixStringSlice "&one." | join ", "}}, &localJoinCol)
		if err != nil {
			return errors.Wrap(err, "failed to scan eager loaded results for {{.ForeignTable}}")
		}
		if err = results.Err(); err != nil {
			return errors.Wrap(err, "failed to plebian-bind eager loaded slice {{.ForeignTable}}")
		}

		resultSlice = append(resultSlice, one)
		localJoinCols = append(localJoinCols, localJoinCol)
	}
	{{- else -}}
	if err = queries.Bind(results, &resultSlice); err != nil {
		return errors.Wrap(err, "failed to bind eager loaded slice {{.ForeignTable}}")
	}
	{{- end}}

	if err = results.Close(); err != nil {
		return errors.Wrap(err, "failed to close results in eager load on {{.ForeignTable}}")
	}
	if err = results.Err(); err != nil {
		return errors.Wrap(err, "error occurred during iteration of eager loaded relations for {{.ForeignTable}}")
	}

	{{if not $data.NoHooks -}}
	if len({{$ftable.DownSingular}}AfterSelectHooks) != 0 {
		for _, obj := range resultSlice {
			if err := obj.doAfterSelectHooks({{if $data.NoContext}}e{{else}}ctx, e{{end -}}); err != nil {
				return err
			}
		}
	}

	{{- end}}
	if singular {
		object.R.{{$relAlias.Local}} = resultSlice
		{{if not $options.NoBackReferencing -}}
		for _, foreign := range resultSlice {
			if foreign.R == nil {
				foreign.R = &{{$ftable.DownSingular}}R{}
			}
			{{if .ToJoinTable -}}
			foreign.R.{{$relAlias.Foreign}} = append(foreign.R.{{$relAlias.Foreign}}, object)
			{{else -}}
			foreign.R.{{$relAlias.Foreign}} = object
			{{end -}}
		}
		{{end -}}
		return nil
	}

	{{if .ToJoinTable -}}
	for i, foreign := range resultSlice {
		localJoinCol := localJoinCols[i]
		for _, local := range slice {
			{{if $usesPrimitives -}}
			if local.{{$col}} == localJoinCol {
			{{else -}}
			if queries.Equal(local.{{$col}}, localJoinCol) {
			{{end -}}
				local.R.{{$relAlias.Local}} = append(local.R.{{$relAlias.Local}}, foreign)
				{{if not $options.NoBackReferencing -}}
				if foreign.R == nil {
					foreign.R = &{{$ftable.DownSingular}}R{}
				}
				foreign.R.{{$relAlias.Foreign}} = append(foreign.R.{{$relAlias.Foreign}}, local)
				{{end -}}
				break
			}
		}
	}
	{{else -}}
	for _, foreign := range resultSlice {
		for _, local := range slice {
			{{if $usesPrimitives -}}
			if local.{{$col}} == foreign.{{$fcol}} {
			{{else -}}
			if queries.Equal(local.{{$col}}, foreign.{{$fcol}}) {
			{{end -}}
				local.R.{{$relAlias.Local}} = append(local.R.{{$relAlias.Local}}, foreign)
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
	{{end}}

	return nil
}

{{end -}}{{/* range tomany */}}
{{- end -}}{{/* if IsJoinTable */}}
