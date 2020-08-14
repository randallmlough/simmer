package core

import (
	"encoding/json"
	"fmt"
	"github.com/pkg/errors"
	"github.com/randallmlough/simmer/data"
	"github.com/randallmlough/simmer/schema"
	"github.com/volatiletech/strmangle"
	"path/filepath"
	"strings"
)

// New creates a new state based off of the config
func New(cfg *Config) (*Simmer, error) {
	s := &Simmer{
		Config: cfg,
		models: make(map[string]*Model),
	}

	models, err := data.New(
		data.Options{
			DBConfig: cfg.DBConfig,
		},
	)
	if err != nil {
		return nil, err
	}
	s.Data = models

	schema, err := schema.New(cfg.Schema)
	if err != nil {
		return nil, err
	}
	s.Schema = schema
	defer func() {
		if s.Config.Debug {
			debugOut := struct {
				Config *Config    `json:"config"`
				Data   *data.Data `json:"data"`
			}{
				Config: s.Config,
				Data:   models,
			}

			b, err := json.Marshal(debugOut)
			if err != nil {
				panic(err)
			}
			fmt.Printf("%s\n", b)
		}
	}()

	s.makeModels()
	return s, nil
}

// Simmer holds the global data needed by most pieces to run
type Simmer struct {
	Config  *Config
	Data    *data.Data
	Schema  *schema.Schema
	Model   *Model
	models  map[string]*Model
	Options interface{}
}

func (s *Simmer) Init(options *Options) error {

	if err := options.validate(); err != nil {
		return errors.Wrap(err, "options failed validation")
	}

	s.Options = options
	return nil
}

func (s *Simmer) Models() []*Model {
	models := make([]*Model, 0, len(s.models))
	for _, model := range s.models {
		models = append(models, model)
	}
	return models
}

func (s *Simmer) makeModels() {

	for _, table := range s.Data.Tables {
		name := normalizeModelName(table.Name)
		if model, ok := s.models[name]; ok {
			model.Table = table
		} else {
			s.models[name] = &Model{
				Name:  name,
				Table: table,
			}
		}

	}
	for _, typ := range s.Schema.Types {
		if obj := typ.Type; obj != nil {
			name := normalizeModelName(obj.Name)
			if model, ok := s.models[name]; ok {
				model.Schema = typ
			} else {
				s.models[name] = &Model{
					Name:   name,
					Schema: typ,
				}
			}
		}
	}
}

func normalizeModelName(name string) string {
	name = strmangle.Singular(name)
	name = strings.ToLower(name)
	return name
}

// Cleanup closes any resources that must be closed
func (s *Simmer) Cleanup() error {
	// Nothing here atm, used to close the driver
	return nil
}

// OutputDirDepth returns depth of output directory
func OutputDirDepth(outFolder string) int {
	d := filepath.ToSlash(filepath.Clean(outFolder))
	if d == "." {
		return 0
	}

	return strings.Count(d, "/") + 1
}
