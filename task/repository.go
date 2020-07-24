package task

import (
	"github.com/pkg/errors"
	"github.com/randallmlough/simmer/core"
	"github.com/randallmlough/simmer/data"
	"github.com/randallmlough/simmer/importers"
	"github.com/randallmlough/simmer/templates"
	"github.com/volatiletech/strmangle"
)

func RepositoryTask(opts *core.Options) core.Task {
	return &Repository{opts}
}

type Repository struct {
	*core.Options
}

func (r *Repository) Name() string {
	return "repository"
}

func (r *Repository) Run(schema *core.Schema) error {

	tpls, err := templates.LoadTemplates(r.TemplateDirs, r.Name())
	if err != nil {
		return errors.Wrap(err, "unable to initialize templates")
	}

	tplsFuncs := templates.TemplateFunctions
	tplsFuncs.Append(data.DataFuncs)

	r.Imports = r.ConfigureImports(defaultRepositoryImports)

	if err := templates.Render(templates.Options{
		ImportNamedSet:    r.Imports.Singleton,
		OutFolder:         r.OutFolder,
		NoGeneratedHeader: r.NoGeneratedHeader,
		PkgName:           r.PkgName,
		Data:              schema.Data,
		Templates:         tpls,
		TemplateFuncs:     tplsFuncs,
		IsSingleton:       true,
		IsTest:            false,
	}); err != nil {
		return err
	}

	if !r.NoTests {
		if err := templates.Render(templates.Options{
			ImportNamedSet:    r.Imports.TestSingleton,
			OutFolder:         r.OutFolder,
			NoGeneratedHeader: r.NoGeneratedHeader,
			PkgName:           r.PkgName,
			Data:              schema.Data,
			Templates:         tpls,
			TemplateFuncs:     tplsFuncs,
			IsSingleton:       true,
			IsTest:            true,
		}); err != nil {
			return err
		}
	}

	for _, model := range schema.Models() {

		schema.Model = model
		fname := model.Name
		if r.PluralFileNames {
			fname = strmangle.Plural(fname)
		}

		if err := templates.Render(templates.Options{
			Filename:          fname,
			ImportSet:         r.Imports.All,
			OutFolder:         r.OutFolder,
			NoGeneratedHeader: r.NoGeneratedHeader,
			PkgName:           r.PkgName,
			Data:              schema,
			Templates:         tpls,
			TemplateFuncs:     tplsFuncs,
			IsTest:            false,
		}); err != nil {
			return err
		}

		if !r.NoTests {
			if err := templates.Render(templates.Options{
				Filename:          fname,
				ImportSet:         r.Imports.Test,
				OutFolder:         r.OutFolder,
				NoGeneratedHeader: r.NoGeneratedHeader,
				PkgName:           r.PkgName,
				Data:              schema,
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

func defaultRepositoryImports() importers.Collection {
	return importers.Collection{
		All: importers.Set{
			Standard: []string{
				`"context"`,
				`"database/sql"`,
			},
			ThirdParty: []string{
				`"github.com/pkg/errors"`,
				`"github.com/raaloo/raaloo/models"`,
			},
		},
		Singleton: importers.Map{
			"db": importers.Set{
				Standard: []string{
					`"context"`,
					`"database/sql"`,
				},
				ThirdParty: []string{
					`"github.com/randallmlough/simmer/simmer"`,
					`_ "github.com/jackc/pgx/v4/stdlib"`,
				},
			},
			"queries": importers.Set{
				Standard: []string{
					`"strings"`,
				},
				ThirdParty: []string{
					`"github.com/randallmlough/simmer/queries"`,
				},
			},
			"errors": importers.Set{
				ThirdParty: []string{
					`"github.com/pkg/errors"`,
				},
			},
		},
	}
}
