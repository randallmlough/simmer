{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- $dataReplacement := $options.Package "data" -}}
{{- $schemaReplacement := $options.Package "schema" -}}
{{- $table := $model.Table -}}

{{ if $model.HasObject }}
{{/*
	import required data and schema packages
*/}}
{{ addImport $dataReplacement.Import}}
{{ addImport $schemaReplacement.Import}}

{{ $object := $model.Object }}
{{ $alias := $data.Aliases.Table $table.Name }}
func {{$alias.UpSingular |go }}ModelToObject(m *{{$dataReplacement}}.{{ $alias.UpSingular }})( *{{$schemaReplacement}}.{{ $object.Name |go }}) {
	if m == nil {
		return nil
	}

	r := &{{$schemaReplacement}}.{{ $object.Name |go }}{
		{{- range $field := $object.Fields }}
			{{ $field.SchemaField.Name|go }}: {{ $field.ToObjectField "m"}},
		{{- end -}}
	}

	return r
}

func {{$alias.UpPlural |go }}ModelToObject(mm []*{{$dataReplacement}}.{{ $alias.UpSingular }})( []*{{$schemaReplacement}}.{{ $object.Name |go }}) {
	if mm == nil {
		return nil
	}

	objects := make([]*{{$schemaReplacement}}.{{ $object.Name |go }}, 0, len(mm))
	for _, model := range mm {
		objects = append(objects, {{$alias.UpSingular |go }}ModelToObject(model))
	}

	return objects
}
{{ end }}