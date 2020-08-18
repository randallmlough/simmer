{{- addImport "fmt" -}}
{{- addImport "io" -}}
{{- addImport "strconv" -}}

{{- $schema := .Schema -}}
{{- if $schema.Scalars.Scalar "Password"}}
const protectedString string = "____REDACTED____"

// ensures that password won't be logged or marshalled
type Password string

func (p *Password) UnmarshalGQL(v interface{}) error {
	str, ok := v.(string)
	if !ok {
		return fmt.Errorf("password must be string")
	}

	*p = Password(str)
	return nil
}

func (p Password) MarshalGQL(w io.Writer) {
	fmt.Fprint(w, strconv.Quote(p.String()))
}

func (p Password) MarshalJSON() ([]byte, error) {
	return []byte(`"` + protectedString + `"`), nil
}

func (p Password) String() string {
	return protectedString
}

func (p Password) UnRedacted() string {
	return string(p)
}
{{ end -}}

