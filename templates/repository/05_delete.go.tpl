{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- $modelName := $model.Name | singular -}}
{{- $modelNameUppercase := $modelName | titleCase }}
{{- $canSoftDelete := $model.Table.CanSoftDelete }}

// Delete{{$modelNameUppercase}} will delete a {{$modelName}} model at the given ID.
// If an ID isn't present an error will be returned.
func (db *{{$modelNameUppercase}}) Delete{{$modelNameUppercase}}(ctx context.Context, m *models.{{$modelNameUppercase}}, opts ...Option) error {
	if err := db.val.delete(m); err != nil {
		return errors.Wrap(err, "{{$modelName}} validation failed")
	}

	{{- if and $.Data.AddSoftDeletes $canSoftDelete}}
	o := initOptions(opts...)
	{{- end}}
	if _, err := m.Delete(ctx, db.getExecutor(ctx){{if and $options.AddSoftDeletes $canSoftDelete}}, o.HardDelete{{end}}); err != nil {
		return errors.Wrapf(err, "failed to delete {{$modelName}} with id: %v", m.ID)
	}
	return nil
}

