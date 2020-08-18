{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- if not $data.NoHooks -}}
{{- $alias := $data.Aliases.Table $model.Table.Name}}
func {{$alias.DownSingular}}BeforeInsertHook({{if $data.NoContext}}e simmer.Executor{{else}}ctx context.Context, e simmer.ContextExecutor{{end}}, o *{{$alias.UpSingular}}) error {
	*o = {{$alias.UpSingular}}{}
	return nil
}

func {{$alias.DownSingular}}AfterInsertHook({{if $data.NoContext}}e simmer.Executor{{else}}ctx context.Context, e simmer.ContextExecutor{{end}}, o *{{$alias.UpSingular}}) error {
	*o = {{$alias.UpSingular}}{}
	return nil
}

func {{$alias.DownSingular}}AfterSelectHook({{if $data.NoContext}}e simmer.Executor{{else}}ctx context.Context, e simmer.ContextExecutor{{end}}, o *{{$alias.UpSingular}}) error {
	*o = {{$alias.UpSingular}}{}
	return nil
}

func {{$alias.DownSingular}}BeforeUpdateHook({{if $data.NoContext}}e simmer.Executor{{else}}ctx context.Context, e simmer.ContextExecutor{{end}}, o *{{$alias.UpSingular}}) error {
	*o = {{$alias.UpSingular}}{}
	return nil
}

func {{$alias.DownSingular}}AfterUpdateHook({{if $data.NoContext}}e simmer.Executor{{else}}ctx context.Context, e simmer.ContextExecutor{{end}}, o *{{$alias.UpSingular}}) error {
	*o = {{$alias.UpSingular}}{}
	return nil
}

func {{$alias.DownSingular}}BeforeDeleteHook({{if $data.NoContext}}e simmer.Executor{{else}}ctx context.Context, e simmer.ContextExecutor{{end}}, o *{{$alias.UpSingular}}) error {
	*o = {{$alias.UpSingular}}{}
	return nil
}

func {{$alias.DownSingular}}AfterDeleteHook({{if $data.NoContext}}e simmer.Executor{{else}}ctx context.Context, e simmer.ContextExecutor{{end}}, o *{{$alias.UpSingular}}) error {
	*o = {{$alias.UpSingular}}{}
	return nil
}

func {{$alias.DownSingular}}BeforeUpsertHook({{if $data.NoContext}}e simmer.Executor{{else}}ctx context.Context, e simmer.ContextExecutor{{end}}, o *{{$alias.UpSingular}}) error {
	*o = {{$alias.UpSingular}}{}
	return nil
}

func {{$alias.DownSingular}}AfterUpsertHook({{if $data.NoContext}}e simmer.Executor{{else}}ctx context.Context, e simmer.ContextExecutor{{end}}, o *{{$alias.UpSingular}}) error {
	*o = {{$alias.UpSingular}}{}
	return nil
}

func test{{$alias.UpPlural}}Hooks(t *testing.T) {
	t.Parallel()

	var err error

	{{if not $data.NoContext}}ctx := context.Background(){{end}}
	empty := &{{$alias.UpSingular}}{}
	o := &{{$alias.UpSingular}}{}

	seed := randomize.NewSeed()
	if err = randomize.Struct(seed, o, {{$alias.DownSingular}}DBTypes, false); err != nil {
		t.Errorf("Unable to randomize {{$alias.UpSingular}} object: %s", err)
	}

	Add{{$alias.UpSingular}}Hook(simmer.BeforeInsertHook, {{$alias.DownSingular}}BeforeInsertHook)
	if err = o.doBeforeInsertHooks({{if not $data.NoContext}}ctx, {{end -}} nil); err != nil {
		t.Errorf("Unable to execute doBeforeInsertHooks: %s", err)
	}
	if !reflect.DeepEqual(o, empty) {
		t.Errorf("Expected BeforeInsertHook function to empty object, but got: %#v", o)
	}
	{{$alias.DownSingular}}BeforeInsertHooks = []{{$alias.UpSingular}}Hook{}

	Add{{$alias.UpSingular}}Hook(simmer.AfterInsertHook, {{$alias.DownSingular}}AfterInsertHook)
	if err = o.doAfterInsertHooks({{if not $data.NoContext}}ctx, {{end -}} nil); err != nil {
		t.Errorf("Unable to execute doAfterInsertHooks: %s", err)
	}
	if !reflect.DeepEqual(o, empty) {
		t.Errorf("Expected AfterInsertHook function to empty object, but got: %#v", o)
	}
	{{$alias.DownSingular}}AfterInsertHooks = []{{$alias.UpSingular}}Hook{}

	Add{{$alias.UpSingular}}Hook(simmer.AfterSelectHook, {{$alias.DownSingular}}AfterSelectHook)
	if err = o.doAfterSelectHooks({{if not $data.NoContext}}ctx, {{end -}} nil); err != nil {
		t.Errorf("Unable to execute doAfterSelectHooks: %s", err)
	}
	if !reflect.DeepEqual(o, empty) {
		t.Errorf("Expected AfterSelectHook function to empty object, but got: %#v", o)
	}
	{{$alias.DownSingular}}AfterSelectHooks = []{{$alias.UpSingular}}Hook{}

	Add{{$alias.UpSingular}}Hook(simmer.BeforeUpdateHook, {{$alias.DownSingular}}BeforeUpdateHook)
	if err = o.doBeforeUpdateHooks({{if not $data.NoContext}}ctx, {{end -}} nil); err != nil {
		t.Errorf("Unable to execute doBeforeUpdateHooks: %s", err)
	}
	if !reflect.DeepEqual(o, empty) {
		t.Errorf("Expected BeforeUpdateHook function to empty object, but got: %#v", o)
	}
	{{$alias.DownSingular}}BeforeUpdateHooks = []{{$alias.UpSingular}}Hook{}

	Add{{$alias.UpSingular}}Hook(simmer.AfterUpdateHook, {{$alias.DownSingular}}AfterUpdateHook)
	if err = o.doAfterUpdateHooks({{if not $data.NoContext}}ctx, {{end -}} nil); err != nil {
		t.Errorf("Unable to execute doAfterUpdateHooks: %s", err)
	}
	if !reflect.DeepEqual(o, empty) {
		t.Errorf("Expected AfterUpdateHook function to empty object, but got: %#v", o)
	}
	{{$alias.DownSingular}}AfterUpdateHooks = []{{$alias.UpSingular}}Hook{}

	Add{{$alias.UpSingular}}Hook(simmer.BeforeDeleteHook, {{$alias.DownSingular}}BeforeDeleteHook)
	if err = o.doBeforeDeleteHooks({{if not $data.NoContext}}ctx, {{end -}} nil); err != nil {
		t.Errorf("Unable to execute doBeforeDeleteHooks: %s", err)
	}
	if !reflect.DeepEqual(o, empty) {
		t.Errorf("Expected BeforeDeleteHook function to empty object, but got: %#v", o)
	}
	{{$alias.DownSingular}}BeforeDeleteHooks = []{{$alias.UpSingular}}Hook{}

	Add{{$alias.UpSingular}}Hook(simmer.AfterDeleteHook, {{$alias.DownSingular}}AfterDeleteHook)
	if err = o.doAfterDeleteHooks({{if not $data.NoContext}}ctx, {{end -}} nil); err != nil {
		t.Errorf("Unable to execute doAfterDeleteHooks: %s", err)
	}
	if !reflect.DeepEqual(o, empty) {
		t.Errorf("Expected AfterDeleteHook function to empty object, but got: %#v", o)
	}
	{{$alias.DownSingular}}AfterDeleteHooks = []{{$alias.UpSingular}}Hook{}

	Add{{$alias.UpSingular}}Hook(simmer.BeforeUpsertHook, {{$alias.DownSingular}}BeforeUpsertHook)
	if err = o.doBeforeUpsertHooks({{if not $data.NoContext}}ctx, {{end -}} nil); err != nil {
		t.Errorf("Unable to execute doBeforeUpsertHooks: %s", err)
	}
	if !reflect.DeepEqual(o, empty) {
		t.Errorf("Expected BeforeUpsertHook function to empty object, but got: %#v", o)
	}
	{{$alias.DownSingular}}BeforeUpsertHooks = []{{$alias.UpSingular}}Hook{}

	Add{{$alias.UpSingular}}Hook(simmer.AfterUpsertHook, {{$alias.DownSingular}}AfterUpsertHook)
	if err = o.doAfterUpsertHooks({{if not $data.NoContext}}ctx, {{end -}} nil); err != nil {
		t.Errorf("Unable to execute doAfterUpsertHooks: %s", err)
	}
	if !reflect.DeepEqual(o, empty) {
		t.Errorf("Expected AfterUpsertHook function to empty object, but got: %#v", o)
	}
	{{$alias.DownSingular}}AfterUpsertHooks = []{{$alias.UpSingular}}Hook{}
}
{{- end}}
