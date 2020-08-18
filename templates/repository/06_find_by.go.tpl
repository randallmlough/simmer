{{ if .Model.HasModel }}
{{- $model := .Model -}}
{{- $data := .Data -}}
{{- $modelName := $model.Name | singular -}}
{{- $modelNameUppercase := $modelName | titleCase }}
{{- $canSoftDelete := $model.Table.CanSoftDelete }}

{{- range $model.Table.Constraints.AllIndexed}}
{{ $columnUppercase := .ColumnName | titleCase}}
{{ $arg := .ColumnName | camelCase}}
// FindBy{{$columnUppercase}} will find a {{$modelName}} record with the given {{$arg}}
func (db *{{$modelNameUppercase}}) FindBy{{$columnUppercase}}(ctx context.Context, {{$arg}} {{.Type}}, opts ...Option) (*models.{{$modelNameUppercase}}, error) {
    o := initOptions(opts...)
    {{$modelName}}, err := db.Select{{$modelNameUppercase}}(ctx,
        Select(o.Columns.Cols...),
        Where(`{{.ColumnName}} = ?{{if and $data.AddSoftDeletes $canSoftDelete}} and "deleted_at" is null{{end}}`, {{$arg}}),
    )
    if err != nil {
    	if errors.Cause(err) == sql.ErrNoRows {
			return nil, ErrNoData
		}
        return nil, errors.Wrap(err, "{{$arg}}: unable to select from {{$.Model.Table.Name}}")
    }
    return {{$modelName}}, nil
}
{{- end }}
{{end}}