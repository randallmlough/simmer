{{- $models := .Model.Name -}}
{{- $modelsUppercase := $models | plural | titleCase }}
{{- $model := $models | singular -}}
{{- $modelUppercase := $model | titleCase }}

// Select{{$modelUppercase}} will attempt to find an {{$model}} based on the given query.
func (db *{{$modelUppercase}}) Select{{$modelUppercase}}(ctx context.Context, q ...Query) (*models.{{$modelUppercase}}, error) {
	result, err := models.{{$modelsUppercase}}(q...).One(ctx, db.getExecutor(ctx))
	if err != nil {
		if errors.Cause(err) == sql.ErrNoRows {
			return nil, ErrNoData
		}
		return nil, errors.Wrap(err, "failed to select {{$model}}")
	}
	return result, nil
}

// Select{{$modelsUppercase}} will attempt to find {{$models}} based on the given query.
func (db *{{$modelUppercase}}) Select{{$modelsUppercase}}(ctx context.Context, q ...Query) ([]*models.{{$modelUppercase}}, error) {
	results, err := models.{{$modelsUppercase}}(q...).All(ctx, db.getExecutor(ctx))
	if err != nil {
		if errors.Cause(err) == sql.ErrNoRows {
			return nil, ErrNoData
		}
		return nil, errors.Wrap(err, "failed to select {{$models}}")
	}
	return results, nil
}