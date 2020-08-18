{{ if .Model.HasModel }}
{{- $model := .Model.Name | singular -}}
{{- $modelUppercase := $model | titleCase }}
{{- $canSoftDelete := .Model.Table.CanSoftDelete }}
{{- $valType := printf "%sValidation" $model }}
{{- $pk := .Model.Table.Constraints.PrimaryKey}}
type {{$valType}} struct {}

type {{$valType}}Func func(m *models.{{$modelUppercase}}) error

func (val {{$valType}}) validate(m *models.{{$modelUppercase}}, fns ...{{$valType}}Func) error {
	for _, fn := range fns {
		if err := fn(m); err != nil {
			return err
		}
	}
	return nil
}

func (val {{$valType}}) insert(m *models.{{$modelUppercase}}) error {
    if err := val.validate(m,
        {{- range .Model.Table.Columns.NonNulls}}
            {{- if eq .Name $pk.Name}}
                {{- if not $pk.Sequenced }}
                val.{{.Name | camelCase }}Required(),
                {{- end }}
            {{- else }}
            val.{{.Name | camelCase }}Required(),
            {{- end }}
        {{- end }}
    ); err != nil {
        return err
    }
    return nil
}

func (val {{$valType}}) update(m *models.{{$modelUppercase}}) error {
    if err := val.validate(m,
        val.{{$pk.Name}}Required(),
    ); err != nil {
        return err
    }
    return nil
}

func (val {{$valType}}) delete(m *models.{{$modelUppercase}}) error {
    if err := val.validate(m,
    	val.{{$pk.Name}}Required(),
    ); err != nil {
        return err
    }
    return nil
}

{{- range .Model.Table.Columns.NonNulls}}
{{ $columnUppercase := .Name | titleCase}}
var Err{{$modelUppercase}}{{$columnUppercase}}Required = errors.New("{{$columnUppercase}} is a required field")

func (val {{$valType}}) {{.Name | camelCase}}Required() {{$valType}}Func {
    return func(m *models.{{$modelUppercase}}) error {
        {{- if eq .Type "string"}}
            if m.{{$columnUppercase}} == "" {
                return Err{{$modelUppercase}}{{$columnUppercase}}Required
            }
        {{ else if eq .Type "int"}}
            if m.{{$columnUppercase}} <= 0 {
                return Err{{$modelUppercase}}{{$columnUppercase}}Required
            }
        {{ end -}}
        return nil
    }
}
{{- end }}
{{end}}