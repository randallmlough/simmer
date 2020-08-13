package task

import (
	"github.com/pkg/errors"
	"github.com/randallmlough/simmer/core"
	"github.com/randallmlough/simmer/data"
	"github.com/randallmlough/simmer/templates"
	"github.com/volatiletech/strmangle"
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

	if err := t.Init(nil); err != nil {
		return errors.Wrap(err, "failed to initialize options")
	}
	t.Imports = t.ConfigureImports(nil)

	tpls, err := templates.LoadTemplates(t.TemplateDirs, t.Name())
	if err != nil {
		return errors.Wrap(err, "unable to initialize templates")
	}

	tplsFuncs := templates.TemplateFunctions
	tplsFuncs.Append(data.DataFuncs)

	if err := templates.Render(templates.Options{
		ImportNamedSet:    t.Imports.Singleton,
		OutFolder:         t.OutFolder,
		NoGeneratedHeader: t.NoGeneratedHeader,
		PkgName:           t.PkgName,
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
			ImportNamedSet:    t.Imports.TestSingleton,
			OutFolder:         t.OutFolder,
			NoGeneratedHeader: t.NoGeneratedHeader,
			PkgName:           t.PkgName,
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
		if t.PluralFileNames {
			fname = strmangle.Plural(fname)
		}

		imps := t.Imports

		if err := templates.Render(templates.Options{
			Filename:          fname,
			ImportSet:         imps.All,
			OutFolder:         t.OutFolder,
			NoGeneratedHeader: t.NoGeneratedHeader,
			PkgName:           t.PkgName,
			Data:              simmer,
			Templates:         tpls,
			TemplateFuncs:     tplsFuncs,
			IsTest:            false,
		}); err != nil {
			return err
		}

		if !t.NoTests {
			if err := templates.Render(templates.Options{
				Filename:          fname,
				ImportSet:         imps.Test,
				OutFolder:         t.OutFolder,
				NoGeneratedHeader: t.NoGeneratedHeader,
				PkgName:           t.PkgName,
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
