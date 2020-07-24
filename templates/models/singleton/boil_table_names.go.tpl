{{ $data := .Data }}
var TableNames = struct {
	{{range $table := $data.Tables -}}
	{{titleCase $table.Name}} string
	{{end -}}
}{
	{{range $table := $data.Tables -}}
	{{titleCase $table.Name}}: "{{$table.Name}}",
	{{end -}}
}
