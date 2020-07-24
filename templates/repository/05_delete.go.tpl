{{- $model := .Model.Name | singular -}}
{{- $modelUppercase := $model | titleCase }}
{{- $canSoftDelete := .Model.Table.CanSoftDelete }}

// Delete{{$modelUppercase}} will delete a {{$model}} model at the given ID.
// If an ID isn't present an error will be returned.
func (db *{{$modelUppercase}}) Delete{{$modelUppercase}}(ctx context.Context, m *models.{{$modelUppercase}}, opts ...Option) error {
	if err := db.val.delete(m); err != nil {
		return errors.Wrap(err, "{{$model}} validation failed")
	}

	{{- if and $.Data.AddSoftDeletes $canSoftDelete}}
	o := initOptions(opts...)
	{{- end}}
	if _, err := m.Delete(ctx, db.getExecutor(ctx){{if and $.Data.AddSoftDeletes $canSoftDelete}}, o.HardDelete{{end}}); err != nil {
		return errors.Wrapf(err, "failed to delete {{$model}} with id: %v", m.ID)
	}
	return nil
}

