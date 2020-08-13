{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $table := $model.Table -}}

{{ if $model.HasObject }}
{{ $object := $model.Object }}
{{ $alias := $data.Aliases.Table $table.Name }}
func {{$alias.UpSingular |go }}ModelToObject(m *models.{{ $alias.UpSingular }})( *app.{{ $object.Name |go }}) {
	if m == nil {
		return nil
	}

	r := &app.{{ $object.Name |go }}{
		{{- range $field := $object.Fields }}
			{{ if isBuiltin $field.TableField.Type -}}
				{{- if $field.SchemaField.IsRequired -}}
				{{ $field.SchemaField.Name|go }}: m.{{ $field.TableField.Name|go }},
				{{- else -}}
				{{ $field.SchemaField.Name|go }}: &m.{{ $field.TableField.Name|go }},
				{{- end -}}
			{{- else -}}
			{{ $field.SchemaField.Name|go }}: {{ $field.ToObjectField }}(m.{{ $field.TableField.Name|go }}),
			{{- end -}}
		{{- end }}
	}

	return r
}

func {{$alias.UpPlural |go }}ModelToObject(mm []*models.{{ $alias.UpSingular }})( []*app.{{ $object.Name |go }}) {
	if mm == nil {
		return nil
	}

	objects := make([]*app.{{ $object.Name |go }}, 0, len(mm))
	for _, model := range mm {
		objects = append(objects, {{$alias.UpSingular |go }}ModelToObject(model))
	}

	return objects
}
{{ end }}