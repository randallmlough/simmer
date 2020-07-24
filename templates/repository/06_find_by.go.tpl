{{- $model := .Model.Name | singular -}}
{{- $modelUppercase := $model | titleCase }}
{{- $canSoftDelete := .Model.Table.CanSoftDelete }}

{{- range .Model.Table.Constraints.AllIndexed}}
{{ $columnUppercase := .ColumnName | titleCase}}
{{ $arg := .ColumnName | camelCase}}
// FindBy{{$columnUppercase}} will find a {{$model}} record with the given {{$arg}}
func (db *{{$modelUppercase}}) FindBy{{$columnUppercase}}(ctx context.Context, {{$arg}} {{.Type}}, opts ...Option) (*models.{{$modelUppercase}}, error) {
    o := initOptions(opts...)
    {{$model}}, err := db.Select{{$modelUppercase}}(ctx,
        Select(o.Columns.Cols...),
        Where(`{{.ColumnName}} = ?{{if and $.Data.AddSoftDeletes $canSoftDelete}} and "deleted_at" is null{{end}}`, {{$arg}}),
    )
    if err != nil {
    	if errors.Cause(err) == sql.ErrNoRows {
			return nil, ErrNoData
		}
        return nil, errors.Wrap(err, "{{$arg}}: unable to select from {{$.Model.Table.Name}}")
    }
    return {{$model}}, nil
}
{{- end }}