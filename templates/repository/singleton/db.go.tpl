type DB struct {
	*sql.DB
}

func New(conn string) (*DB, error) {

	db, err := sql.Open("pgx", conn)
	if err != nil {
		return nil, err
	}

	return &DB{db}, nil
}

var txCtxKey = &contextKey{"tx"}

type contextKey struct {
	name string
}

func txFromContext(ctx context.Context) (*sql.Tx, bool) {
	temp := ctx.Value(txCtxKey)
	if temp != nil {
		if tx, ok := temp.(*sql.Tx); ok {
			return tx, true
		}
	}
	return nil, false
}

func txToContext(ctx context.Context, tx *sql.Tx) context.Context {
	return context.WithValue(ctx, txCtxKey, tx)
}

type Executor = simmer.ContextExecutor

type executor interface {
	getExecutor(ctx context.Context) Executor
}

func (db *DB) getExecutor(ctx context.Context) Executor {
	if tx, use := txFromContext(ctx); use {
		return tx
	} else {
		return db.DB
	}
}

func (db *DB) Begin(ctx context.Context) (*Tx, context.Context, error) {
	context.Background()
	dbTx, err := db.DB.Begin()
	if err != nil {
		return nil, ctx, err
	}
	return &Tx{dbTx}, txToContext(ctx, dbTx), nil
}

type Tx struct {
	tx *sql.Tx
}

func (tx *Tx) Commit() error {
	return tx.tx.Commit()
}

func (tx *Tx) Rollback() error {
	return tx.tx.Rollback()
}

type Columns = simmer.Columns

func Infer() Columns {
	return simmer.Infer()
}

var defaultOptions = options{Columns: Infer()}

type options struct {
	Columns Columns
	HardDelete bool
}

// Option modifies a options object.
type Option interface {
	Apply(opts *options)
}

type optionsFunc func(opts *options)

// Apply calls f(q).
func (f optionsFunc) Apply(opts *options) {
	f(opts)
}

func SelectColumns(cols Columns) Option {
	return optionsFunc(func(opts *options) {
		opts.Columns = cols
	})
}

func initOptions(opts ...Option) *options {
	o := defaultOptions
	for _, opt := range opts {
		opt.Apply(&o)
	}
	return &o
}

func SetColumns(cols Columns) Option {
	return optionsFunc(func(opts *options) {
		opts.Columns = cols
	})
}

func HardDelete(hardDelete bool) Option {
	return optionsFunc(func(opts *options) {
		opts.HardDelete = hardDelete
	})
}