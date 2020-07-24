package data

import (
	"fmt"
	"github.com/pkg/errors"
	"github.com/randallmlough/simmer/database"
	"github.com/randallmlough/simmer/importers"
	"github.com/randallmlough/simmer/templates"
	"github.com/volatiletech/strmangle"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

type Data struct {
	Tables  []database.Table
	Table   database.Table
	Aliases Aliases

	// todo remove unused fields after migration
	//PkgName string
	Schema string

	// Helps tune the output
	DriverName string
	Dialect    database.Dialect
	Driver     database.Interface
	//TypeReplaces []TypeReplace

	// LQ and RQ contain a quoted quote that allows us to write
	// the templates more easily.
	LQ string
	RQ string

	// Control various generation features
	//AddGlobal        bool
	//AddPanic         bool
	//AddSoftDeletes   bool
	//NoContext        bool
	//NoHooks          bool
	//NoAutoTimestamps bool
	//NoRowsAffected   bool
	//NoDriverTemplates bool
	//NoBackReferencing bool

	// Tags control which tags are added to the struct
	//Tags []string

	// RelationTag controls the value of the tags for the Relationship struct
	//RelationTag string

	// Run struct tags as camelCase or snake_case
	//StructTagCasing string

	// Contains field names that should have tags values set to '-'
	//TagIgnore map[string]struct{}

	// OutputDirDepth is used to find sqlboiler config file
	//OutputDirDepth int

	// Hacky state for where clauses to avoid having to do type-based imports
	// for singletons
	//DBTypes templates.Once

	// StringFuncs are usable in templates with stringMap
	//StringFuncs map[string]func(string) string
}

func (d *Data) Quotes(s string) string {
	return fmt.Sprintf("%s%s%s", d.LQ, s, d.RQ)
}

func (d *Data) SchemaTable(table string) string {
	return strmangle.SchemaTable(d.LQ, d.RQ, d.Dialect.UseSchema, d.Schema, table)
}

// TypeReplace replaces a column type with something else
type TypeReplace struct {
	Tables  []string        `toml:"tables,omitempty" json:"tables,omitempty" yaml:"tables,omitempty"`
	Match   database.Column `toml:"match,omitempty" json:"match,omitempty" yaml:"match,omitempty"`
	Replace database.Column `toml:"replace,omitempty" json:"replace,omitempty" yaml:"replace,omitempty"`
	Imports importers.Set   `toml:"imports,omitempty" json:"imports,omitempty" yaml:"imports,omitempty"`
}

type Options struct {
	DBConfig           *database.Config
	DatabaseDriverName string
	Aliases            Aliases
}

func New(opts Options) (*Data, error) {

	data := new(Data)

	if opts.DBConfig == nil {
		return nil, errors.New("postgres database config required")
	}

	if err := data.initDBInfo(opts.DBConfig.ToMap()); err != nil {
		return nil, errors.Wrap(err, "failed to initialize database")
	}

	data.initAliases(opts.Aliases)
	return data, nil
}

// initDBInfo retrieves information about the database
func (d *Data) initDBInfo(pgConfig map[string]interface{}) error {
	driverName := "psql"
	driverPath := "psql"

	if strings.ContainsRune(driverName, os.PathSeparator) {
		driverName = strings.Replace(filepath.Base(driverName), "simmer-", "", 1)
		driverName = strings.Replace(driverName, ".exe", "", 1)
	} else {
		driverPath = "simmer-" + driverPath
		if p, err := exec.LookPath(driverPath); err == nil {
			driverPath = p
		}
	}

	driverPath, err := filepath.Abs(driverPath)
	if err != nil {
		return errors.Wrap(err, "could not find absolute path to driver")
	}
	if !database.DriverExists(driverName) {
		database.RegisterBinary(driverName, driverPath)
	}

	driver := database.GetDriver(driverName)

	dbInfo, err := driver.Assemble(pgConfig)
	if err != nil {
		return errors.Wrap(err, "unable to fetch table data")
	}

	if len(dbInfo.Tables) == 0 {
		return errors.New("no tables found in database")
	}

	if err := checkPKeys(dbInfo.Tables); err != nil {
		return err
	}

	d.Driver = driver
	d.Schema = dbInfo.Schema
	d.Tables = dbInfo.Tables
	d.Dialect = dbInfo.Dialect
	d.LQ = strmangle.QuoteCharacter(dbInfo.Dialect.LQ)
	d.RQ = strmangle.QuoteCharacter(dbInfo.Dialect.RQ)

	return nil
}

// checkPKeys ensures every table has a primary key column
func checkPKeys(tables []database.Table) error {
	var missingPkey []string
	for _, t := range tables {
		if t.PKey == nil {
			missingPkey = append(missingPkey, t.Name)
		}
	}

	if len(missingPkey) != 0 {
		return errors.Errorf("primary key missing in tables (%s)", strings.Join(missingPkey, ", "))
	}

	return nil
}

// mergeDriverImports calls the driver and asks for its set
// of imports, then merges it into the current configuration's
// imports.
//func (s *Data) mergeDriverImports() error {
//	drivers, err := s.Driver.Imports()
//	if err != nil {
//		return errors.Wrap(err, "failed to fetch driver's imports")
//	}
//
//	s.ConfigMap.Imports = importers.Merge(s.ConfigMap.Imports, drivers)
//	return nil
//}

// ProcessTypeReplacements checks the config for type replacements
// and performs them.
func (d *Data) ProcessTypeReplacements(typeReplaces []TypeReplace, importTypeMap importers.Map) importers.Map {
	for _, r := range typeReplaces {

		for i := range d.Tables {
			t := d.Tables[i]

			if !shouldReplaceInTable(t, r) {
				continue
			}

			for j := range t.Columns {
				c := t.Columns[j]
				if matchColumn(c, r.Match) {
					t.Columns[j] = columnMerge(c, r.Replace)

					if len(r.Imports.Standard) != 0 || len(r.Imports.ThirdParty) != 0 {
						importTypeMap[t.Columns[j].Type] = importers.Set{
							Standard:   r.Imports.Standard,
							ThirdParty: r.Imports.ThirdParty,
						}
					}
				}
			}
		}
	}

	return importTypeMap
}

func (d *Data) DriverTemplates() (map[string]templates.TemplateLoader, error) {
	driverTemplates, err := d.Driver.Templates()
	if err != nil {
		return nil, err
	}
	temps := make(map[string]templates.TemplateLoader)
	for template, contents := range driverTemplates {
		temps[templates.NormalizeSlashes(template)] = templates.Base64Loader(contents)
	}
	return temps, nil
}

func (d *Data) initAliases(aliases Aliases) {

	a := aliases
	FillAliases(&a, d.Tables)
	d.Aliases = a

}

// matchColumn checks if a column 'c' matches specifiers in 'm'.
// Anything defined in m is checked against a's values, the
// match is a done using logical and (all specifiers must match).
// Bool fields are only checked if a string type field matched first
// and if a string field matched they are always checked (must be defined).
//
// Doesn't care about Unique columns since those can vary independent of type.
func matchColumn(c, m database.Column) bool {
	matchedSomething := false

	// return true if we matched, or we don't have to match
	// if we actually matched against something, then additionally set
	// matchedSomething so we can check boolean values too.
	matches := func(matcher, value string) bool {
		if len(matcher) != 0 && matcher != value {
			return false
		}
		matchedSomething = true
		return true
	}

	if !matches(m.Name, c.Name) {
		return false
	}
	if !matches(m.Type, c.Type) {
		return false
	}
	if !matches(m.DBType, c.DBType) {
		return false
	}
	if !matches(m.UDTName, c.UDTName) {
		return false
	}
	if !matches(m.FullDBType, c.FullDBType) {
		return false
	}
	if m.ArrType != nil && (c.ArrType == nil || !matches(*m.ArrType, *c.ArrType)) {
		return false
	}
	if m.DomainName != nil && (c.DomainName == nil || !matches(*m.DomainName, *c.DomainName)) {
		return false
	}

	if !matchedSomething {
		return false
	}

	if m.AutoGenerated != c.AutoGenerated {
		return false
	}
	if m.Nullable != c.Nullable {
		return false
	}

	return true
}

// columnMerge merges values from src into dst. Bools are copied regardless
// strings are copied if they have values. Name is excluded because it doesn't make
// sense to non-programatically replace a name.
func columnMerge(dst, src database.Column) database.Column {
	ret := dst
	if len(src.Type) != 0 {
		ret.Type = src.Type
	}
	if len(src.DBType) != 0 {
		ret.DBType = src.DBType
	}
	if len(src.UDTName) != 0 {
		ret.UDTName = src.UDTName
	}
	if len(src.FullDBType) != 0 {
		ret.FullDBType = src.FullDBType
	}
	if src.ArrType != nil && len(*src.ArrType) != 0 {
		ret.ArrType = new(string)
		*ret.ArrType = *src.ArrType
	}

	return ret
}

// shouldReplaceInTable checks if tables were specified in types.match in the config.
// If tables were set, it checks if the given table is among the specified tables.
func shouldReplaceInTable(t database.Table, r TypeReplace) bool {
	if len(r.Tables) == 0 {
		return true
	}

	for _, replaceInTable := range r.Tables {
		if replaceInTable == t.Name {
			return true
		}
	}

	return false
}
