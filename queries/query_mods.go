package queries

import (
	"fmt"
	"reflect"
	"strings"
)

// QueryMod modifies a query object.
type QueryMod interface {
	Apply(q *Query)
}

// The QueryModFunc type is an adapter to allow the use
// of ordinary functions for query modifying. If f is a
// function with the appropriate signature,
// QueryModFunc(f) is a QueryMod that calls f.
type QueryModFunc func(q *Query)

// Apply calls f(q).
func (f QueryModFunc) Apply(q *Query) {
	f(q)
}

type queryMods []QueryMod

// Apply applies the query mods to a query, satisfying
// the applicator interface in  This "clever"
// inversion of dependency is because suddenly the
// eager loading needs to be able to store query mods
// in the query object, which before - never knew about
// query mods.
func (m queryMods) Apply(q *Query) {
	Apply(q, m...)
}

// Apply the query mods to the Query object
func Apply(q *Query, mods ...QueryMod) {
	for _, mod := range mods {
		mod.Apply(q)
	}
}

type sqlQueryMod struct {
	sql  string
	args []interface{}
}

// Apply implements QueryMod.Apply.
func (qm sqlQueryMod) Apply(q *Query) {
	SetSQL(q, qm.sql, qm.args...)
}

// SQL allows you to execute a plain SQL statement
func SQL(sql string, args ...interface{}) QueryMod {
	return sqlQueryMod{
		sql:  sql,
		args: args,
	}
}

type loadQueryMod struct {
	relationship string
	mods         []QueryMod
}

// Apply implements QueryMod.Apply.
func (qm loadQueryMod) Apply(q *Query) {
	AppendLoad(q, qm.relationship)

	if len(qm.mods) != 0 {
		SetLoadMods(q, qm.relationship, queryMods(qm.mods))
	}
}

// Load allows you to specify foreign key relationships to eager load
// for your query. Passed in relationships need to be in the format
// MyThing or MyThings.
// Relationship name plurality is important, if your relationship is
// singular, you need to specify the singular form and vice versa.
//
// In the following example we see how to eager load a users's videos
// and the video's tags comments, and publisher during a query to find users.
//
//   models.Users(qm.Load("Videos.Tags"))
//
// In order to filter better on the query for the relationships you can additionally
// supply query mods.
//
//   models.Users(qm.Load("Videos.Tags", Where("deleted = ?", isDeleted)))
//
// Keep in mind the above only sets the query mods for the query on the last specified
// relationship. In this case, only Tags will get the query mod. If you want to do
// intermediate relationships with query mods you must specify them separately:
//
//   models.Users(
//     qm.Load("Videos", Where("deleted = false"))
//     qm.Load("Videos.Tags", Where("deleted = ?", isDeleted))
//   )
func Load(relationship string, mods ...QueryMod) QueryMod {
	return loadQueryMod{
		relationship: relationship,
		mods:         mods,
	}
}

type innerJoinQueryMod struct {
	clause string
	args   []interface{}
}

// Apply implements QueryMod.Apply.
func (qm innerJoinQueryMod) Apply(q *Query) {
	AppendInnerJoin(q, qm.clause, qm.args...)
}

// InnerJoin on another table
func InnerJoin(clause string, args ...interface{}) QueryMod {
	return innerJoinQueryMod{
		clause: clause,
		args:   args,
	}
}

type leftOuterJoinQueryMod struct {
	clause string
	args   []interface{}
}

// Apply implements QueryMod.Apply.
func (qm leftOuterJoinQueryMod) Apply(q *Query) {
	AppendLeftOuterJoin(q, qm.clause, qm.args...)
}

// LeftOuterJoin on another table
func LeftOuterJoin(clause string, args ...interface{}) QueryMod {
	return leftOuterJoinQueryMod{
		clause: clause,
		args:   args,
	}
}

type rightOuterJoinQueryMod struct {
	clause string
	args   []interface{}
}

// Apply implements QueryMod.Apply.
func (qm rightOuterJoinQueryMod) Apply(q *Query) {
	AppendRightOuterJoin(q, qm.clause, qm.args...)
}

// RightOuterJoin on another table
func RightOuterJoin(clause string, args ...interface{}) QueryMod {
	return rightOuterJoinQueryMod{
		clause: clause,
		args:   args,
	}
}

type fullOuterJoinQueryMod struct {
	clause string
	args   []interface{}
}

// Apply implements QueryMod.Apply.
func (qm fullOuterJoinQueryMod) Apply(q *Query) {
	AppendFullOuterJoin(q, qm.clause, qm.args...)
}

// FullOuterJoin on another table
func FullOuterJoin(clause string, args ...interface{}) QueryMod {
	return fullOuterJoinQueryMod{
		clause: clause,
		args:   args,
	}
}

type distinctQueryMod struct {
	clause string
}

// Apply implements QueryMod.Apply.
func (qm distinctQueryMod) Apply(q *Query) {
	SetDistinct(q, qm.clause)
}

// Distinct allows you to filter duplicates
func Distinct(clause string) QueryMod {
	return distinctQueryMod{
		clause: clause,
	}
}

type withQueryMod struct {
	clause string
	args   []interface{}
}

// Apply implements QueryMod.Apply.
func (qm withQueryMod) Apply(q *Query) {
	AppendWith(q, qm.clause, qm.args...)
}

// With allows you to pass in a Common Table Expression clause (and args)
func With(clause string, args ...interface{}) QueryMod {
	return withQueryMod{
		clause: clause,
		args:   args,
	}
}

type selectQueryMod struct {
	columns []string
}

// Apply implements QueryMod.Apply.
func (qm selectQueryMod) Apply(q *Query) {
	AppendSelect(q, qm.columns...)
}

// Select specific columns opposed to all columns
func Select(columns ...string) QueryMod {
	return selectQueryMod{
		columns: columns,
	}
}

// Where allows you to specify a where clause for your statement. If multiple
// Where statements are used they are combined with 'and'
func Where(clause string, args ...interface{}) QueryMod {
	return WhereQueryMod{
		Clause: clause,
		Args:   args,
	}
}

type andQueryMod struct {
	clause string
	args   []interface{}
}

// Apply implements QueryMod.Apply.
func (qm andQueryMod) Apply(q *Query) {
	AppendWhere(q, qm.clause, qm.args...)
}

// And allows you to specify a where clause separated by an AND for your statement
// And is a duplicate of the Where function, but allows for more natural looking
// query mod chains, for example: (Where("a=?"), And("b=?"), Or("c=?")))
//
// Because Where statements are by default combined with and, there's no reason
// to call this method as it behaves the same as "Where"
func And(clause string, args ...interface{}) QueryMod {
	return andQueryMod{
		clause: clause,
		args:   args,
	}
}

type orQueryMod struct {
	clause string
	args   []interface{}
}

// Apply implements QueryMod.Apply.
func (qm orQueryMod) Apply(q *Query) {
	AppendWhere(q, qm.clause, qm.args...)
	SetLastWhereAsOr(q)
}

// Or allows you to specify a where clause separated by an OR for your statement
func Or(clause string, args ...interface{}) QueryMod {
	return orQueryMod{
		clause: clause,
		args:   args,
	}
}

// Or2 takes a Where query mod and turns it into an Or. It can be detrimental
// if used on things that are not Where query mods as it will still modify the
// last Where statement into an Or.
func Or2(q QueryMod) QueryMod {
	return or2QueryMod{inner: q}
}

type or2QueryMod struct {
	inner QueryMod
}

func (qm or2QueryMod) Apply(q *Query) {
	qm.inner.Apply(q)
	SetLastWhereAsOr(q)
}

// Apply implements QueryMod.Apply.
type whereInQueryMod struct {
	clause string
	args   []interface{}
}

func (qm whereInQueryMod) Apply(q *Query) {
	AppendIn(q, qm.clause, qm.args...)
}

// WhereIn allows you to specify a "x IN (set)" clause for your where statement
// Example clauses: "column in ?", "(column1,column2) in ?"
func WhereIn(clause string, args ...interface{}) QueryMod {
	return whereInQueryMod{
		clause: clause,
		args:   args,
	}
}

type andInQueryMod struct {
	clause string
	args   []interface{}
}

// Apply implements QueryMod.Apply.
func (qm andInQueryMod) Apply(q *Query) {
	AppendIn(q, qm.clause, qm.args...)
}

// AndIn allows you to specify a "x IN (set)" clause separated by an AndIn
// for your where statement. AndIn is a duplicate of the WhereIn function, but
// allows for more natural looking query mod chains, for example:
// (WhereIn("column1 in ?"), AndIn("column2 in ?"), OrIn("column3 in ?"))
func AndIn(clause string, args ...interface{}) QueryMod {
	return andInQueryMod{
		clause: clause,
		args:   args,
	}
}

type orInQueryMod struct {
	clause string
	args   []interface{}
}

// Apply implements QueryMod.Apply.
func (qm orInQueryMod) Apply(q *Query) {
	AppendIn(q, qm.clause, qm.args...)
	SetLastInAsOr(q)
}

// OrIn allows you to specify an IN clause separated by
// an OR for your where statement
func OrIn(clause string, args ...interface{}) QueryMod {
	return orInQueryMod{
		clause: clause,
		args:   args,
	}
}

type whereNotInQueryMod struct {
	clause string
	args   []interface{}
}

// Apply implements QueryMod.Apply.
func (qm whereNotInQueryMod) Apply(q *Query) {
	AppendIn(q, qm.clause, qm.args...)
}

// WhereNotIn allows you to specify a "x NOT IN (set)" clause for your where
// statement. Example clauses: "column not in ?",
// "(column1,column2) not in ?"
func WhereNotIn(clause string, args ...interface{}) QueryMod {
	return whereNotInQueryMod{
		clause: clause,
		args:   args,
	}
}

type andNotInQueryMod struct {
	clause string
	args   []interface{}
}

// Apply implements QueryMod.Apply.
func (qm andNotInQueryMod) Apply(q *Query) {
	AppendIn(q, qm.clause, qm.args...)
}

// AndNotIn allows you to specify a "x NOT IN (set)" clause separated by an
// AndNotIn for your where statement. AndNotIn is a duplicate of the WhereNotIn
// function, but allows for more natural looking query mod chains, for example:
// (WhereNotIn("column1 not in ?"), AndIn("column2 not in ?"), OrIn("column3 not
// in ?"))
func AndNotIn(clause string, args ...interface{}) QueryMod {
	return andNotInQueryMod{
		clause: clause,
		args:   args,
	}
}

type orNotInQueryMod struct {
	clause string
	args   []interface{}
}

// Apply implements QueryMod.Apply.
func (qm orNotInQueryMod) Apply(q *Query) {
	AppendIn(q, qm.clause, qm.args...)
	SetLastInAsOr(q)
}

// OrNotIn allows you to specify a NOT IN clause separated by
// an OR for your where statement
func OrNotIn(clause string, args ...interface{}) QueryMod {
	return orNotInQueryMod{
		clause: clause,
		args:   args,
	}
}

// Expr groups where query mods. It's detrimental to use this with any other
// type of Query Mod because the effects will always only affect where clauses.
//
// When Expr is used, the entire query will stop doing automatic paretheses
// for the where statement and you must use Expr anywhere you would like them.
//
// Do NOT use with anything except where.
func Expr(wheremods ...QueryMod) QueryMod {
	return exprMod{mods: wheremods}
}

type exprMod struct {
	mods []QueryMod
}

// Apply implements QueryMod.Apply
func (qm exprMod) Apply(q *Query) {
	AppendWhereLeftParen(q)
	for _, mod := range qm.mods {
		mod.Apply(q)
	}
	AppendWhereRightParen(q)
}

type groupByQueryMod struct {
	clause string
}

// Apply implements QueryMod.Apply.
func (qm groupByQueryMod) Apply(q *Query) {
	AppendGroupBy(q, qm.clause)
}

// GroupBy allows you to specify a group by clause for your statement
func GroupBy(clause string) QueryMod {
	return groupByQueryMod{
		clause: clause,
	}
}

type orderByQueryMod struct {
	clause string
}

// Apply implements QueryMod.Apply.
func (qm orderByQueryMod) Apply(q *Query) {
	AppendOrderBy(q, qm.clause)
}

// OrderBy allows you to specify a order by clause for your statement
func OrderBy(clause string) QueryMod {
	return orderByQueryMod{
		clause: clause,
	}
}

type havingQueryMod struct {
	clause string
	args   []interface{}
}

// Apply implements QueryMod.Apply.
func (qm havingQueryMod) Apply(q *Query) {
	AppendHaving(q, qm.clause, qm.args...)
}

// Having allows you to specify a having clause for your statement
func Having(clause string, args ...interface{}) QueryMod {
	return havingQueryMod{
		clause: clause,
		args:   args,
	}
}

type fromQueryMod struct {
	from string
}

// Apply implements QueryMod.Apply.
func (qm fromQueryMod) Apply(q *Query) {
	AppendFrom(q, qm.from)
}

// From allows to specify the table for your statement
func From(from string) QueryMod {
	return fromQueryMod{
		from: from,
	}
}

type limitQueryMod struct {
	limit int
}

// Apply implements QueryMod.Apply.
func (qm limitQueryMod) Apply(q *Query) {
	SetLimit(q, qm.limit)
}

// Limit the number of returned rows
func Limit(limit int) QueryMod {
	return limitQueryMod{
		limit: limit,
	}
}

type offsetQueryMod struct {
	offset int
}

// Apply implements QueryMod.Apply.
func (qm offsetQueryMod) Apply(q *Query) {
	SetOffset(q, qm.offset)
}

// Offset into the results
func Offset(offset int) QueryMod {
	return offsetQueryMod{
		offset: offset,
	}
}

type forQueryMod struct {
	clause string
}

// Apply implements QueryMod.Apply.
func (qm forQueryMod) Apply(q *Query) {
	SetFor(q, qm.clause)
}

// For inserts a concurrency locking clause at the end of your statement
func For(clause string) QueryMod {
	return forQueryMod{
		clause: clause,
	}
}

// Rels is an alias for strings.Join to make it easier to use relationship name
// constants in Load.
func Rels(r ...string) string {
	return strings.Join(r, ".")
}

// Nullable object
type Nullable interface {
	IsZero() bool
}

// WhereQueryMod allows construction of where clauses
type WhereQueryMod struct {
	Clause string
	Args   []interface{}
}

// Apply implements QueryMod.Apply.
func (qm WhereQueryMod) Apply(q *Query) {
	AppendWhere(q, qm.Clause, qm.Args...)
}

// WhereNullEQ is a helper for doing equality with null types
func WhereNullEQ(name string, negated bool, value interface{}) WhereQueryMod {
	isNull := false
	if nullable, ok := value.(Nullable); ok {
		isNull = nullable.IsZero()
	} else {
		isNull = reflect.ValueOf(value).IsNil()
	}

	if isNull {
		var not string
		if negated {
			not = "not "
		}
		return WhereQueryMod{
			Clause: fmt.Sprintf("%s is %snull", name, not),
		}
	}

	op := "="
	if negated {
		op = "!="
	}

	return WhereQueryMod{
		Clause: fmt.Sprintf("%s %s ?", name, op),
		Args:   []interface{}{value},
	}
}

// WhereIsNull is a helper that just returns "name is null"
func WhereIsNull(name string) WhereQueryMod {
	return WhereQueryMod{Clause: fmt.Sprintf("%s is null", name)}
}

// WhereIsNotNull is a helper that just returns "name is not null"
func WhereIsNotNull(name string) WhereQueryMod {
	return WhereQueryMod{Clause: fmt.Sprintf("%s is not null", name)}
}

type operator string

// Supported operations
const (
	EQ  operator = "="
	NEQ operator = "!="
	LT  operator = "<"
	LTE operator = "<="
	GT  operator = ">"
	GTE operator = ">="
)

// Where is a helper for doing operations on primitive types
func WhereOp(name string, operator operator, value interface{}) WhereQueryMod {
	return WhereQueryMod{
		Clause: fmt.Sprintf("%s %s ?", name, string(operator)),
		Args:   []interface{}{value},
	}
}
