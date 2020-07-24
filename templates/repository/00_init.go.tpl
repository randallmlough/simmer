{{- $model := .Model.Name | singular -}}
{{- $modelUppercase := $model | titleCase }}

func New{{$modelUppercase}}(db executor) *{{$modelUppercase}} {
	return &{{$modelUppercase}}{
		{{$model}}Validation{},
		db,
	}
}

type {{$modelUppercase}} struct {
	val {{$model}}Validation
	executor
}
