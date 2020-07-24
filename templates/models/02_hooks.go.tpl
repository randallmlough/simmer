{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{- if not $options.NoHooks -}}
{{- $alias := $data.Aliases.Table $model.Table.Name}}

var {{$alias.DownSingular}}BeforeInsertHooks []{{$alias.UpSingular}}Hook
var {{$alias.DownSingular}}BeforeUpdateHooks []{{$alias.UpSingular}}Hook
var {{$alias.DownSingular}}BeforeDeleteHooks []{{$alias.UpSingular}}Hook
var {{$alias.DownSingular}}BeforeUpsertHooks []{{$alias.UpSingular}}Hook

var {{$alias.DownSingular}}AfterInsertHooks []{{$alias.UpSingular}}Hook
var {{$alias.DownSingular}}AfterSelectHooks []{{$alias.UpSingular}}Hook
var {{$alias.DownSingular}}AfterUpdateHooks []{{$alias.UpSingular}}Hook
var {{$alias.DownSingular}}AfterDeleteHooks []{{$alias.UpSingular}}Hook
var {{$alias.DownSingular}}AfterUpsertHooks []{{$alias.UpSingular}}Hook

// doBeforeInsertHooks executes all "before insert" hooks.
func (o *{{$alias.UpSingular}}) doBeforeInsertHooks({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) (err error) {
	{{if not $options.NoContext -}}
	if simmer.HooksAreSkipped(ctx) {
		return nil
	}

	{{end -}}
	for _, hook := range {{$alias.DownSingular}}BeforeInsertHooks {
		if err := hook({{if not $options.NoContext}}ctx, {{end -}} exec, o); err != nil {
			return err
		}
	}

	return nil
}

// doBeforeUpdateHooks executes all "before Update" hooks.
func (o *{{$alias.UpSingular}}) doBeforeUpdateHooks({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) (err error) {
	{{if not $options.NoContext -}}
	if simmer.HooksAreSkipped(ctx) {
		return nil
	}

	{{end -}}
	for _, hook := range {{$alias.DownSingular}}BeforeUpdateHooks {
		if err := hook({{if not $options.NoContext}}ctx, {{end -}} exec, o); err != nil {
			return err
		}
	}

	return nil
}

// doBeforeDeleteHooks executes all "before Delete" hooks.
func (o *{{$alias.UpSingular}}) doBeforeDeleteHooks({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) (err error) {
	{{if not $options.NoContext -}}
	if simmer.HooksAreSkipped(ctx) {
		return nil
	}

	{{end -}}
	for _, hook := range {{$alias.DownSingular}}BeforeDeleteHooks {
		if err := hook({{if not $options.NoContext}}ctx, {{end -}} exec, o); err != nil {
			return err
		}
	}

	return nil
}

// doBeforeUpsertHooks executes all "before Upsert" hooks.
func (o *{{$alias.UpSingular}}) doBeforeUpsertHooks({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) (err error) {
	{{if not $options.NoContext -}}
	if simmer.HooksAreSkipped(ctx) {
		return nil
	}

	{{end -}}
	for _, hook := range {{$alias.DownSingular}}BeforeUpsertHooks {
		if err := hook({{if not $options.NoContext}}ctx, {{end -}} exec, o); err != nil {
			return err
		}
	}

	return nil
}

// doAfterInsertHooks executes all "after Insert" hooks.
func (o *{{$alias.UpSingular}}) doAfterInsertHooks({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) (err error) {
	{{if not $options.NoContext -}}
	if simmer.HooksAreSkipped(ctx) {
		return nil
	}

	{{end -}}
	for _, hook := range {{$alias.DownSingular}}AfterInsertHooks {
		if err := hook({{if not $options.NoContext}}ctx, {{end -}} exec, o); err != nil {
			return err
		}
	}

	return nil
}

// doAfterSelectHooks executes all "after Select" hooks.
func (o *{{$alias.UpSingular}}) doAfterSelectHooks({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) (err error) {
	{{if not $options.NoContext -}}
	if simmer.HooksAreSkipped(ctx) {
		return nil
	}

	{{end -}}
	for _, hook := range {{$alias.DownSingular}}AfterSelectHooks {
		if err := hook({{if not $options.NoContext}}ctx, {{end -}} exec, o); err != nil {
			return err
		}
	}

	return nil
}

// doAfterUpdateHooks executes all "after Update" hooks.
func (o *{{$alias.UpSingular}}) doAfterUpdateHooks({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) (err error) {
	{{if not $options.NoContext -}}
	if simmer.HooksAreSkipped(ctx) {
		return nil
	}

	{{end -}}
	for _, hook := range {{$alias.DownSingular}}AfterUpdateHooks {
		if err := hook({{if not $options.NoContext}}ctx, {{end -}} exec, o); err != nil {
			return err
		}
	}

	return nil
}

// doAfterDeleteHooks executes all "after Delete" hooks.
func (o *{{$alias.UpSingular}}) doAfterDeleteHooks({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) (err error) {
	{{if not $options.NoContext -}}
	if simmer.HooksAreSkipped(ctx) {
		return nil
	}

	{{end -}}
	for _, hook := range {{$alias.DownSingular}}AfterDeleteHooks {
		if err := hook({{if not $options.NoContext}}ctx, {{end -}} exec, o); err != nil {
			return err
		}
	}

	return nil
}

// doAfterUpsertHooks executes all "after Upsert" hooks.
func (o *{{$alias.UpSingular}}) doAfterUpsertHooks({{if $options.NoContext}}exec simmer.Executor{{else}}ctx context.Context, exec simmer.ContextExecutor{{end}}) (err error) {
	{{if not $options.NoContext -}}
	if simmer.HooksAreSkipped(ctx) {
		return nil
	}

	{{end -}}
	for _, hook := range {{$alias.DownSingular}}AfterUpsertHooks {
		if err := hook({{if not $options.NoContext}}ctx, {{end -}} exec, o); err != nil {
			return err
		}
	}

	return nil
}

// Add{{$alias.UpSingular}}Hook registers your hook function for all future operations.
func Add{{$alias.UpSingular}}Hook(hookPoint simmer.HookPoint, {{$alias.DownSingular}}Hook {{$alias.UpSingular}}Hook) {
	switch hookPoint {
		case simmer.BeforeInsertHook:
			{{$alias.DownSingular}}BeforeInsertHooks = append({{$alias.DownSingular}}BeforeInsertHooks, {{$alias.DownSingular}}Hook)
		case simmer.BeforeUpdateHook:
			{{$alias.DownSingular}}BeforeUpdateHooks = append({{$alias.DownSingular}}BeforeUpdateHooks, {{$alias.DownSingular}}Hook)
		case simmer.BeforeDeleteHook:
			{{$alias.DownSingular}}BeforeDeleteHooks = append({{$alias.DownSingular}}BeforeDeleteHooks, {{$alias.DownSingular}}Hook)
		case simmer.BeforeUpsertHook:
			{{$alias.DownSingular}}BeforeUpsertHooks = append({{$alias.DownSingular}}BeforeUpsertHooks, {{$alias.DownSingular}}Hook)
		case simmer.AfterInsertHook:
			{{$alias.DownSingular}}AfterInsertHooks = append({{$alias.DownSingular}}AfterInsertHooks, {{$alias.DownSingular}}Hook)
		case simmer.AfterSelectHook:
			{{$alias.DownSingular}}AfterSelectHooks = append({{$alias.DownSingular}}AfterSelectHooks, {{$alias.DownSingular}}Hook)
		case simmer.AfterUpdateHook:
			{{$alias.DownSingular}}AfterUpdateHooks = append({{$alias.DownSingular}}AfterUpdateHooks, {{$alias.DownSingular}}Hook)
		case simmer.AfterDeleteHook:
			{{$alias.DownSingular}}AfterDeleteHooks = append({{$alias.DownSingular}}AfterDeleteHooks, {{$alias.DownSingular}}Hook)
		case simmer.AfterUpsertHook:
			{{$alias.DownSingular}}AfterUpsertHooks = append({{$alias.DownSingular}}AfterUpsertHooks, {{$alias.DownSingular}}Hook)
	}
}
{{- end}}
