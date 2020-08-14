package task

import (
	"github.com/pkg/errors"
	"github.com/randallmlough/simmer/core"
	"github.com/randallmlough/simmer/data"
	"github.com/randallmlough/simmer/templates"
	"github.com/volatiletech/strmangle"
	"path/filepath"
)

func NewTasks(tasks map[string]*core.Options) (core.Tasks, error) {
	t := make(core.Tasks, 0, len(tasks))
	for taskName, options := range tasks {
		if options == nil {
			options = new(core.Options)
		}
		options.Name = taskName
		if err := t.AddTask(findTaskRunner(taskName, options), false); err != nil {
			return nil, errors.Wrapf(err, "failed to add task %s", taskName)
		}
	}
	return t, nil
}

func findTaskRunner(name string, options *core.Options) core.Task {
	switch name {
	case "orm":
		return ModelsTask(options)
	default:
		return New(options)
	}
}

func New(task *core.Options) core.Task {
	return &Task{task}
}

type Task struct {
	*core.Options
}

func (t *Task) Name() string {
	return t.Options.Name
}

func (t *Task) Run(simmer *core.Simmer) error {

	opts := core.MergeOptions(defaultTaskOptions(simmer.Config.RootImportPath), *t.Options)
	if err := simmer.Init(&opts); err != nil {
		return errors.Wrap(err, "failed to initialize model options")
	}

	opts.Imports = t.ConfigureImports(nil)

	tpls, err := templates.LoadTemplates(opts.TemplateDirs, t.Name())
	if err != nil {
		return errors.Wrap(err, "unable to initialize templates")
	}

	tplsFuncs := templates.TemplateFunctions
	tplsFuncs.Append(data.DataFuncs)

	if err := templates.Render(templates.Options{
		ImportNamedSet:    opts.Imports.Singleton,
		OutFolder:         opts.OutFolder,
		NoGeneratedHeader: opts.NoGeneratedHeader,
		PkgName:           opts.PkgName,
		Data:              simmer,
		Templates:         tpls,
		TemplateFuncs:     tplsFuncs,
		IsSingleton:       true,
		IsTest:            false,
	}); err != nil {
		return err
	}

	if !t.NoTests {
		if err := templates.Render(templates.Options{
			ImportNamedSet:    opts.Imports.TestSingleton,
			OutFolder:         opts.OutFolder,
			NoGeneratedHeader: opts.NoGeneratedHeader,
			PkgName:           opts.PkgName,
			Data:              simmer,
			Templates:         tpls,
			TemplateFuncs:     tplsFuncs,
			IsSingleton:       true,
			IsTest:            true,
		}); err != nil {
			return err
		}
	}

	for _, model := range simmer.Models() {

		simmer.Model = model
		fname := model.Name
		if opts.PluralFileNames {
			fname = strmangle.Plural(fname)
		}

		imps := opts.Imports

		if err := templates.Render(templates.Options{
			Filename:          fname,
			ImportSet:         imps.All,
			OutFolder:         opts.OutFolder,
			NoGeneratedHeader: opts.NoGeneratedHeader,
			PkgName:           opts.PkgName,
			Data:              simmer,
			Templates:         tpls,
			TemplateFuncs:     tplsFuncs,
			IsTest:            false,
		}); err != nil {
			return err
		}

		if !opts.NoTests {
			if err := templates.Render(templates.Options{
				Filename:          fname,
				ImportSet:         imps.Test,
				OutFolder:         opts.OutFolder,
				NoGeneratedHeader: opts.NoGeneratedHeader,
				PkgName:           opts.PkgName,
				Data:              simmer,
				Templates:         tpls,
				TemplateFuncs:     tplsFuncs,
				IsTest:            true,
			}); err != nil {
				return err
			}
		}
	}

	return nil
}
func defaultTaskOptions(rootImportPath string) core.Options {
	return core.Options{
		Replacements: core.Replacements{
			Type: make(map[string]core.Replacement),
			Package: map[string]core.Replacement{
				"data": {
					Value:  "models",
					Import: filepath.Join(rootImportPath, "models"),
				},
				"schema": {
					Value:  "domain",
					Import: filepath.Join(rootImportPath, "domain"),
				},
			},
		},
	}
}
