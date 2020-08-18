package task

import (
	"github.com/pkg/errors"
	"github.com/randallmlough/simmer/core"
	"github.com/randallmlough/simmer/data"
	"github.com/randallmlough/simmer/importers"
	"github.com/randallmlough/simmer/templates"
	"github.com/volatiletech/strmangle"
	"regexp"
)

var (
	rgxValidTableColumn = regexp.MustCompile(`^[\w]+\.[\w]+$|^[\w]+$`)
)

func ModelsTask(p *core.Options) core.Task {

	return &Models{
		Options:           p,
		NoDriverTemplates: false,
		NoContext:         false,
		AddSoftDeletes:    false,
		NoRowsAffected:    false,
		NoHooks:           false,
		NoAutoTimestamps:  false,
		NoBackReferencing: false,
	}
}

type Models struct {
	*core.Options
	NoDriverTemplates bool
	NoContext         bool
	AddSoftDeletes    bool
	NoRowsAffected    bool
	NoHooks           bool
	NoAutoTimestamps  bool
	NoBackReferencing bool
}

func (m *Models) Name() string {
	return "models"
}

func (m *Models) Run(simmer *core.Simmer) error {

	opts := core.MergeOptions(*m.Options, defaultModelOptions())
	if err := simmer.Init(&opts); err != nil {
		return errors.Wrap(err, "failed to initialize model options")
	}

	m.Imports = m.ConfigureImports(defaultModelsImports)

	tpls, err := templates.LoadTemplates(m.TemplateDirs, m.Name())
	if err != nil {
		return errors.Wrap(err, "unable to initialize templates")
	}

	tplsFuncs := templates.TemplateFunctions
	tplsFuncs.Append(data.DataFuncs)

	if !m.NoDriverTemplates {
		driverTpls, err := simmer.Data.Driver.Templates()
		if err != nil {
			return errors.Wrap(err, "failed to retrieve driver templates")
		}
		tpls.AppendBase64Templates(driverTpls)

		driverImports, err := simmer.Data.Driver.Imports()
		if err != nil {
			return errors.Wrap(err, "failed to retrieve driver imports")
		}
		m.Imports = importers.Merge(m.Imports, driverImports)
	}

	if !m.NoContext {
		m.Imports.All.Standard = append(m.Imports.All.Standard, `"context"`)
		m.Imports.Test.Standard = append(m.Imports.Test.Standard, `"context"`)
	}

	type options struct {
		*core.Options
		TagIgnore      map[string]struct{}
		RelationTag    string
		PkgName        string
		OutputDirDepth int
		AddGlobal      bool
		AddPanic       bool
		//AddSoftDeletes    bool
		//NoContext         bool
		//NoHooks           bool
		//NoAutoTimestamps  bool
		//NoRowsAffected    bool
		NoDriverTemplates bool
		NoBackReferencing bool
		DBTypes           templates.Once
	}
	ignoreTags := make(map[string]struct{})
	for _, v := range m.TagIgnore {
		if !rgxValidTableColumn.MatchString(v) {
			return errors.New("Invalid column name %q supplied, only specify column name or table.column, eg: created_at, user.password")
		}
		ignoreTags[v] = struct{}{}
	}
	simmer.Options = options{
		Options:        m.Options,
		TagIgnore:      ignoreTags,
		RelationTag:    "-",
		OutputDirDepth: core.OutputDirDepth(m.OutFolder),
		AddGlobal:      false,
		AddPanic:       false,
		//AddSoftDeletes:    simmer.o,
		//NoContext:         simmer.o,
		//NoHooks:           simmer.o,
		//NoAutoTimestamps:  simmer.o,
		//NoRowsAffected:    simmer.o,
		NoDriverTemplates: false,
		NoBackReferencing: true,
		DBTypes:           make(templates.Once),
	}

	if err := templates.Render(templates.Options{
		ImportNamedSet:    m.Imports.Singleton,
		OutFolder:         m.OutFolder,
		NoGeneratedHeader: m.NoGeneratedHeader,
		PkgName:           m.PkgName,
		Data:              simmer,
		Templates:         tpls,
		TemplateFuncs:     tplsFuncs,
		IsSingleton:       true,
		IsTest:            false,
	}); err != nil {
		return err
	}

	if !m.NoTests {
		if err := templates.Render(templates.Options{
			ImportNamedSet:    m.Imports.TestSingleton,
			OutFolder:         m.OutFolder,
			NoGeneratedHeader: m.NoGeneratedHeader,
			PkgName:           m.PkgName,
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
		if !model.HasModel() || model.Table.IsJoinTable {
			continue
		}

		simmer.Model = model
		fname := model.Name
		if m.PluralFileNames {
			fname = strmangle.Plural(fname)
		}

		table := model.Table

		var imps importers.Set
		imps.Standard = m.Imports.All.Standard
		imps.ThirdParty = m.Imports.All.ThirdParty
		colTypes := make([]string, len(table.Columns))
		for i, ct := range table.Columns {
			colTypes[i] = ct.Type
		}

		imps = importers.AddTypeImports(imps, m.Imports.BasedOnType, colTypes)

		if err := templates.Render(templates.Options{
			Filename:          fname,
			ImportSet:         &imps,
			OutFolder:         m.OutFolder,
			NoGeneratedHeader: m.NoGeneratedHeader,
			PkgName:           m.PkgName,
			Data:              simmer,
			Templates:         tpls,
			TemplateFuncs:     tplsFuncs,
			IsTest:            false,
		}); err != nil {
			return err
		}

		if !m.NoTests {
			if err := templates.Render(templates.Options{
				Filename:          fname,
				ImportSet:         &m.Imports.Test,
				OutFolder:         m.OutFolder,
				NoGeneratedHeader: m.NoGeneratedHeader,
				PkgName:           m.PkgName,
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

func defaultModelOptions() core.Options {
	return core.Options{
		Name:              "orm",
		Debug:             false,
		PluralFileNames:   false,
		NoTests:           false,
		Tags:              nil,
		Wipe:              true,
		NoGeneratedHeader: true,
		StructTagCasing:   "snake",
		TagIgnore:         nil,
	}
}

// NewDefaultImports returns a default Imports struct.
func defaultModelsImports() importers.Collection {
	var col importers.Collection

	col.All = importers.Set{
		Standard: importers.List{
			`"database/sql"`,
			`"fmt"`,
			`"reflect"`,
			`"strings"`,
			`"sync"`,
			`"time"`,
		},
		ThirdParty: importers.List{
			`"github.com/pkg/errors"`,
			`"github.com/volatiletech/null/v8"`,
			`"github.com/randallmlough/simmer/simmer"`,
			`"github.com/randallmlough/simmer/queries"`,
			`"github.com/volatiletech/strmangle"`,
		},
	}

	col.Singleton = importers.Map{
		"boil_queries": {
			ThirdParty: importers.List{
				`"github.com/randallmlough/simmer/database"`,
				`"github.com/randallmlough/simmer/queries"`,
			},
		},
		"boil_types": {
			Standard: importers.List{
				`"strconv"`,
			},
			ThirdParty: importers.List{
				`"github.com/pkg/errors"`,
				`"github.com/randallmlough/simmer/simmer"`,
				`"github.com/volatiletech/strmangle"`,
			},
		},
	}

	col.Test = importers.Set{
		Standard: importers.List{
			`"bytes"`,
			`"reflect"`,
			`"testing"`,
		},
		ThirdParty: importers.List{
			`"github.com/randallmlough/simmer/simmer"`,
			`"github.com/randallmlough/simmer/queries"`,
			`"github.com/volatiletech/randomize"`,
			`"github.com/volatiletech/strmangle"`,
		},
	}

	col.TestSingleton = importers.Map{
		"boil_main_test": {
			Standard: importers.List{
				`"database/sql"`,
				`"flag"`,
				`"fmt"`,
				`"math/rand"`,
				`"os"`,
				`"path/filepath"`,
				`"strings"`,
				`"testing"`,
				`"time"`,
			},
			ThirdParty: importers.List{
				`"github.com/spf13/viper"`,
				`"github.com/randallmlough/simmer/simmer"`,
			},
		},
		"boil_queries_test": {
			Standard: importers.List{
				`"bytes"`,
				`"fmt"`,
				`"io"`,
				`"io/ioutil"`,
				`"math/rand"`,
				`"regexp"`,
			},
			ThirdParty: importers.List{
				`"github.com/randallmlough/simmer/simmer"`,
			},
		},
		"boil_suites_test": {
			Standard: importers.List{
				`"testing"`,
			},
		},
	}

	return col
}
