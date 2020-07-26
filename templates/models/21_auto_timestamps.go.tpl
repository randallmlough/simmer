{{- define "timestamp_insert_helper" -}}
	{{- $data := .Data -}}
	{{- $model := .Model -}}
	{{- $options := .Options -}}
	{{- if not $options.NoAutoTimestamps -}}
	{{- $colNames := $model.Table.Columns | columnNames -}}
	{{if containsAny $colNames "created_at" "updated_at"}}
		{{if not $options.NoContext -}}
	if !simmer.TimestampsAreSkipped(ctx) {
		{{end -}}
		currTime := time.Now().In(simmer.GetLocation())
		{{range $ind, $col := $model.Table.Columns}}
			{{- if eq $col.Name "created_at" -}}
				{{- if eq $col.Type "time.Time" }}
		if o.CreatedAt.IsZero() {
			o.CreatedAt = currTime
		}
				{{- else}}
		if queries.MustTime(o.CreatedAt).IsZero() {
			queries.SetScanner(&o.CreatedAt, currTime)
		}
				{{- end -}}
			{{- end -}}
			{{- if eq $col.Name "updated_at" -}}
				{{- if eq $col.Type "time.Time"}}
		if o.UpdatedAt.IsZero() {
			o.UpdatedAt = currTime
		}
				{{- else}}
		if queries.MustTime(o.UpdatedAt).IsZero() {
			queries.SetScanner(&o.UpdatedAt, currTime)
		}
				{{- end -}}
			{{- end -}}
		{{end}}
		{{if not $options.NoContext -}}
	}
		{{end -}}
	{{end}}
	{{- end}}
{{- end -}}
{{- define "timestamp_update_helper" -}}
	{{- $data := .Data -}}
	{{- $model := .Model -}}
	{{- $options := .Options -}}
	{{- if not $options.NoAutoTimestamps -}}
	{{- $colNames := $model.Table.Columns | columnNames -}}
	{{if containsAny $colNames "updated_at"}}
		{{if not $options.NoContext -}}
	if !simmer.TimestampsAreSkipped(ctx) {
		{{end -}}
		currTime := time.Now().In(simmer.GetLocation())
		{{range $ind, $col := $model.Table.Columns}}
			{{- if eq $col.Name "updated_at" -}}
				{{- if eq $col.Type "time.Time"}}
		o.UpdatedAt = currTime
				{{- else}}
		queries.SetScanner(&o.UpdatedAt, currTime)
				{{- end -}}
			{{- end -}}
		{{end}}
		{{if not $options.NoContext -}}
	}
		{{end -}}
	{{end}}
	{{- end}}
{{end -}}
{{- define "timestamp_upsert_helper" -}}
	{{- $data := .Data -}}
	{{- $model := .Model -}}
	{{- $options := .Options -}}
	{{- if not $options.NoAutoTimestamps -}}
	{{- $colNames := $model.Table.Columns | columnNames -}}
	{{if containsAny $colNames "created_at" "updated_at"}}
		{{if not $options.NoContext -}}
	if !simmer.TimestampsAreSkipped(ctx) {
		{{end -}}
	currTime := time.Now().In(simmer.GetLocation())
		{{range $ind, $col := $model.Table.Columns}}
			{{- if eq $col.Name "created_at" -}}
				{{- if eq $col.Type "time.Time"}}
	if o.CreatedAt.IsZero() {
		o.CreatedAt = currTime
	}
				{{- else}}
	if queries.MustTime(o.CreatedAt).IsZero() {
		queries.SetScanner(&o.CreatedAt, currTime)
	}
				{{- end -}}
			{{- end -}}
			{{- if eq $col.Name "updated_at" -}}
				{{- if eq $col.Type "time.Time"}}
	o.UpdatedAt = currTime
				{{- else}}
	queries.SetScanner(&o.UpdatedAt, currTime)
				{{- end -}}
			{{- end -}}
		{{end}}
		{{if not $options.NoContext -}}
	}
		{{end -}}
	{{end}}
	{{- end}}
{{end -}}
