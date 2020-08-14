package core

import (
	"github.com/randallmlough/simmer/database"
)

type Config struct {
	DBConfig   *database.Config `json:"database" yaml:"database"`
	Migrations string
	Tasks      map[string]*Options `json:"tasks" yaml:"tasks"`

	Debug bool `toml:"debug,omitempty" json:"debug,omitempty" yaml:"debug,omitempty"`

	NoEditDisclaimer []byte
	Verbose          bool   `json:"verbose" yaml:"verbose"`
	Version          string `toml:"-" json:"-" yaml:"-"`

	Schema         StringList `yaml:"schema,omitempty"`
	RootImportPath string     `json:"root_import_path" yaml:"root_import_path"`
}

type StringList []string

func (a *StringList) UnmarshalYAML(unmarshal func(interface{}) error) error {
	var single string
	err := unmarshal(&single)
	if err == nil {
		*a = []string{single}
		return nil
	}

	var multi []string
	err = unmarshal(&multi)
	if err != nil {
		return err
	}

	*a = multi
	return nil
}

func (a StringList) Has(file string) bool {
	for _, existing := range a {
		if existing == file {
			return true
		}
	}
	return false
}
