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
		{{- $schemaForeignTable := $rel.ForeignTable | $data.SchemaTable -}}
		{{- $foreignPKeyCols := (getTable $data.Tables .ForeignTable).PKey.Columns }}
{{if $options.AddGlobal -}}
// Set{{$relAlias.Local}}G of the {{$ltable.DownSingular}} to the related item.
// Sets o.R.{{$relAlias.Local}} to related.
// Adds o to related.R.{{$relAlias.Foreign}}.
// Uses the global database handle.
func (o *{{$ltable.UpSingular}}) Set{{$relAlias.Local}}G({{if not $data.NoContext}}ctx context.Context, {{end -}} insert bool, related *{{$ftable.UpSingular}}) error {
	return o.Set{{$relAlias.Local}}({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, insert, related)
}

{{end -}}

{{if $options.AddPanic -}}
// Set{{$relAlias.Local}}P of the {{$ltable.DownSingular}} to the related item.
// Sets o.R.{{$relAlias.Local}} to related.
// Adds o to related.R.{{$relAlias.Foreign}}.
// Panics on error.
func (o *{{$ltable.UpSingular}}) Set{{$relAlias.Local}}P({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, insert bool, related *{{$ftable.UpSingular}}) {
	if err := o.Set{{$relAlias.Local}}({{if not $data.NoContext}}ctx, {{end -}} exec, insert, related); err != nil {
		panic(simmer.WrapErr(err))
	}
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// Set{{$relAlias.Local}}GP of the {{$ltable.DownSingular}} to the related item.
// Sets o.R.{{$relAlias.Local}} to related.
// Adds o to related.R.{{$relAlias.Foreign}}.
// Uses the global database handle and panics on error.
func (o *{{$ltable.UpSingular}}) Set{{$relAlias.Local}}GP({{if not $data.NoContext}}ctx context.Context, {{end -}} insert bool, related *{{$ftable.UpSingular}}) {
	if err := o.Set{{$relAlias.Local}}({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, insert, related); err != nil {
		panic(simmer.WrapErr(err))
	}
}

{{end -}}

// Set{{$relAlias.Local}} of the {{$ltable.DownSingular}} to the related item.
// Sets o.R.{{$relAlias.Local}} to related.
// Adds o to related.R.{{$relAlias.Foreign}}.
func (o *{{$ltable.UpSingular}}) Set{{$relAlias.Local}}({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, insert bool, related *{{$ftable.UpSingular}}) error {
	var err error

	if insert {
		{{if $usesPrimitives -}}
		related.{{$fcol}} = o.{{$col}}
		{{else -}}
		queries.Assign(&related.{{$fcol}}, o.{{$col}})
		{{- end}}

		if err = related.Insert({{if not $data.NoContext}}ctx, {{end -}} exec, simmer.Infer()); err != nil {
			return errors.Wrap(err, "failed to insert into foreign table")
		}
	} else {
		updateQuery := fmt.Sprintf(
			"UPDATE {{$schemaForeignTable}} SET %s WHERE %s",
			strmangle.SetParamNames("{{$data.LQ}}", "{{$data.RQ}}", {{if $data.Dialect.UseIndexPlaceholders}}1{{else}}0{{end}}, []string{{"{"}}"{{.ForeignColumn}}"{{"}"}}),
			strmangle.WhereClause("{{$data.LQ}}", "{{$data.RQ}}", {{if $data.Dialect.UseIndexPlaceholders}}2{{else}}0{{end}}, {{$ftable.DownSingular}}PrimaryKeyColumns),
		)
		values := []interface{}{o.{{$col}}, related.{{$foreignPKeyCols | stringMap (aliasCols $ftable) | join ", related."}}{{"}"}}

		{{if $data.NoContext -}}
		if simmer.DebugMode {
			fmt.Fprintln(simmer.DebugWriter, updateQuery)
			fmt.Fprintln(simmer.DebugWriter, values)
		}
		{{else -}}
		if simmer.IsDebug(ctx) {
		writer := simmer.DebugWriterFrom(ctx)
			fmt.Fprintln(writer, updateQuery)
			fmt.Fprintln(writer, values)
		}
		{{end -}}

		{{if $data.NoContext -}}
		if _, err = exec.Exec(updateQuery, values...); err != nil {
		{{else -}}
		if _, err = exec.ExecContext(ctx, updateQuery, values...); err != nil {
		{{end -}}
			return errors.Wrap(err, "failed to update foreign table")
		}

		{{if $usesPrimitives -}}
		related.{{$fcol}} = o.{{$col}}
		{{else -}}
		queries.Assign(&related.{{$fcol}}, o.{{$col}})
		{{- end}}
	}


	if o.R == nil {
		o.R = &{{$ltable.DownSingular}}R{
			{{$relAlias.Local}}: related,
		}
	} else {
		o.R.{{$relAlias.Local}} = related
	}

	if related.R == nil {
		related.R = &{{$ftable.DownSingular}}R{
			{{$relAlias.Foreign}}: o,
		}
	} else {
		related.R.{{$relAlias.Foreign}} = o
	}
	return nil
}

		{{- if .ForeignColumnNullable}}
{{if $options.AddGlobal -}}
// Remove{{$relAlias.Local}}G relationship.
// Sets o.R.{{$relAlias.Local}} to nil.
// Removes o from all passed in related items' relationships struct (Optional).
// Uses the global database handle.
func (o *{{$ltable.UpSingular}}) Remove{{$relAlias.Local}}G({{if not $data.NoContext}}ctx context.Context, {{end -}} related *{{$ftable.UpSingular}}) error {
	return o.Remove{{$relAlias.Local}}({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, related)
}

{{end -}}

{{if $options.AddPanic -}}
// Remove{{$relAlias.Local}}P relationship.
// Sets o.R.{{$relAlias.Local}} to nil.
// Removes o from all passed in related items' relationships struct (Optional).
// Panics on error.
func (o *{{$ltable.UpSingular}}) Remove{{$relAlias.Local}}P({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, related *{{$ftable.UpSingular}}) {
	if err := o.Remove{{$relAlias.Local}}({{if not $data.NoContext}}ctx, {{end -}} exec, related); err != nil {
		panic(simmer.WrapErr(err))
	}
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// Remove{{$relAlias.Local}}GP relationship.
// Sets o.R.{{$relAlias.Local}} to nil.
// Removes o from all passed in related items' relationships struct (Optional).
// Uses the global database handle and panics on error.
func (o *{{$ltable.UpSingular}}) Remove{{$relAlias.Local}}GP({{if not $data.NoContext}}ctx context.Context, {{end -}} related *{{$ftable.UpSingular}}) {
	if err := o.Remove{{$relAlias.Local}}({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, related); err != nil {
		panic(simmer.WrapErr(err))
	}
}

{{end -}}

// Remove{{$relAlias.Local}} relationship.
// Sets o.R.{{$relAlias.Local}} to nil.
// Removes o from all passed in related items' relationships struct (Optional).
func (o *{{$ltable.UpSingular}}) Remove{{$relAlias.Local}}({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, related *{{$ftable.UpSingular}}) error {
	var err error

	queries.SetScanner(&related.{{$fcol}}, nil)
	if {{if not $data.NoRowsAffected}}_, {{end -}} err = related.Update({{if not $data.NoContext}}ctx, {{end -}} exec, simmer.Whitelist("{{.ForeignColumn}}")); err != nil {
		return errors.Wrap(err, "failed to update local table")
	}

	if o.R != nil {
		o.R.{{$relAlias.Local}} = nil
	}
	if related == nil || related.R == nil {
		return nil
	}

	related.R.{{$relAlias.Foreign}} = nil
	return nil
}
{{end -}}{{/* if foreignkey nullable */}}
{{- end -}}{{/* range */}}
{{- end -}}{{/* join table */}}
