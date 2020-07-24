
type Query = queries.QueryMod

// SQL allows you to execute a plain SQL statement
func SQL(sql string, args ...interface{}) Query {
	return queries.SQL(sql, args...)
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
//   models.Users(queries.Load("Videos.Tags"))
//
// In order to filter better on the query for the relationships you can additionally
// supply query mods.
//
//   models.Users(queries.Load("Videos.Tags", Where("deleted = ?", isDeleted)))
//
// Keep in mind the above only sets the query mods for the query on the last specified
// relationship. In this case, only Tags will get the query mod. If you want to do
// intermediate relationships with query mods you must specify them separately:
//
//   models.Users(
//     queries.Load("Videos", Where("deleted = false"))
//     queries.Load("Videos.Tags", Where("deleted = ?", isDeleted))
//   )
func Load(relationship string, mods ...Query) Query {
	return queries.Load(relationship, mods...)
}

func LeftOuterJoin(clause string, args ...interface{}) Query {
	return queries.LeftOuterJoin(clause, args...)
}

// InnerJoin on another table
func InnerJoin(clause string, args ...interface{}) Query {
	return queries.InnerJoin(clause, args...)
}

// RightOuterJoin on another table
func RightOuterJoin(clause string, args ...interface{}) Query {
	return queries.RightOuterJoin(clause, args...)
}

// FullOuterJoin on another table
func FullOuterJoin(clause string, args ...interface{}) Query {
	return queries.FullOuterJoin(clause, args...)
}

// Distinct allows you to filter duplicates
func Distinct(clause string) Query {
	return queries.Distinct(clause)
}

// With allows you to pass in a Common Table Expression clause (and args)
func With(clause string, args ...interface{}) Query {
	return queries.With(clause, args...)
}

// Select specific columns opposed to all columns
func Select(columns ...string) Query {
	return queries.Select(columns...)
}

// Where allows you to specify a where clause for your statement. If multiple
// Where statements are used they are combined with 'and'
func Where(clause string, args ...interface{}) Query {
	return queries.Where(clause, args...)
}

// And allows you to specify a where clause separated by an AND for your statement
// And is a duplicate of the Where function, but allows for more natural looking
// query mod chains, for example: (Where("a=?"), And("b=?"), Or("c=?")))
//
// Because Where statements are by default combined with and, there's no reason
// to call this method as it behaves the same as "Where"
func And(clause string, args ...interface{}) Query {
	return queries.And(clause, args...)
}

// Or allows you to specify a where clause separated by an OR for your statement
func Or(clause string, args ...interface{}) Query {
	return queries.Or(clause, args...)
}

// Or2 takes a Where query mod and turns it into an Or. It can be detrimental
// if used on things that are not Where query mods as it will still modify the
// last Where statement into an Or.
func Or2(q Query) Query {
	return queries.Or2(q)
}

// WhereIn allows you to specify a "x IN (set)" clause for your where statement
// Example clauses: "column in ?", "(column1,column2) in ?"
func WhereIn(clause string, args ...interface{}) Query {
	return queries.WhereIn(clause, args...)
}

// AndIn allows you to specify a "x IN (set)" clause separated by an AndIn
// for your where statement. AndIn is a duplicate of the WhereIn function, but
// allows for more natural looking query mod chains, for example:
// (WhereIn("column1 in ?"), AndIn("column2 in ?"), OrIn("column3 in ?"))
func AndIn(clause string, args ...interface{}) Query {
	return queries.AndIn(clause, args...)
}

// OrIn allows you to specify an IN clause separated by
// an OR for your where statement
func OrIn(clause string, args ...interface{}) Query {
	return queries.OrIn(clause, args...)
}

// WhereNotIn allows you to specify a "x NOT IN (set)" clause for your where
// statement. Example clauses: "column not in ?",
// "(column1,column2) not in ?"
func WhereNotIn(clause string, args ...interface{}) Query {
	return queries.WhereNotIn(clause, args...)
}

// AndNotIn allows you to specify a "x NOT IN (set)" clause separated by an
// AndNotIn for your where statement. AndNotIn is a duplicate of the WhereNotIn
// function, but allows for more natural looking query mod chains, for example:
// (WhereNotIn("column1 not in ?"), AndIn("column2 not in ?"), OrIn("column3 not
// in ?"))
func AndNotIn(clause string, args ...interface{}) Query {
	return queries.AndNotIn(clause, args...)
}

// OrNotIn allows you to specify a NOT IN clause separated by
// an OR for your where statement
func OrNotIn(clause string, args ...interface{}) Query {
	return queries.OrNotIn(clause, args...)
}

// Expr groups where query mods. It's detrimental to use this with any other
// type of Query Mod because the effects will always only affect where clauses.
//
// When Expr is used, the entire query will stop doing automatic paretheses
// for the where statement and you must use Expr anywhere you would like them.
//
// Do NOT use with anything except where.
func Expr(wheremods ...Query) Query {
	return queries.Expr(wheremods...)
}

// GroupBy allows you to specify a group by clause for your statement
func GroupBy(clause string) Query {
	return queries.GroupBy(clause)
}

// OrderBy allows you to specify a order by clause for your statement
func OrderBy(clause string) Query {
	return queries.OrderBy(clause)
}

// Having allows you to specify a having clause for your statement
func Having(clause string, args ...interface{}) Query {
	return queries.Having(clause, args...)
}

// From allows to specify the table for your statement
func From(from string) Query {
	return queries.From(from)
}

// Limit the number of returned rows
func Limit(limit int) Query {
	return queries.Limit(limit)
}

// Offset into the results
func Offset(offset int) Query {
	return queries.Offset(offset)
}

// For inserts a concurrency locking clause at the end of your statement
func For(clause string) Query {
	return queries.For(clause)
}

// Rels is an alias for strings.Join to make it easier to use relationship name
// constants in Load.
func Rels(r ...string) string {
	return strings.Join(r, ".")
}
