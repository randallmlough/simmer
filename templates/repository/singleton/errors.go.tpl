
var ErrNoData = errors.New("no data")

const (
    sqlNonNullConstraintViolationCode = "23502"
    sqlUniqueConstraintViolationCode = "23505"
    sqlCheckConstraintViolationCode = "23514"
    sqlForeignKeyConstraintViolationCode = "23503"
)