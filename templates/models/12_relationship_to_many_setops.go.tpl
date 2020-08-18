{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- if $model.Table.IsJoinTable -}}
{{- else -}}
	{{- $table := $model.Table -}}
	{{- range $rel := $model.Table.ToManyRelationships -}}
		{{- $ltable := $data.Aliases.Table $rel.Table -}}
		{{- $ftable := $data.Aliases.Table $rel.ForeignTable -}}
		{{- $relAlias := $data.Aliases.ManyRelationship $rel.ForeignTable $rel.Name $rel.JoinTable $rel.JoinLocalFKeyName -}}
		{{- $col := $ltable.Column $rel.Column -}}
		{{- $fcol := $ftable.Column $rel.ForeignColumn -}}
		{{- $usesPrimitives := usesPrimitives $data.Tables $rel.Table $rel.Column $rel.ForeignTable $rel.ForeignColumn -}}
		{{- $schemaForeignTable := $rel.ForeignTable | $data.SchemaTable }}
		{{- $foreignPKeyCols := (getTable $data.Tables $rel.ForeignTable).PKey.Columns }}
{{if $options.AddGlobal -}}
// Add{{$relAlias.Local}}G adds the given related objects to the existing relationships
// of the {{$table.Name | singular}}, optionally inserting them as new records.
// Appends related to o.R.{{$relAlias.Local}}.
// Sets related.R.{{$relAlias.Foreign}} appropriately.
// Uses the global database handle.
func (o *{{$ltable.UpSingular}}) Add{{$relAlias.Local}}G({{if not $data.NoContext}}ctx context.Context, {{end -}} insert bool, related ...*{{$ftable.UpSingular}}) error {
	return o.Add{{$relAlias.Local}}({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, insert, related...)
}

{{end -}}

{{if $options.AddPanic -}}
// Add{{$relAlias.Local}}P adds the given related objects to the existing relationships
// of the {{$table.Name | singular}}, optionally inserting them as new records.
// Appends related to o.R.{{$relAlias.Local}}.
// Sets related.R.{{$relAlias.Foreign}} appropriately.
// Panics on error.
func (o *{{$ltable.UpSingular}}) Add{{$relAlias.Local}}P({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, insert bool, related ...*{{$ftable.UpSingular}}) {
	if err := o.Add{{$relAlias.Local}}({{if not $data.NoContext}}ctx, {{end -}} exec, insert, related...); err != nil {
		panic(simmer.WrapErr(err))
	}
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// Add{{$relAlias.Local}}GP adds the given related objects to the existing relationships
// of the {{$table.Name | singular}}, optionally inserting them as new records.
// Appends related to o.R.{{$relAlias.Local}}.
// Sets related.R.{{$relAlias.Foreign}} appropriately.
// Uses the global database handle and panics on error.
func (o *{{$ltable.UpSingular}}) Add{{$relAlias.Local}}GP({{if not $data.NoContext}}ctx context.Context, {{end -}} insert bool, related ...*{{$ftable.UpSingular}}) {
	if err := o.Add{{$relAlias.Local}}({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, insert, related...); err != nil {
		panic(simmer.WrapErr(err))
	}
}

{{end -}}

// Add{{$relAlias.Local}} adds the given related objects to the existing relationships
// of the {{$table.Name | singular}}, optionally inserting them as new records.
// Appends related to o.R.{{$relAlias.Local}}.
// Sets related.R.{{$relAlias.Foreign}} appropriately.
func (o *{{$ltable.UpSingular}}) Add{{$relAlias.Local}}({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, insert bool, related ...*{{$ftable.UpSingular}}) error {
	var err error
	for _, rel := range related {
		if insert {
			{{if not .ToJoinTable -}}
				{{if $usesPrimitives -}}
			rel.{{$fcol}} = o.{{$col}}
				{{else -}}
			queries.Assign(&rel.{{$fcol}}, o.{{$col}})
				{{end -}}
			{{end -}}

			if err = rel.Insert({{if not $data.NoContext}}ctx, {{end -}} exec, simmer.Infer()); err != nil {
				return errors.Wrap(err, "failed to insert into foreign table")
			}
		}{{if not .ToJoinTable}} else {
			updateQuery := fmt.Sprintf(
				"UPDATE {{$schemaForeignTable}} SET %s WHERE %s",
				strmangle.SetParamNames("{{$data.LQ}}", "{{$data.RQ}}", {{if $data.Dialect.UseIndexPlaceholders}}1{{else}}0{{end}}, []string{{"{"}}"{{.ForeignColumn}}"{{"}"}}),
				strmangle.WhereClause("{{$data.LQ}}", "{{$data.RQ}}", {{if $data.Dialect.UseIndexPlaceholders}}2{{else}}0{{end}}, {{$ftable.DownSingular}}PrimaryKeyColumns),
			)
			values := []interface{}{o.{{$col}}, rel.{{$foreignPKeyCols | stringMap (aliasCols $ftable) | join ", rel."}}{{"}"}}

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
			rel.{{$fcol}} = o.{{$col}}
			{{else -}}
			queries.Assign(&rel.{{$fcol}}, o.{{$col}})
			{{end -}}
		}{{end -}}
	}

	{{if .ToJoinTable -}}
	for _, rel := range related {
		query := "insert into {{.JoinTable | $data.SchemaTable}} ({{.JoinLocalColumn | $data.Quotes}}, {{.JoinForeignColumn | $.Quotes}}) values {{if $.Dialect.UseIndexPlaceholders}}($1, $2){{else}}(?, ?){{end}}"
		values := []interface{}{{"{"}}o.{{$col}}, rel.{{$fcol}}}

		{{if $data.NoContext -}}
		if simmer.DebugMode {
			fmt.Fprintln(simmer.DebugWriter, query)
			fmt.Fprintln(simmer.DebugWriter, values)
		}
		{{else -}}
		if simmer.IsDebug(ctx) {
		writer := simmer.DebugWriterFrom(ctx)
			fmt.Fprintln(writer, query)
			fmt.Fprintln(writer, values)
		}
		{{end -}}

		{{if $data.NoContext -}}
		_, err = exec.Exec(query, values...)
		{{else -}}
		_, err = exec.ExecContext(ctx, query, values...)
		{{end -}}
		if err != nil {
			return errors.Wrap(err, "failed to insert into join table")
		}
	}
	{{end -}}

	if o.R == nil {
		o.R = &{{$ltable.DownSingular}}R{
			{{$relAlias.Local}}: related,
		}
	} else {
		o.R.{{$relAlias.Local}} = append(o.R.{{$relAlias.Local}}, related...)
	}

	{{if .ToJoinTable -}}
	for _, rel := range related {
		if rel.R == nil {
			rel.R = &{{$ftable.DownSingular}}R{
				{{$relAlias.Foreign}}: {{$ltable.UpSingular}}Slice{{"{"}}o{{"}"}},
			}
		} else {
			rel.R.{{$relAlias.Foreign}} = append(rel.R.{{$relAlias.Foreign}}, o)
		}
	}
	{{else -}}
	for _, rel := range related {
		if rel.R == nil {
			rel.R = &{{$ftable.DownSingular}}R{
				{{$relAlias.Foreign}}: o,
			}
		} else {
			rel.R.{{$relAlias.Foreign}} = o
		}
	}
	{{end -}}

	return nil
}

			{{- if (or .ForeignColumnNullable .ToJoinTable)}}
{{if $options.AddGlobal -}}
// Set{{$relAlias.Local}}G removes all previously related items of the
// {{$table.Name | singular}} replacing them completely with the passed
// in related items, optionally inserting them as new records.
// Sets o.R.{{$relAlias.Foreign}}'s {{$relAlias.Local}} accordingly.
// Replaces o.R.{{$relAlias.Local}} with related.
// Sets related.R.{{$relAlias.Foreign}}'s {{$relAlias.Local}} accordingly.
// Uses the global database handle.
func (o *{{$ltable.UpSingular}}) Set{{$relAlias.Local}}G({{if not $data.NoContext}}ctx context.Context, {{end -}} insert bool, related ...*{{$ftable.UpSingular}}) error {
	return o.Set{{$relAlias.Local}}({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, insert, related...)
}

{{end -}}

{{if $options.AddPanic -}}
// Set{{$relAlias.Local}}P removes all previously related items of the
// {{$table.Name | singular}} replacing them completely with the passed
// in related items, optionally inserting them as new records.
// Sets o.R.{{$relAlias.Foreign}}'s {{$relAlias.Local}} accordingly.
// Replaces o.R.{{$relAlias.Local}} with related.
// Sets related.R.{{$relAlias.Foreign}}'s {{$relAlias.Local}} accordingly.
// Panics on error.
func (o *{{$ltable.UpSingular}}) Set{{$relAlias.Local}}P({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, insert bool, related ...*{{$ftable.UpSingular}}) {
	if err := o.Set{{$relAlias.Local}}({{if not $data.NoContext}}ctx, {{end -}} exec, insert, related...); err != nil {
		panic(simmer.WrapErr(err))
	}
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// Set{{$relAlias.Local}}GP removes all previously related items of the
// {{$table.Name | singular}} replacing them completely with the passed
// in related items, optionally inserting them as new records.
// Sets o.R.{{$relAlias.Foreign}}'s {{$relAlias.Local}} accordingly.
// Replaces o.R.{{$relAlias.Local}} with related.
// Sets related.R.{{$relAlias.Foreign}}'s {{$relAlias.Local}} accordingly.
// Uses the global database handle and panics on error.
func (o *{{$ltable.UpSingular}}) Set{{$relAlias.Local}}GP({{if not $data.NoContext}}ctx context.Context, {{end -}} insert bool, related ...*{{$ftable.UpSingular}}) {
	if err := o.Set{{$relAlias.Local}}({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, insert, related...); err != nil {
		panic(simmer.WrapErr(err))
	}
}

{{end -}}

// Set{{$relAlias.Local}} removes all previously related items of the
// {{$table.Name | singular}} replacing them completely with the passed
// in related items, optionally inserting them as new records.
// Sets o.R.{{$relAlias.Foreign}}'s {{$relAlias.Local}} accordingly.
// Replaces o.R.{{$relAlias.Local}} with related.
// Sets related.R.{{$relAlias.Foreign}}'s {{$relAlias.Local}} accordingly.
func (o *{{$ltable.UpSingular}}) Set{{$relAlias.Local}}({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, insert bool, related ...*{{$ftable.UpSingular}}) error {
	{{if .ToJoinTable -}}
	query := "delete from {{.JoinTable | $data.SchemaTable}} where {{.JoinLocalColumn | $data.Quotes}} = {{if $data.Dialect.UseIndexPlaceholders}}$1{{else}}?{{end}}"
	values := []interface{}{{"{"}}o.{{$col}}}
	{{else -}}
	query := "update {{.ForeignTable | $data.SchemaTable}} set {{.ForeignColumn | $data.Quotes}} = null where {{.ForeignColumn | $data.Quotes}} = {{if $data.Dialect.UseIndexPlaceholders}}$1{{else}}?{{end}}"
	values := []interface{}{{"{"}}o.{{$col}}}
	{{end -}}
	{{if $data.NoContext -}}
	if simmer.DebugMode {
		fmt.Fprintln(simmer.DebugWriter, query)
		fmt.Fprintln(simmer.DebugWriter, values)
	}
	{{else -}}
	if simmer.IsDebug(ctx) {
		writer := simmer.DebugWriterFrom(ctx)
		fmt.Fprintln(writer, query)
		fmt.Fprintln(writer, values)
	}
	{{end -}}

	{{if $data.NoContext -}}
	_, err := exec.Exec(query, values...)
	{{else -}}
	_, err := exec.ExecContext(ctx, query, values...)
	{{end -}}
	if err != nil {
		return errors.Wrap(err, "failed to remove relationships before set")
	}

	{{if .ToJoinTable -}}
	remove{{$relAlias.Local}}From{{$relAlias.Foreign}}Slice(o, related)
	if o.R != nil {
		o.R.{{$relAlias.Local}} = nil
	}
	{{else -}}
	if o.R != nil {
		for _, rel := range o.R.{{$relAlias.Local}} {
			queries.SetScanner(&rel.{{$fcol}}, nil)
			if rel.R == nil {
				continue
			}

			rel.R.{{$relAlias.Foreign}} = nil
		}

		o.R.{{$relAlias.Local}} = nil
	}
	{{end -}}

	return o.Add{{$relAlias.Local}}({{if not $data.NoContext}}ctx, {{end -}} exec, insert, related...)
}

{{if $options.AddGlobal -}}
// Remove{{$relAlias.Local}}G relationships from objects passed in.
// Removes related items from R.{{$relAlias.Local}} (uses pointer comparison, removal does not keep order)
// Sets related.R.{{$relAlias.Foreign}}.
// Uses the global database handle.
func (o *{{$ltable.UpSingular}}) Remove{{$relAlias.Local}}G({{if not $data.NoContext}}ctx context.Context, {{end -}} related ...*{{$ftable.UpSingular}}) error {
	return o.Remove{{$relAlias.Local}}({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, related...)
}

{{end -}}

{{if $options.AddPanic -}}
// Remove{{$relAlias.Local}}P relationships from objects passed in.
// Removes related items from R.{{$relAlias.Local}} (uses pointer comparison, removal does not keep order)
// Sets related.R.{{$relAlias.Foreign}}.
// Panics on error.
func (o *{{$ltable.UpSingular}}) Remove{{$relAlias.Local}}P({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, related ...*{{$ftable.UpSingular}}) {
	if err := o.Remove{{$relAlias.Local}}({{if not $data.NoContext}}ctx, {{end -}} exec, related...); err != nil {
		panic(simmer.WrapErr(err))
	}
}

{{end -}}

{{if and $options.AddGlobal $options.AddPanic -}}
// Remove{{$relAlias.Local}}GP relationships from objects passed in.
// Removes related items from R.{{$relAlias.Local}} (uses pointer comparison, removal does not keep order)
// Sets related.R.{{$relAlias.Foreign}}.
// Uses the global database handle and panics on error.
func (o *{{$ltable.UpSingular}}) Remove{{$relAlias.Local}}GP({{if not $data.NoContext}}ctx context.Context, {{end -}} related ...*{{$ftable.UpSingular}}) {
	if err := o.Remove{{$relAlias.Local}}({{if $data.NoContext}}simmer.GetDB(){{else}}ctx, simmer.GetContextDB(){{end}}, related...); err != nil {
		panic(simmer.WrapErr(err))
	}
}

{{end -}}

// Remove{{$relAlias.Local}} relationships from objects passed in.
// Removes related items from R.{{$relAlias.Local}} (uses pointer comparison, removal does not keep order)
// Sets related.R.{{$relAlias.Foreign}}.
func (o *{{$ltable.UpSingular}}) Remove{{$relAlias.Local}}({{if $data.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}, related ...*{{$ftable.UpSingular}}) error {
	var err error
	{{if .ToJoinTable -}}
	query := fmt.Sprintf(
		"delete from {{.JoinTable | $data.SchemaTable}} where {{.JoinLocalColumn | $data.Quotes}} = {{if $data.Dialect.UseIndexPlaceholders}}$1{{else}}?{{end}} and {{.JoinForeignColumn | $data.Quotes}} in (%s)",
		strmangle.Placeholders(dialect.UseIndexPlaceholders, len(related), 2, 1),
	)
	values := []interface{}{{"{"}}o.{{$col}}}
	for _, rel := range related {
		values = append(values, rel.{{$fcol}})
	}

	{{if $data.NoContext -}}
	if simmer.DebugMode {
		fmt.Fprintln(simmer.DebugWriter, query)
		fmt.Fprintln(simmer.DebugWriter, values)
	}
	{{else -}}
	if simmer.IsDebug(ctx) {
		writer := simmer.DebugWriterFrom(ctx)
		fmt.Fprintln(writer, query)
		fmt.Fprintln(writer, values)
	}
	{{end -}}

	{{if $data.NoContext -}}
	_, err = exec.Exec(query, values...)
	{{else -}}
	_, err = exec.ExecContext(ctx, query, values...)
	{{end -}}
	if err != nil {
		return errors.Wrap(err, "failed to remove relationships before set")
	}
	{{else -}}
	for _, rel := range related {
		queries.SetScanner(&rel.{{$fcol}}, nil)
		{{if not .ToJoinTable -}}
		if rel.R != nil {
			rel.R.{{$relAlias.Foreign}} = nil
		}
		{{end -}}
		if {{if not $data.NoRowsAffected}}_, {{end -}} err = rel.Update({{if not $data.NoContext}}ctx, {{end -}} exec, simmer.Whitelist("{{.ForeignColumn}}")); err != nil {
			return err
		}
	}
	{{end -}}

	{{if .ToJoinTable -}}
	remove{{$relAlias.Local}}From{{$relAlias.Foreign}}Slice(o, related)
	{{end -}}
	if o.R == nil {
		return nil
	}

	for _, rel := range related {
		for i, ri := range o.R.{{$relAlias.Local}} {
			if rel != ri {
				continue
			}

			ln := len(o.R.{{$relAlias.Local}})
			if ln > 1 && i < ln-1 {
				o.R.{{$relAlias.Local}}[i] = o.R.{{$relAlias.Local}}[ln-1]
			}
			o.R.{{$relAlias.Local}} = o.R.{{$relAlias.Local}}[:ln-1]
			break
		}
	}

	return nil
}

				{{if .ToJoinTable -}}
func remove{{$relAlias.Local}}From{{$relAlias.Foreign}}Slice(o *{{$ltable.UpSingular}}, related []*{{$ftable.UpSingular}}) {
	for _, rel := range related {
		if rel.R == nil {
			continue
		}
		for i, ri := range rel.R.{{$relAlias.Foreign}} {
			{{if $usesPrimitives -}}
			if o.{{$col}} != ri.{{$col}} {
			{{else -}}
			if !queries.Equal(o.{{$col}}, ri.{{$col}}) {
			{{end -}}
				continue
			}

			ln := len(rel.R.{{$relAlias.Foreign}})
			if ln > 1 && i < ln-1 {
				rel.R.{{$relAlias.Foreign}}[i] = rel.R.{{$relAlias.Foreign}}[ln-1]
			}
			rel.R.{{$relAlias.Foreign}} = rel.R.{{$relAlias.Foreign}}[:ln-1]
			break
		}
	}
}
				{{end -}}{{- /* if ToJoinTable */ -}}
			{{- end -}}{{- /* if nullable foreign key */ -}}
	{{- end -}}{{- /* range relationships */ -}}
{{- end -}}{{- /* if IsJoinTable */ -}}
