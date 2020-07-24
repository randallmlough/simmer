{{ $data := .Data }}
var dialect = database.Dialect{
	LQ: 0x{{printf "%x" $data.Dialect.LQ}},
	RQ: 0x{{printf "%x" $data.Dialect.RQ}},

	UseIndexPlaceholders:    {{$data.Dialect.UseIndexPlaceholders}},
	UseLastInsertID:         {{$data.Dialect.UseLastInsertID}},
	UseSchema:               {{$data.Dialect.UseSchema}},
	UseDefaultKeyword:       {{$data.Dialect.UseDefaultKeyword}},
	UseAutoColumns:          {{$data.Dialect.UseAutoColumns}},
	UseTopClause:            {{$data.Dialect.UseTopClause}},
	UseOutputClause:         {{$data.Dialect.UseOutputClause}},
	UseCaseWhenExistsClause: {{$data.Dialect.UseCaseWhenExistsClause}},
}

// NewQuery initializes a new Query using the passed in QueryMods
func NewQuery(mods ...queries.QueryMod) *queries.Query {
	q := &queries.Query{}
	queries.SetDialect(q, &dialect)
	queries.Apply(q, mods...)

	return q
}
