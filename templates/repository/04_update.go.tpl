{{ if .Model.HasModel }}
{{- $model := .Model.Name | singular -}}
{{- $modelUppercase := $model | titleCase }}

// Update{{$modelUppercase}} will update a {{$model}} model at the given ID.
// If an ID isn't present an error will be returned
func (db *{{$modelUppercase}}) Update{{$modelUppercase}}(ctx context.Context, m *models.{{$modelUppercase}}, opts ...Option) error {
	if err := db.val.update(m); err != nil {
		return errors.Wrap(err, "{{$model}} validation failed")
	}

	o := initOptions(opts...)
	if _, err := m.Update(ctx, db.getExecutor(ctx), o.Columns); err != nil {
		return errors.Wrapf(err, "failed to update {{$model}} with id: %v", m.ID)
	}
	return nil
}
{{end}}