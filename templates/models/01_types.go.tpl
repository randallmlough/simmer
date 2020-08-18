{{- $data := .Data -}}
{{- $model := .Model -}}
{{- $options := .Options -}}
{{if $model.Table.IsJoinTable -}}
{{else -}}
{{- $alias := $data.Aliases.Table $model.Table.Name -}}
var (
	{{$alias.DownSingular}}AllColumns               = []string{{"{"}}{{$model.Table.Columns | columnNames | stringMap (stringFuncs "quoteWrap") | join ", "}}{{"}"}}
	{{if $data.Dialect.UseAutoColumns -}}
	{{$alias.DownSingular}}ColumnsWithAuto = []string{{"{"}}{{$model.Table.Columns | filterColumnsByAuto true | columnNames | stringMap (stringFuncs "quoteWrap") | join ","}}{{"}"}}
	{{end -}}
	{{$alias.DownSingular}}ColumnsWithoutDefault = []string{{"{"}}{{$model.Table.Columns | filterColumnsByDefault false | columnNames | stringMap (stringFuncs "quoteWrap") | join ","}}{{"}"}}
	{{$alias.DownSingular}}ColumnsWithDefault    = []string{{"{"}}{{$model.Table.Columns | filterColumnsByDefault true | columnNames | stringMap (stringFuncs "quoteWrap") | join ","}}{{"}"}}
	{{$alias.DownSingular}}PrimaryKeyColumns     = []string{{"{"}}{{$model.Table.PKey.Columns | stringMap (stringFuncs "quoteWrap") | join ", "}}{{"}"}}
)

type (
	// {{$alias.UpSingular}}Slice is an alias for a slice of pointers to {{$alias.UpSingular}}.
	// This should generally be used opposed to []{{$alias.UpSingular}}.
	{{$alias.UpSingular}}Slice []*{{$alias.UpSingular}}
	{{if not $data.NoHooks -}}
	// {{$alias.UpSingular}}Hook is the signature for custom {{$alias.UpSingular}} hook methods
	{{$alias.UpSingular}}Hook func({{if $data.NoContext}}simmer.Executor{{else}}context.Context, simmer.ContextExecutor{{end}}, *{{$alias.UpSingular}}) error
	{{- end}}

	{{$alias.DownSingular}}Query struct {
		*queries.Query
	}
)

// Cache for insert, update and upsert
var (
	{{$alias.DownSingular}}Type = reflect.TypeOf(&{{$alias.UpSingular}}{})
	{{$alias.DownSingular}}Mapping = queries.MakeStructMapping({{$alias.DownSingular}}Type)
	{{$alias.DownSingular}}PrimaryKeyMapping, _ = queries.BindMapping({{$alias.DownSingular}}Type, {{$alias.DownSingular}}Mapping, {{$alias.DownSingular}}PrimaryKeyColumns)
	{{$alias.DownSingular}}InsertCacheMut sync.RWMutex
	{{$alias.DownSingular}}InsertCache = make(map[string]insertCache)
	{{$alias.DownSingular}}UpdateCacheMut sync.RWMutex
	{{$alias.DownSingular}}UpdateCache = make(map[string]updateCache)
	{{$alias.DownSingular}}UpsertCacheMut sync.RWMutex
	{{$alias.DownSingular}}UpsertCache = make(map[string]insertCache)
)

var (
	// Force time package dependency for automated UpdatedAt/CreatedAt.
	_ = time.Second
	// Force qmhelper dependency for where clause generation (which doesn't
	// always happen)
	_ = queries.WhereOp
)
{{end -}}
