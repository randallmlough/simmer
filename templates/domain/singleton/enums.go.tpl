{{- $schema := .Schema -}}
{{ range $enum := $schema.Enums }}
	{{- addImport "fmt"}}
	{{- addImport "strconv"}}
	{{- addImport "io"}}
	{{ with .Description }} {{.|prefixLines "// "}} {{end}}
	type {{.Name|go }} string
	const (
	{{- range $value := .Values}}
		{{- with .Description}}
			{{.|prefixLines "// "}}
		{{- end}}
		{{ $enum.Name|go }}{{ .Name|go }} {{$enum.Name|go }} = {{.Name|quoteWrap}}
	{{- end }}
	)

	var All{{.Name|go }} = []{{ .Name|go }}{
	{{- range $value := .Values}}
		{{$enum.Name|go }}{{ .Name|go }},
	{{- end }}
	}

	func (e {{.Name|go }}) IsValid() bool {
		switch e {
		case {{ range $index, $element := .Values}}{{if $index}},{{end}}{{ $enum.Name|go }}{{ $element.Name|go }}{{end}}:
			return true
		}
		return false
	}

	func (e {{.Name|go }}) String() string {
		return string(e)
	}

	func (e *{{.Name|go }}) UnmarshalGQL(v interface{}) error {
		str, ok := v.(string)
		if !ok {
			return fmt.Errorf("enums must be strings")
		}

		*e = {{ .Name|go }}(str)
		if !e.IsValid() {
			return fmt.Errorf("%s is not a valid {{ .Name }}", str)
		}
		return nil
	}

	func (e {{.Name|go }}) MarshalGQL(w io.Writer) {
		fmt.Fprint(w, strconv.Quote(e.String()))
	}

{{- end }}