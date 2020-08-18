{{ if .Model.HasModel }}
{{- $model := .Model.Name | singular -}}
{{- $modelUppercase := $model | titleCase }}

// Insert{{$modelUppercase}} will insert a new {{$model}} record into the database.
func (db *{{$modelUppercase}}) Insert{{$modelUppercase}}(ctx context.Context, m *models.{{$modelUppercase}}, opts ...Option) error {
	if err := db.val.insert(m); err != nil {
		return errors.Wrap(err, "{{$model}} validation failed")
	}

	o := initOptions(opts...)
	if err := m.Insert(ctx, db.getExecutor(ctx), o.Columns); err != nil {
		return errors.Wrap(err, "failed to insert {{$model}}")
	}
	return nil
}
{{end}}