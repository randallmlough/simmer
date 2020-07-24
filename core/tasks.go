package core

import (
	"fmt"
	"github.com/pkg/errors"
	"github.com/randallmlough/simmer/importers"
	"path/filepath"
)

type Task interface {
	Name() string
	Run(schema *Schema) error
}

func Runner(config *Config, tasks ...Task) error {
	s, err := New(config)
	if err != nil {
		return err
	}

	for _, plugin := range tasks {
		if config.Verbose {
			fmt.Printf("Running task: %s\n", plugin.Name())
		}
		if err := plugin.Run(s); err != nil {
			fmt.Printf("Task %s failed\n", plugin.Name())
			return err
		}
	}
	if config.Verbose {
		fmt.Println("All tasks completed successfully")
	}
	return nil
}

type Options struct {
	Name              string   `json:"name" yaml:"name"`
	Debug             bool     `json:"debug,omitempty" yaml:"debug,omitempty"`
	OutFolder         string   `json:"out_folder,omitempty" yaml:"output,omitempty"`
	PkgName           string   `json:"pkgname,omitempty" yaml:"pkgname,omitempty"`
	PluralFileNames   bool     `json:"plural_file_names" yaml:"plural_file_names"`
	NoTests           bool     `json:"no_tests,omitempty" yaml:"no_tests,omitempty"`
	Tags              []string `json:"tags,omitempty" yaml:"tags,omitempty"`
	Replacements      []string `json:"replacements,omitempty" yaml:"replacements,omitempty"`
	AddSoftDeletes    bool     `json:"add_soft_deletes,omitempty" yaml:"add_soft_deletes,omitempty"`
	NoRowsAffected    bool     `json:"no_rows_affected,omitempty" yaml:"no_rows_affected,omitempty"`
	NoHooks           bool     `json:"no_hooks,omitempty" yaml:"no_hooks,omitempty"`
	NoAutoTimestamps  bool     `json:"no_auto_timestamps,omitempty" yaml:"no_auto_timestamps,omitempty"`
	Wipe              bool     `json:"wipe,omitempty" yaml:"wipe,omitempty"`
	NoGeneratedHeader bool     `json:"no_generated_header,omitempty" yaml:"no_generated_header,omitempty"`

	TemplateDirs []string             `json:"template_dirs" yaml:"template_dirs"`
	Imports      importers.Collection `json:"imports" yaml:"imports"`

	StructTagCasing string   `json:"struct_tag_casing" yaml:"struct_tag_casing"`
	RelationTag     string   `json:"relation_tag" yaml:"relation_tag"`
	TagIgnore       []string `json:"tag_ignore" yaml:"tag_ignore"`
}

func (o *Options) Init(defaultOptions func() Options) error {
	if defaultOptions == nil {
		if err := o.validate(); err != nil {
			return errors.Wrap(err, "options failed validation")
		}
		return nil
	}
	options := mergeOptions(*o, defaultOptions())
	if err := options.validate(); err != nil {
		return errors.Wrap(err, "options failed validation")
	}
	*o = options

	return nil
}

func mergeOptions(src, defaultOptions Options) Options {
	return Options{
		Name:              stringFallback(src.Name, defaultOptions.Name),
		Debug:             boolFallback(src.Debug, defaultOptions.Debug),
		OutFolder:         stringFallback(src.OutFolder, defaultOptions.OutFolder),
		PkgName:           stringFallback(src.PkgName, defaultOptions.PkgName),
		PluralFileNames:   boolFallback(src.PluralFileNames, defaultOptions.PluralFileNames),
		NoTests:           boolFallback(src.NoTests, defaultOptions.NoTests),
		Tags:              sliceFallback(src.Tags, defaultOptions.Tags),
		Replacements:      sliceFallback(src.Replacements, defaultOptions.Replacements),
		AddSoftDeletes:    boolFallback(src.AddSoftDeletes, defaultOptions.AddSoftDeletes),
		NoRowsAffected:    boolFallback(src.NoRowsAffected, defaultOptions.NoRowsAffected),
		NoHooks:           boolFallback(src.NoHooks, defaultOptions.NoHooks),
		NoAutoTimestamps:  boolFallback(src.NoAutoTimestamps, defaultOptions.NoAutoTimestamps),
		Wipe:              boolFallback(src.Wipe, defaultOptions.Wipe),
		NoGeneratedHeader: boolFallback(src.NoGeneratedHeader, defaultOptions.NoGeneratedHeader),
		TemplateDirs:      sliceFallback(src.TemplateDirs, defaultOptions.TemplateDirs),
		StructTagCasing:   stringFallback(src.StructTagCasing, defaultOptions.StructTagCasing),
		RelationTag:       stringFallback(src.RelationTag, defaultOptions.RelationTag),
		TagIgnore:         sliceFallback(src.TagIgnore, defaultOptions.TagIgnore),
	}
}

func (o *Options) validate() error {
	if o.Name == "" {
		return errors.New("name is required")
	}

	if o.OutFolder == "" {
		o.OutFolder = o.Name
	}

	if o.PkgName == "" {
		o.PkgName = filepath.Base(o.OutFolder)
	}

	return nil
}

func stringFallback(value, fallbackValue string) string {
	if isZero(value) {
		return fallbackValue
	}
	return value
}
func sliceFallback(value, fallbackValue []string) []string {
	if isZero(value) {
		return fallbackValue
	}
	return value
}
func boolFallback(value, fallbackValue bool) bool {
	if isZero(value) {
		return fallbackValue
	}
	return value
}
func isZero(t interface{}) bool {
	switch v := t.(type) {
	case string:
		return v == ""
	case bool:
		return v == false
	case []string:
		return v == nil
	default:
		return true
	}
}

func (o *Options) ConfigureImports(defaultImport func() importers.Collection) importers.Collection {
	var imports importers.Collection
	if defaultImport != nil {
		imports = defaultImport()
	}
	if o.Imports.All.Standard != nil {
		imports.All.Standard = o.Imports.All.Standard
	}
	if o.Imports.All.ThirdParty != nil {
		imports.All.ThirdParty = o.Imports.All.ThirdParty
	}
	if o.Imports.Test.Standard != nil {
		imports.Test.Standard = o.Imports.Test.Standard
	}
	if o.Imports.Test.ThirdParty != nil {
		imports.Test.ThirdParty = o.Imports.Test.ThirdParty
	}
	if o.Imports.Singleton != nil {
		imports.Singleton = o.Imports.Singleton
	}
	if o.Imports.TestSingleton != nil {
		imports.TestSingleton = o.Imports.TestSingleton
	}
	if o.Imports.BasedOnType != nil {
		imports.BasedOnType = o.Imports.BasedOnType
	}

	return imports
}

type Tasks []Task

func (tt *Tasks) AddTask(task Task, override bool) error {
	if len(*tt) == 0 {
		tt.Append(task)
		return nil
	}
	for _, t := range *tt {
		if t.Name() == task.Name() {
			if !override {
				return errors.New("task already exists")
			}
			t = task
		} else {
			tt.Append(task)
		}
	}
	return nil
}

func (tt *Tasks) Append(task Task) {
	*tt = append(*tt, task)
}
