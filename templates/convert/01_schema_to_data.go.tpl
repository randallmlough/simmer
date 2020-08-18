{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- $dataReplacement := $options.Package "data" -}}
{{- $schemaReplacement := $options.Package "schema" -}}
{{- $table := $model.Table -}}

{{ if $model.HasObject }}

{{ $object := $model.Object }}
{{ $alias := $data.Aliases.Table $table.Name }}
func {{ $object.Name |go }}ObjectToModel(o *{{$schemaReplacement}}.{{ $object.Name |go }})( *{{$dataReplacement}}.{{$alias.UpSingular}}) {
	if o == nil {
		return nil
	}

	r := &{{$dataReplacement}}.{{ $alias.UpSingular }}{
		{{- range $field := $object.Fields }}
			{{ $field.TableField.Name|go }}: {{ $field.ToTableField "o"}},
		{{- end -}}
	}

	return r
}

func {{ $object.Name |go }}sObjectToModel(oo []*{{$schemaReplacement}}.{{ $object.Name |go }})( []*{{$dataReplacement}}.{{$alias.UpSingular}}) {
	if oo == nil {
		return nil
	}

	models := make([]*{{$dataReplacement}}.{{$alias.UpSingular}}, 0, len(oo))
	for _, object := range oo {
		models = append(models, {{ $object.Name |go }}ObjectToModel(object))
	}

	return models
}
{{ end }}