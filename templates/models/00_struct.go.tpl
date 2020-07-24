{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- $alias := $data.Aliases.Table $model.Table.Name -}}
{{- $orig_tbl_name := $model.Table.Name -}}

// {{$alias.UpSingular}} is an object representing the database table.
type {{$alias.UpSingular}} struct {
	{{- range $column := $model.Table.Columns -}}
	{{- $colAlias := $alias.Column $column.Name -}}
	{{- $orig_col_name := $column.Name -}}
	{{if ignore $orig_tbl_name $orig_col_name $options.TagIgnore -}}
	{{$colAlias}} {{$column.Type}} `{{generateIgnoreTags $options.Tags}}simmer:"{{$column.Name}}" json:"-" toml:"-" yaml:"-"`
	{{else if eq $options.StructTagCasing "title" -}}
	{{$colAlias}} {{$column.Type}} `{{generateTags $options.Tags $column.Name}}simmer:"{{$column.Name}}" json:"{{$column.Name | titleCase}}{{if $column.Nullable}},omitempty{{end}}" toml:"{{$column.Name | titleCase}}" yaml:"{{$column.Name | titleCase}}{{if $column.Nullable}},omitempty{{end}}"`
	{{else if eq $options.StructTagCasing "camel" -}}
	{{$colAlias}} {{$column.Type}} `{{generateTags $options.Tags $column.Name}}simmer:"{{$column.Name}}" json:"{{$column.Name | camelCase}}{{if $column.Nullable}},omitempty{{end}}" toml:"{{$column.Name | camelCase}}" yaml:"{{$column.Name | camelCase}}{{if $column.Nullable}},omitempty{{end}}"`
	{{else if eq $options.StructTagCasing "alias" -}}
	{{$colAlias}} {{$column.Type}} `{{generateTags $options.Tags $colAlias}}simmer:"{{$column.Name}}" json:"{{$colAlias}}{{if $column.Nullable}},omitempty{{end}}" toml:"{{$colAlias}}" yaml:"{{$colAlias}}{{if $column.Nullable}},omitempty{{end}}"`
	{{else -}}
	{{$colAlias}} {{$column.Type}} `{{generateTags $options.Tags $column.Name}}simmer:"{{$column.Name}}" json:"{{$column.Name}}{{if $column.Nullable}},omitempty{{end}}" toml:"{{$column.Name}}" yaml:"{{$column.Name}}{{if $column.Nullable}},omitempty{{end}}"`
	{{end -}}
	{{end -}}
	{{- if $model.Table.IsJoinTable -}}
	{{- else}}
	R *{{$alias.DownSingular}}R `{{generateTags $options.Tags $options.RelationTag}}simmer:"{{$options.RelationTag}}" json:"{{$options.RelationTag}}" toml:"{{$options.RelationTag}}" yaml:"{{$options.RelationTag}}"`
	L {{$alias.DownSingular}}L `{{generateIgnoreTags $options.Tags}}simmer:"-" json:"-" toml:"-" yaml:"-"`
	{{end -}}
}

var {{$alias.UpSingular}}Columns = struct {
	{{range $column := $model.Table.Columns -}}
	{{- $colAlias := $alias.Column $column.Name -}}
	{{$colAlias}} string
	{{end -}}
}{
	{{range $column := $model.Table.Columns -}}
	{{- $colAlias := $alias.Column $column.Name -}}
	{{$colAlias}}: "{{$column.Name}}",
	{{end -}}
}

{{/* Generated where helpers for all types in the database */}}
// Generated where
{{- range $model.Table.Columns -}}
	{{- if (oncePut $options.DBTypes .Type)}}
	{{$name := printf "whereHelper%s" (goVarname .Type)}}
type {{$name}} struct { field string }
func (w {{$name}}) EQ(x {{.Type}}) queries.QueryMod { return queries.Where{{if .Nullable}}NullEQ(w.field, false, x){{else}}(w.field, queries.EQ, x){{end}} }
func (w {{$name}}) NEQ(x {{.Type}}) queries.QueryMod { return queries.Where{{if .Nullable}}NullEQ(w.field, true, x){{else}}(w.field, queries.NEQ, x){{end}} }
{{if .Nullable -}}
func (w {{$name}}) IsNull() queries.QueryMod { return queries.WhereIsNull(w.field) }
func (w {{$name}}) IsNotNull() queries.QueryMod { return queries.WhereIsNotNull(w.field) }
{{end -}}
func (w {{$name}}) LT(x {{.Type}}) queries.QueryMod { return queries.WhereOp(w.field, queries.LT, x) }
func (w {{$name}}) LTE(x {{.Type}}) queries.QueryMod { return queries.WhereOp(w.field, queries.LTE, x) }
func (w {{$name}}) GT(x {{.Type}}) queries.QueryMod { return queries.WhereOp(w.field, queries.GT, x) }
func (w {{$name}}) GTE(x {{.Type}}) queries.QueryMod { return queries.WhereOp(w.field, queries.GTE, x) }
{{if isPrimitive .Type -}}
func (w {{$name}}) IN(slice []{{.Type}}) queries.QueryMod {
  values := make([]interface{}, 0, len(slice))
  for _, value := range slice {
    values = append(values, value)
  }
  return queries.WhereIn(fmt.Sprintf("%s IN ?", w.field), values...)
}
func (w {{$name}}) NIN(slice []{{.Type}}) queries.QueryMod {
	values := make([]interface{}, 0, len(slice))
	for _, value := range slice {
	  values = append(values, value)
	}
	return queries.WhereNotIn(fmt.Sprintf("%s NOT IN ?", w.field), values...)
  }
{{end -}}
	{{- end -}}
{{- end}}

var {{$alias.UpSingular}}Where = struct {
	{{range $column := $model.Table.Columns -}}
	{{- $colAlias := $alias.Column $column.Name -}}
	{{$colAlias}} whereHelper{{goVarname $column.Type}}
	{{end -}}
}{
	{{range $column := $model.Table.Columns -}}
	{{- $colAlias := $alias.Column $column.Name -}}
	{{$colAlias}}: whereHelper{{goVarname $column.Type}}{field: "{{$model.Table.Name | $data.SchemaTable}}.{{$column.Name | $data.Quotes}}"},
	{{end -}}
}

{{- if $model.Table.IsJoinTable -}}
{{- else}}
// {{$alias.UpSingular}}Rels is where relationship names are stored.
var {{$alias.UpSingular}}Rels = struct {
	{{range $model.Table.FKeys -}}
	{{- $relAlias := $alias.Relationship .Name -}}
	{{$relAlias.Foreign}} string
	{{end -}}

	{{range $model.Table.ToOneRelationships -}}
	{{- $ftable := $data.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $ftable.Relationship .Name -}}
	{{$relAlias.Local}} string
	{{end -}}

	{{range $model.Table.ToManyRelationships -}}
	{{- $relAlias := $data.Aliases.ManyRelationship .ForeignTable .Name .JoinTable .JoinLocalFKeyName -}}
	{{$relAlias.Local}} string
	{{end -}}{{/* range tomany */}}
}{
	{{range $model.Table.FKeys -}}
	{{- $relAlias := $alias.Relationship .Name -}}
	{{$relAlias.Foreign}}: "{{$relAlias.Foreign}}",
	{{end -}}

	{{range $model.Table.ToOneRelationships -}}
	{{- $ftable := $data.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $ftable.Relationship .Name -}}
	{{$relAlias.Local}}: "{{$relAlias.Local}}",
	{{end -}}

	{{range $model.Table.ToManyRelationships -}}
	{{- $relAlias := $data.Aliases.ManyRelationship .ForeignTable .Name .JoinTable .JoinLocalFKeyName -}}
	{{$relAlias.Local}}: "{{$relAlias.Local}}",
	{{end -}}{{/* range tomany */}}
}

// {{$alias.DownSingular}}R is where relationships are stored.
type {{$alias.DownSingular}}R struct {
	{{range $model.Table.FKeys -}}
	{{- $ftable := $data.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $alias.Relationship .Name -}}
	{{$relAlias.Foreign}} *{{$ftable.UpSingular}} `{{generateTags $options.Tags $relAlias.Foreign}}simmer:"{{$relAlias.Foreign}}" json:"{{$relAlias.Foreign}}" toml:"{{$relAlias.Foreign}}" yaml:"{{$relAlias.Foreign}}"`
	{{end -}}

	{{range $model.Table.ToOneRelationships -}}
	{{- $ftable := $data.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $ftable.Relationship .Name -}}
	{{$relAlias.Local}} *{{$ftable.UpSingular}} `{{generateTags $options.Tags $relAlias.Local}}simmer:"{{$relAlias.Local}}" json:"{{$relAlias.Local}}" toml:"{{$relAlias.Local}}" yaml:"{{$relAlias.Local}}"`
	{{end -}}

	{{range $model.Table.ToManyRelationships -}}
	{{- $ftable := $data.Aliases.Table .ForeignTable -}}
	{{- $relAlias := $data.Aliases.ManyRelationship .ForeignTable .Name .JoinTable .JoinLocalFKeyName -}}
	{{$relAlias.Local}} {{printf "%sSlice" $ftable.UpSingular}} `{{generateTags $options.Tags $relAlias.Local}}simmer:"{{$relAlias.Local}}" json:"{{$relAlias.Local}}" toml:"{{$relAlias.Local}}" yaml:"{{$relAlias.Local}}"`
	{{end -}}{{/* range tomany */}}
}

// NewStruct creates a new relationship struct
func (*{{$alias.DownSingular}}R) NewStruct() *{{$alias.DownSingular}}R {
	return &{{$alias.DownSingular}}R{}
}

// {{$alias.DownSingular}}L is where Load methods for each relationship are stored.
type {{$alias.DownSingular}}L struct{}
{{end -}}
