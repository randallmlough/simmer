package core

import (
	"github.com/randallmlough/simmer/database"
)

type Config struct {
	DBConfig   *database.Config `json:"database" yaml:"database"`
	Migrations string
	Schema     string

	//Models     *Options            `json:"models,omitempty" yaml:"models,omitempty"`
	//Repository *Options            `json:"repository,omitempty" yaml:"repository,omitempty"`
	Tasks map[string]*Options `json:"tasks" yaml:"tasks"`

	Debug bool `toml:"debug,omitempty" json:"debug,omitempty" yaml:"debug,omitempty"`

	NoEditDisclaimer []byte
	Verbose          bool   `json:"verbose" yaml:"verbose"`
	Version          string `toml:"-" json:"-" yaml:"-"`
}
