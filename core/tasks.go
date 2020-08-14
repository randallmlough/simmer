package core

import (
	"fmt"
	"github.com/pkg/errors"
	"github.com/randallmlough/simmer/importers"
	"github.com/volatiletech/strmangle"
	"path/filepath"
	"regexp"
)

var (
	// Tags must be in a format like: json, xml, etc.
	rgxValidTag = regexp.MustCompile(`[a-zA-Z_\.]+`)
)

type Task interface {
	Name() string
	Run(schema *Simmer) error
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
	Name              string `json:"name" yaml:"name"`
	Debug             bool   `json:"debug,omitempty" yaml:"debug,omitempty"`
	OutFolder         string `json:"out_folder,omitempty" yaml:"output,omitempty"`
	PkgName           string `json:"pkgname,omitempty" yaml:"pkgname,omitempty"`
	PluralFileNames   bool   `json:"plural_file_names" yaml:"plural_file_names"`
	NoTests           bool   `json:"no_tests,omitempty" yaml:"no_tests,omitempty"`
	Wipe              bool   `json:"wipe,omitempty" yaml:"wipe,omitempty"`
	NoGeneratedHeader bool   `json:"no_generated_header,omitempty" yaml:"no_generated_header,omitempty"`

	Tags            []string `json:"tags,omitempty" yaml:"tags,omitempty"`
	TagIgnore       []string `json:"tag_ignore" yaml:"tag_ignore"`
	StructTagCasing string   `json:"struct_tag_casing" yaml:"struct_tag_casing"`

	TemplateDirs []string             `json:"template_dirs" yaml:"template_dirs"`
	Imports      importers.Collection `json:"imports" yaml:"imports"`
	Replacements Replacements         `json:"replacements,omitempty" yaml:"replacements,omitempty"`
}

func MergeOptions(defaultOptions, newOptions Options) Options {
	return Options{
		Name:              stringFallback(newOptions.Name, defaultOptions.Name),
		Debug:             boolFallback(newOptions.Debug, defaultOptions.Debug),
		OutFolder:         stringFallback(newOptions.OutFolder, defaultOptions.OutFolder),
		PkgName:           stringFallback(newOptions.PkgName, defaultOptions.PkgName),
		PluralFileNames:   boolFallback(newOptions.PluralFileNames, defaultOptions.PluralFileNames),
		NoTests:           boolFallback(newOptions.NoTests, defaultOptions.NoTests),
		Tags:              sliceFallback(newOptions.Tags, defaultOptions.Tags),
		Wipe:              boolFallback(newOptions.Wipe, defaultOptions.Wipe),
		NoGeneratedHeader: boolFallback(newOptions.NoGeneratedHeader, defaultOptions.NoGeneratedHeader),
		TemplateDirs:      sliceFallback(newOptions.TemplateDirs, defaultOptions.TemplateDirs),
		StructTagCasing:   stringFallback(newOptions.StructTagCasing, defaultOptions.StructTagCasing),
		TagIgnore:         sliceFallback(newOptions.TagIgnore, defaultOptions.TagIgnore),
		Replacements:      MergeReplacements(defaultOptions.Replacements, newOptions.Replacements),
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

	if o.StructTagCasing == "" {
		o.StructTagCasing = "snake"
	}
	return nil
}

// initTags removes duplicate tags and validates the format
// of all user tags are simple strings without quotes: [a-zA-Z_\.]+
func (o *Options) initTags(tags []string) error {
	o.Tags = strmangle.RemoveDuplicates(o.Tags)
	for _, v := range o.Tags {
		if !rgxValidTag.MatchString(v) {
			return errors.New("Invalid tag format %q supplied, only specify name, eg: xml")
		}
	}

	return nil
}

func (o *Options) Package(name string) Replacement {
	if r, ok := o.Replacements.Package[name]; ok {
		return r
	}
	return Replacement{Value: name}
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

type Replacements struct {
	Type    map[string]Replacement `json:"type" yaml:"type"`
	Package map[string]Replacement `json:"package" yaml:"package"`
}

func MergeReplacements(a, b Replacements) Replacements {
	// merge type
	c := a
	for key, replacement := range b.Type {
		c.Type[key] = replacement
	}
	// merge package
	for key, replacement := range b.Package {
		c.Type[key] = replacement
	}
	return c
}

type Replacement struct {
	Value  string `json:"value" yaml:"value"`
	Import string `json:"import" yaml:"import"`
}

func (r Replacement) String() string {
	return r.Value
}
