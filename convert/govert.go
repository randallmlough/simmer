package convert

import (
	"github.com/99designs/gqlgen/codegen/config"
	"github.com/99designs/gqlgen/plugin"
)

var defaultConfig = Config{
	Aliases: map[string][]string{
		"Auth": {"AuthRegister", "AuthAuthenticate", "Auth"},
	},
}

func New(output, backend, frontend Directory, opts ...Option) plugin.Plugin {
	c := &Convert{
		output:         output,
		backend:        backend,
		frontend:       frontend,
		primaryKeyType: primaryKeyType(primaryKeyUint),
		Cfg:            &defaultConfig,
	}

	for _, opt := range opts {
		opt.apply(c)
	}

	if c.rootImportPath == "" {
		c.rootImportPath = getRootImportPath()
	}
	return c
}

// An Option configures a Logger.
type Option interface {
	apply(*Convert)
}

// optionFunc wraps a func so it satisfies the Option interface.
type optionFunc func(*Convert)

func (f optionFunc) apply(c *Convert) {
	f(c)
}
func SetConfig(cfg *Config) Option {
	return optionFunc(func(c *Convert) {
		c.Cfg = cfg
	})
}
func PrimaryKeyString() Option {
	return optionFunc(func(c *Convert) {
		c.primaryKeyType = primaryKeyType(primaryKeyString)
	})
}
func PrimaryKeyInt() Option {
	return optionFunc(func(c *Convert) {
		c.primaryKeyType = primaryKeyType(primaryKeyInt)
	})
}
func PrimaryKeyUint() Option {
	return optionFunc(func(c *Convert) {
		c.primaryKeyType = primaryKeyType(primaryKeyUint)
	})
}
func PrimaryKeyCustom(typ interface{}) Option {
	return optionFunc(func(c *Convert) {
		c.primaryKeyType = primaryKeyType(typ)
	})
}

var _ plugin.ConfigMutator = &Convert{}

func copyConfig(cfg config.Config) *config.Config {
	return &cfg
}
