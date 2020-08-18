package convert

import (
	"fmt"
	"github.com/randallmlough/modelgen"
	"github.com/randallmlough/modelgen/model"
	"github.com/randallmlough/modelgen/utils"
	"go/types"
	"path"
	"reflect"
	"regexp"
	"sort"
	"strings"

	"github.com/99designs/gqlgen/codegen/config"
	"github.com/99designs/gqlgen/codegen/templates"
	"github.com/iancoleman/strcase"
	. "github.com/logrusorgru/aurora"
	"github.com/vektah/gqlparser/v2/ast"
	"github.com/web-ridge/go-pluralize"
)

var pathRegex *regexp.Regexp
var pluralizer *pluralize.Client

func init() {
	var initError error
	pluralizer = pluralize.NewClient()
	pathRegex, initError = regexp.Compile(`src\/(.*)`)
	if initError != nil {
		fmt.Println("could not compile the path regex")
	}
}

type Config struct {
	// Aliases between domain type and model
	// useful if you have a domain type like, Auth that connects to a User model
	Aliases map[string][]string
}
type Convert struct {
	output         Directory
	backend        Directory
	frontend       Directory
	rootImportPath string
	primaryKeyType reflect.Type
	Cfg            *Config
}

type Directory struct {
	Directory string
	Package   string
}

func (c *Convert) Name() string {
	return "convert-generator"
}

func (c *Convert) MutateConfig(originalCfg *config.Config) error {
	t := &Template{
		PackageName: c.output.Package,
		Backend: Directory{
			Directory: path.Join(c.rootImportPath, c.backend.Directory),
			Package:   c.backend.Package,
		},
		Frontend: Directory{
			Directory: path.Join(c.rootImportPath, c.frontend.Directory),
			Package:   c.frontend.Package,
		},
		PrimaryKey: c.primaryKeyType,
	}

	cfg := copyConfig(*originalCfg)

	fmt.Println(BrightGreen("[convert]"), " get boiler models")
	boilerModels := model.GetModels(c.backend.Directory)

	fmt.Println(BrightGreen("[convert]"), " get extra's from schema")
	interfaces, enums, scalars := getExtrasFromSchema(cfg.Schema)

	fmt.Println(BrightGreen("[convert]"), " get model with information")
	models := c.GetModelsWithInformation(enums, originalCfg, boilerModels)

	t.Models = models
	t.HasStringPrimaryIDs = HasStringPrimaryIDsInModels(models)
	t.Interfaces = interfaces
	t.Enums = enums
	t.Scalars = scalars
	if len(t.Models) == 0 {
		fmt.Println(Red("No models found in graphql so skipping generation").Bold())
		return nil
	}

	fmt.Println(BrightGreen("[convert]"), " render preload.gotpl")
	templates.CurrentImports = nil
	if renderError := c.generatePreloadFile(cfg, t); renderError != nil {
		fmt.Println(BrightRed("renderError"), renderError)
	}
	templates.CurrentImports = nil
	fmt.Println(BrightGreen("[convert]"), " render convert.gotpl")
	if renderError := c.generateConvertFile(cfg, t); renderError != nil {
		fmt.Println(BrightRed("renderError"), renderError)
	}

	templates.CurrentImports = nil
	fmt.Println(BrightGreen("[convert]"), " render convert_input.gotpl")
	if renderError := c.generateConvertInputFile(cfg, t); renderError != nil {
		fmt.Println(BrightRed("renderError"), renderError)
	}

	// TODO: FIX FILTER
	//templates.CurrentImports = nil
	//fmt.Println(BrightGreen("[convert]"), " render filter.gotpl")
	//if renderError := m.generateFilterFile(cfg, t); renderError != nil {
	//	fmt.Println(BrightRed("renderError"), renderError)
	//}

	templates.CurrentImports = nil
	fmt.Println(BrightGreen("[convert]"), " generating ID file")
	if renderError := c.generateIDFile(cfg, t); renderError != nil {
		fmt.Println(BrightRed("renderError"), renderError)
	}
	return nil
}

func getExtrasFromSchema(schema *ast.Schema) (interfaces []*Interface, enums []*Enum, scalars []*Scalar) {
	for _, schemaType := range schema.Types {
		switch schemaType.Kind {
		case ast.Interface, ast.Union:
			interfaces = append(interfaces, &Interface{
				Description: schemaType.Description,
				Name:        schemaType.Name,
			})
		case ast.Enum:
			it := &Enum{
				Name: schemaType.Name,

				Description: schemaType.Description,
			}
			for _, v := range schemaType.EnumValues {
				it.Values = append(it.Values, &EnumValue{
					Name:        v.Name,
					NameLower:   strcase.ToLowerCamel(strings.ToLower(v.Name)),
					Description: v.Description,
				})
			}
			if strings.HasPrefix(it.Name, "_") {
				continue
			}
			enums = append(enums, it)
		case ast.Scalar:
			it := &Scalar{
				IsCustom:    scalarIsCustom(schemaType.Name),
				Name:        schemaType.Name,
				Description: schemaType.Description,
			}
			if strings.HasPrefix(it.Name, "_") {
				continue
			}
			scalars = append(scalars, it)
		}
	}
	return
}
func scalarIsCustom(scalar string) bool {
	switch scalar {
	case "Float", "Int", "Any", "Boolean", "String", "Time", "Map", "Upload", "ID":
		return false
	}
	return true
}

func (c *Convert) generatePreloadFile(cfg *config.Config, data *Template) error {
	if err := templates.Render(templates.Options{
		Template:        utils.GetTemplate("preload.gotpl"),
		PackageName:     c.output.Package,
		Filename:        c.output.Directory + "/" + "preload.go",
		Data:            data,
		GeneratedHeader: false,
		Packages:        cfg.Packages,
	}); err != nil {
		return fmt.Errorf("failed to render ID file %w", err)
	}
	return nil
}
func (c *Convert) generateConvertFile(cfg *config.Config, data *Template) error {
	if err := templates.Render(templates.Options{
		Template:        utils.GetTemplate("convert.gotpl"),
		PackageName:     c.output.Package,
		Filename:        c.output.Directory + "/" + "convert.go",
		Data:            data,
		GeneratedHeader: false,
		Packages:        cfg.Packages,
	}); err != nil {
		return fmt.Errorf("failed to render ID file %w", err)
	}
	return nil
}
func (c *Convert) generateConvertInputFile(cfg *config.Config, data *Template) error {
	if err := templates.Render(templates.Options{
		Template:        utils.GetTemplate("convert_input.gotpl"),
		PackageName:     c.output.Package,
		Filename:        c.output.Directory + "/" + "convert_input.go",
		Data:            data,
		GeneratedHeader: false,
		Packages:        cfg.Packages,
	}); err != nil {
		return fmt.Errorf("failed to render ID file %w", err)
	}
	return nil
}
func (c *Convert) generateFilterFile(cfg *config.Config, data *Template) error {
	if err := templates.Render(templates.Options{
		Template:        utils.GetTemplate("filter.gotpl"),
		PackageName:     c.output.Package,
		Filename:        c.output.Directory + "/" + "filter.go",
		Data:            data,
		GeneratedHeader: false,
		Packages:        cfg.Packages,
	}); err != nil {
		return fmt.Errorf("failed to generate filter file %w", err)
	}
	return nil
}

func (c *Convert) generateIDFile(cfg *config.Config, data *Template) error {
	if err := templates.Render(templates.Options{
		Template:        utils.GetTemplate("id.gotpl"),
		PackageName:     c.output.Package,
		Filename:        c.output.Directory + "/" + "id.go",
		Data:            data,
		GeneratedHeader: false,
		Funcs:           modelgen.FuncMap,
		Packages:        cfg.Packages,
	}); err != nil {
		return fmt.Errorf("failed to generate ID file %w", err)
	}
	return nil
}

type Template struct {
	Backend             Directory
	Frontend            Directory
	HasStringPrimaryIDs bool
	PackageName         string
	Interfaces          []*Interface
	Models              []*Model
	Enums               []*Enum
	Scalars             []*Scalar
	PrimaryKey          reflect.Type
}

type Interface struct {
	Description string
	Name        string
}

type Preload struct {
	Key           string
	ColumnSetting ColumnSetting
}

type Model struct {
	Name                  string
	PluralName            string
	BoilerModel           model.Model
	PrimaryKeyType        string
	Fields                []*Field
	IsNormal              bool
	IsInput               bool
	IsCreateInput         bool
	IsUpdateInput         bool
	IsNormalInput         bool
	IsPayload             bool
	IsWhere               bool
	IsFilter              bool
	IsPreloadable         bool
	PreloadArray          []Preload
	HasOrganizationID     bool
	HasUserOrganizationID bool
	HasUserID             bool
	HasStringPrimaryID    bool
	// other stuff
	Description string
	PureFields  []*ast.FieldDefinition
	Implements  []string
}

type ColumnSetting struct {
	Name                  string
	RelationshipModelName string
	IDAvailable           bool
}

type Field struct {
	Name               string
	PluralName         string
	Type               string
	TypeWithoutPointer string
	IsNumberID         bool
	IsPrimaryNumberID  bool
	IsPrimaryID        bool
	IsRequired         bool
	IsPlural           bool
	ConvertConfig      ConvertConfig
	// relation stuff
	IsRelation bool
	// boiler relation stuff is inside this field
	BoilerField model.Field
	// graphql relation ship can be found here
	Relationship *Model
	IsOr         bool
	IsAnd        bool

	// Some stuff
	Description  string
	OriginalType types.Type
	Tag          string
}

type Enum struct {
	Description string
	Name        string

	Values []*EnumValue
}
type Scalar struct {
	IsCustom    bool
	Description string
	Name        string
}
type EnumValue struct {
	Description string
	Name        string
	NameLower   string
}

func (c *Convert) GetModelsWithInformation(enums []*Enum, cfg *config.Config, boilerModels []*model.Model) []*Model {

	// get models based on the schema and sqlboiler structs
	models := c.getModelsFromSchema(cfg.Schema, boilerModels)

	// Now we have all model's let enhance them with fields
	enhanceModelsWithFields(enums, cfg.Schema, cfg, models)

	// Add preload maps
	enhanceModelsWithPreloadArray(models)

	// Sort in same order
	sort.Slice(models, func(i, j int) bool { return models[i].Name < models[j].Name })
	for _, m := range models {
		cfg.Models.Add(m.Name, cfg.Model.ImportPath()+"."+templates.ToGo(m.Name))
	}
	return models
}

func HasStringPrimaryIDsInModels(models []*Model) bool {
	for _, model := range models {
		if model.HasStringPrimaryID {
			return true
		}
	}
	return false
}

// getFieldType check's if user has defined a
func getFieldType(binder *config.Binder, schema *ast.Schema, cfg *config.Config, field *ast.FieldDefinition) (types.Type, error) {
	var typ types.Type
	var err error

	fieldDef := schema.Types[field.Type.Name()]
	if cfg.Models.UserDefined(field.Type.Name()) {
		typ, err = binder.FindTypeFromName(cfg.Models[field.Type.Name()].Model[0])
		if err != nil {
			return typ, err
		}
	} else {
		switch fieldDef.Kind {
		case ast.Scalar:
			// no user defined model, referencing a default scalar
			typ = types.NewNamed(
				types.NewTypeName(0, cfg.Model.Pkg(), "string", nil),
				nil,
				nil,
			)

		case ast.Interface, ast.Union:
			// no user defined model, referencing a generated interface type
			typ = types.NewNamed(
				types.NewTypeName(0, cfg.Model.Pkg(), templates.ToGo(field.Type.Name()), nil),
				types.NewInterfaceType([]*types.Func{}, []types.Type{}),
				nil,
			)

		case ast.Enum:
			// no user defined model, must reference a generated enum
			typ = types.NewNamed(
				types.NewTypeName(0, cfg.Model.Pkg(), templates.ToGo(field.Type.Name()), nil),
				nil,
				nil,
			)

		case ast.Object, ast.InputObject:
			// no user defined model, must reference a generated struct
			typ = types.NewNamed(
				types.NewTypeName(0, cfg.Model.Pkg(), templates.ToGo(field.Type.Name()), nil),
				types.NewStruct(nil, nil),
				nil,
			)

		default:
			panic(fmt.Errorf("unknown ast type %s", fieldDef.Kind))
		}
	}

	return typ, err
}

func getPlularBoilerRelationShipName(modelName string) string {
	// sqlboiler adds Slice when multiple, we don't want that
	// since our converts are named plular of model and not Slice
	// e.g. UsersToDomain and not UserSliceToDomain
	modelName = strings.TrimSuffix(modelName, "Slice")
	return pluralizer.Plural(modelName)
}

func enhanceModelsWithFields(enums []*Enum, schema *ast.Schema, cfg *config.Config, models []*Model) {

	binder := cfg.NewBinder()

	// Run the basic of the fields
	for _, m := range models {
		// Let's convert the pure ast fields to something usable for our template
		for _, field := range m.PureFields {
			fieldDef := schema.Types[field.Type.Name()]

			// This calls some qglgen boilerType which gets the gqlgen type
			typ, err := getFieldType(binder, schema, cfg, field)
			if err != nil {
				fmt.Println("Could not get field type from graphql schema: ", err)
			}
			name := field.Name
			if nameOveride := cfg.Models[m.Name].Fields[field.Name].FieldName; nameOveride != "" {
				// TODO: map overrides to sqlboiler the other way around?
				name = nameOveride
			}

			// override type struct with qqlgen code
			typ = binder.CopyModifiersFromAst(field.Type, typ)

			if isStruct(typ) && (fieldDef.Kind == ast.Object || fieldDef.Kind == ast.InputObject) {
				typ = types.NewPointer(typ)
			}
			// get golang friendly fieldName because we want to check if boiler name is available
			golangName := getGoFieldName(name)

			// generate some booleans because these checks will be used a lot
			isRelation := fieldDef.Kind == ast.Object || fieldDef.Kind == ast.InputObject

			shortType := getShortType(typ.String())

			isPrimaryID := golangName == "ID"

			// get sqlboiler information of the field
			boilerField := findBoilerFieldOrForeignKey(m.BoilerModel.Fields, golangName, isRelation)
			isString := strings.Contains(strings.ToLower(boilerField.Type), "string")
			isNumberID := strings.Contains(golangName, "ID") && !isString
			isPrimaryNumberID := isPrimaryID && !isString

			isPrimaryStringID := isPrimaryID && isString
			// enable simpler code in resolvers

			if isPrimaryStringID {
				m.HasStringPrimaryID = isPrimaryStringID
			}
			if isPrimaryNumberID || isPrimaryStringID {
				m.PrimaryKeyType = boilerField.Type
			}

			// log some warnings when fields could not be converted
			if boilerField.Type == "" {
				// TODO: add filter + where here
				if m.IsPayload {
					// ignore
				} else if pluralizer.IsPlural(name) {
					// ignore
				} else if (m.IsFilter || m.IsWhere) && (name == "and" || name == "or" || name == "search" ||
					name == "where") {
					// ignore
				} else {
					fmt.Println("[WARN] boiler type not available for ", name)
				}
			}

			if boilerField.Name == "" {
				if m.IsPayload || m.IsFilter || m.IsWhere {
				} else {
					fmt.Println("[WARN] boiler name not available for ", m.Name+"."+golangName)
					continue
				}

			}
			field := &Field{
				Name:               name,
				Type:               shortType,
				TypeWithoutPointer: strings.Replace(strings.TrimPrefix(shortType, "*"), ".", "Dot", -1),
				BoilerField:        boilerField,
				IsNumberID:         isNumberID,
				IsPrimaryID:        isPrimaryID,
				IsPrimaryNumberID:  isPrimaryNumberID,
				IsRelation:         isRelation,
				IsOr:               name == "or",
				IsAnd:              name == "and",
				IsPlural:           pluralizer.IsPlural(name),
				PluralName:         pluralizer.Plural(name),
				OriginalType:       typ,
				Description:        field.Description,
				Tag:                `json:"` + field.Name + `"`,
			}
			field.ConvertConfig = getConvertConfig(enums, m, field)
			m.Fields = append(m.Fields, field)

		}
	}

	for _, m := range models {
		m.HasOrganizationID = findField(m.Fields, "organizationId") != nil
		m.HasUserOrganizationID = findField(m.Fields, "userOrganizationId") != nil
		m.HasUserID = findField(m.Fields, "userId") != nil
		for _, f := range m.Fields {
			f.Relationship = findModel(models, f.BoilerField.Relationship.Name)
		}
	}
}

var ignoreTypePrefixes = []string{"graphql_models", "models", "gqlutils"}

func getShortType(longType string) string {

	// longType e.g = gitlab.com/decicify/app/backend/graphql_models.FlowWhere
	splittedBySlash := strings.Split(longType, "/")
	// gitlab.com, decicify, app, backend, graphql_models.FlowWhere

	lastPart := splittedBySlash[len(splittedBySlash)-1]
	isPointer := strings.HasPrefix(longType, "*")
	isStructInPackage := strings.Count(lastPart, ".") > 0

	if isStructInPackage {
		// if packages are deeper they don't have pointers but *time.Time will since it's not deep
		returnType := strings.TrimPrefix(lastPart, "*")
		for _, ignoreType := range ignoreTypePrefixes {
			fullIgnoreType := ignoreType + "."
			returnType = strings.TrimPrefix(returnType, fullIgnoreType)
		}

		if isPointer {
			return "*" + returnType
		}
		return returnType
	}

	return longType
}

func findModel(models []*Model, search string) *Model {
	for _, m := range models {
		if m.Name == search {
			return m
		}
	}
	return nil
}

func findField(fields []*Field, search string) *Field {
	for _, f := range fields {
		if f.Name == search {
			return f
		}
	}
	return nil
}
func findRelationModelForForeignKeyAndInput(currentModelName string, foreignKey string, models []*Model) *Field {
	return findRelationModelForForeignKey(getBaseModelFromName(currentModelName), foreignKey, models)
}

func findRelationModelForForeignKey(currentModelName string, foreignKey string, models []*Model) *Field {

	model := findModel(models, currentModelName)
	if model != nil {
		// Use case
		// we want a foreignKey of ParentID but the foreign key resolves to Calamity
		// We could know this based on the boilerType information
		// withou this function the generated convert is like this

		// r.Parent = ParentToDomain(m.R.Parent, m)
		// but it needs to be
		// r.Parent = CalamityToDomain(m.R.Parent, m)
		foreignKey = strings.TrimSuffix(foreignKey, "Id")

		field := findField(model.Fields, foreignKey)
		if field != nil {
			// fmt.Println("Found graph type", field.Name, "for foreign key", foreignKey)
			return field
		}
	}

	return nil
}

func findBoilerFieldOrForeignKey(fields []*model.Field, golangGraphQLName string, isRelation bool) model.Field {
	// get database friendly struct for this model
	for _, field := range fields {
		if isRelation {
			// If it a relation check to see if a foreign key is available
			if field.Name == golangGraphQLName+"ID" {
				return *field
			}
		}
		if field.Name == golangGraphQLName {
			return *field
		}
	}

	// // fallback on foreignKey

	// }

	// fmt.Println("???", golangGraphQLName)

	return model.Field{}
}

func getGoFieldName(name string) string {
	goFieldName := strcase.ToCamel(name)
	// in golang Id = ID
	goFieldName = strings.Replace(goFieldName, "Id", "ID", -1)
	// in golang Url = URL
	goFieldName = strings.Replace(goFieldName, "Url", "URL", -1)
	return goFieldName
}

func (c *Convert) getModelsFromSchema(schema *ast.Schema, boilerModels []*model.Model) (models []*Model) {
	for _, schemaType := range schema.Types {

		// skip boiler plate from ggqlgen, we only want the models
		if strings.HasPrefix(schemaType.Name, "_") {
			continue
		}

		// if cfg.Models.UserDefined(schemaType.Name) {
		// 	fmt.Println("continue")
		// 	continue
		// }

		switch schemaType.Kind {

		case ast.Object, ast.InputObject:
			{
				if schemaType == schema.Query ||
					schemaType == schema.Mutation ||
					schemaType == schema.Subscription {
					continue
				}
				modelName := schemaType.Name

				// fmt.Println("GRAPHQL MODEL ::::", m.Name)
				if strings.HasPrefix(modelName, "_") {
					continue
				}

				isInput := strings.HasSuffix(modelName, "Input") && modelName != "Input"
				isCreateInput := strings.HasSuffix(modelName, "CreateInput") && modelName != "CreateInput"
				isUpdateInput := strings.HasSuffix(modelName, "UpdateInput") && modelName != "UpdateInput"
				isFilter := strings.HasSuffix(modelName, "Filter") && modelName != "Filter"
				isWhere := strings.HasSuffix(modelName, "Where") && modelName != "Where"
				isPayload := strings.HasSuffix(modelName, "Payload") && modelName != "Payload"

				// We will try to find a corresponding boiler struct
				boilerModel := c.FindBoilerModel(boilerModels, getBaseModelFromName(modelName))

				// if no boiler model is found
				if boilerModel.Name == "" {
					if isInput || isWhere || isFilter || isPayload {
						// silent continue
						continue
					}

					fmt.Println(fmt.Sprintf("[WARN] Skip %v because no database model found", modelName))
					continue
				}

				isNormalInput := isInput && !isCreateInput && !isUpdateInput

				m := &Model{
					Name:          modelName,
					Description:   schemaType.Description,
					PluralName:    pluralizer.Plural(modelName),
					BoilerModel:   boilerModel,
					IsInput:       isInput,
					IsFilter:      isFilter,
					IsWhere:       isWhere,
					IsUpdateInput: isUpdateInput,
					IsCreateInput: isCreateInput,
					IsNormalInput: isNormalInput,
					IsPayload:     isPayload,
					IsNormal:      !isInput && !isWhere && !isFilter && !isPayload,
					IsPreloadable: !isInput && !isWhere && !isFilter && !isPayload,
				}

				for _, implementor := range schema.GetImplements(schemaType) {
					m.Implements = append(m.Implements, implementor.Name)
				}

				m.PureFields = append(m.PureFields, schemaType.Fields...)
				models = append(models, m)
			}
		}
	}
	return
}
func (c *Convert) FindBoilerModel(models []*model.Model, modelName string) model.Model {
	for _, m := range models {
		if c.BoilerModelMatch(m.Name, modelName) {
			return *m
		}
	}
	return model.Model{}
}

func (c *Convert) BoilerModelMatch(boilerModelName, modelName string) bool {
	if boilerModelName == modelName {
		return true
	}
	if aliases, ok := c.Cfg.Aliases[boilerModelName]; ok {
		for _, alias := range aliases {
			if alias == modelName {
				return true
			}
		}
	}
	return false
}
func getPreloadMapForModel(model *Model) map[string]ColumnSetting {
	preloadMap := map[string]ColumnSetting{}
	for _, field := range model.Fields {
		// only relations are preloadable
		if !field.IsRelation {
			continue
		}
		// var key string
		// if field.IsPlural {
		key := field.Name
		// } else {
		// 	key = field.PluralName
		// }
		name := fmt.Sprintf("models.%vRels.%v", model.Name, foreignKeyToRel(field.BoilerField.Name))
		setting := ColumnSetting{
			Name:                  name,
			IDAvailable:           !field.IsPlural,
			RelationshipModelName: field.BoilerField.Relationship.Name,
		}

		preloadMap[key] = setting
	}
	return preloadMap
}

const maximumLevelOfPreloads = 4

func enhanceModelsWithPreloadArray(models []*Model) {

	// first adding basic first level relations
	for _, model := range models {
		if !model.IsPreloadable {
			continue
		}

		modelPreloadMap := getPreloadMapForModel(model)

		sortedPreloadKeys := make([]string, 0, len(modelPreloadMap))
		for k := range modelPreloadMap {
			sortedPreloadKeys = append(sortedPreloadKeys, k)
		}
		sort.Strings(sortedPreloadKeys)

		model.PreloadArray = make([]Preload, len(sortedPreloadKeys))
		for i, k := range sortedPreloadKeys {
			columnSetting := modelPreloadMap[k]
			model.PreloadArray[i] = Preload{
				Key:           k,
				ColumnSetting: columnSetting,
			}
		}
	}
}

func enhancePreloadMapWithNestedRelations(
	fullMap map[string]map[string]ColumnSetting,
	preloadMapPerModel map[string]map[string]ColumnSetting,
	modelName string,
) {

	for key, value := range preloadMapPerModel[modelName] {

		// check if relation exist
		if value.RelationshipModelName != "" {
			nestedPreloads, ok := fullMap[value.RelationshipModelName]
			if ok {
				for nestedKey, nestedValue := range nestedPreloads {

					newKey := key + `.` + nestedKey

					if strings.Count(newKey, ".") > maximumLevelOfPreloads {
						continue
					}
					fullMap[modelName][newKey] = ColumnSetting{
						Name:                  value.Name + `+ "." +` + nestedValue.Name,
						RelationshipModelName: nestedValue.RelationshipModelName,
					}
				}
			}
		}
	}
}

// The relationship is defined in the normal model but not in the input, where etc structs
// So just find the normal model and get the relationship type :)
func getBaseModelFromName(v string) string {
	v = safeTrim(v, "CreateInput")
	v = safeTrim(v, "UpdateInput")
	v = safeTrim(v, "Input")
	v = safeTrim(v, "Payload")
	v = safeTrim(v, "Where")
	v = safeTrim(v, "Filter")
	return v
}

func safeTrim(v string, trimSuffix string) string {
	// let user still choose Payload as model names
	// not recommended but could be done theoretically :-)
	if v != trimSuffix {
		v = strings.TrimSuffix(v, trimSuffix)
	}
	return v
}

func foreignKeyToRel(v string) string {
	return strings.TrimSuffix(strcase.ToCamel(v), "ID")
}

func isStruct(t types.Type) bool {
	_, is := t.Underlying().(*types.Struct)
	return is
}

type ConvertConfig struct {
	IsCustom         bool
	IsDomainType     bool
	ToBoiler         string
	ToDomain         string
	GraphTypeAsText  string
	BoilerTypeAsText string
}

func findEnum(enums []*Enum, graphType string) *Enum {
	for _, enum := range enums {
		if enum.Name == graphType {
			return enum
		}
	}
	return nil
}

func getConvertConfig(enums []*Enum, model *Model, field *Field) (cc ConvertConfig) {
	graphType := field.Type
	boilType := field.BoilerField.Type

	if model.Name == "RegisterInput" {
		fmt.Println(field.Name, field.Type)
		//if field.Name == "name" {
		//	fmt.Println("is name")
		//	fmt.Println(field.typ)
		//}
	}
	enum := findEnum(enums, field.TypeWithoutPointer)
	if enum != nil {
		cc.IsCustom = true
		cc.ToBoiler = getToBoiler(
			getBoilerTypeAsText(boilType),
			getGraphTypeAsText(graphType),
		)

		cc.ToDomain = getToDomain(
			getBoilerTypeAsText(boilType),
			getGraphTypeAsText(graphType),
		)

	} else if graphType != boilType {
		//fmt.Printf("CUSTOM TYPE:\nBOIL:\n Name: %s typ:%s\n GRAPH:\n Name: %s typ:%s\n", field.BoilerField.Name, boilType, field.Name, graphType)
		cc.IsCustom = true

		if field.IsPrimaryNumberID || field.IsNumberID {

			cc.ToDomain = "VALUE"
			cc.ToBoiler = "VALUE"

			// first unpointer json type if is pointer
			if strings.HasPrefix(graphType, "*") {
				cc.ToBoiler = "gqlutils.PointerStringToString(VALUE)"
			}

			goToUint := getBoilerTypeAsText(boilType) + "ToUint"
			if goToUint == "IntToUint" {
				cc.ToDomain = "uint(VALUE)"
			} else if goToUint != "UintToUint" {
				cc.ToDomain = "gqlutils." + goToUint + "(VALUE)"
			}

			if field.IsPrimaryNumberID {
				cc.ToDomain = model.Name + "IDToDomain(" + cc.ToDomain + ")"
			} else if field.IsNumberID {
				cc.ToDomain = field.BoilerField.Relationship.Name + "IDToDomain(" + cc.ToDomain + ")"
			}

			isInt := strings.HasPrefix(strings.ToLower(boilType), "int") && !strings.HasPrefix(strings.ToLower(boilType), "uint")

			if strings.HasPrefix(boilType, "null") {
				cc.ToBoiler = fmt.Sprintf("gqlutils.IDToNullBoiler(%v)", cc.ToBoiler)
				if isInt {
					cc.ToBoiler = fmt.Sprintf("gqlutils.NullUintToNullInt(%v)", cc.ToBoiler)
				}

			} else {
				cc.ToBoiler = fmt.Sprintf("gqlutils.IDToBoiler(%v)", cc.ToBoiler)
				if isInt {
					cc.ToBoiler = fmt.Sprintf("int(%v)", cc.ToBoiler)
				}
			}

			cc.ToDomain = strings.Replace(cc.ToDomain, "VALUE", "m."+getGoFieldName(field.BoilerField.Name), -1)
			cc.ToBoiler = strings.Replace(cc.ToBoiler, "VALUE", "m."+getGoFieldName(field.Name), -1)

		} else {
			toBoiler := getToBoiler(getBoilerTypeAsText(boilType), getGraphTypeAsText(graphType))
			toDomain := getToDomain(getBoilerTypeAsText(boilType), getGraphTypeAsText(graphType))
			if ss := strings.Split(graphType, "."); ss[0] == "app" {
				cc.IsDomainType = true
			} else {
				toBoiler = "gqlutils." + toBoiler
				toDomain = "gqlutils." + toDomain
			}
			// Make these go-friendly for the helper/convert.go package
			cc.ToBoiler = toBoiler
			cc.ToDomain = toDomain
		}

	}
	// fmt.Println("boilType for", field.Name, ":", boilType)

	cc.GraphTypeAsText = getGraphTypeAsText(graphType)
	cc.BoilerTypeAsText = getBoilerTypeAsText(boilType)

	return
}

func getToBoiler(boilType, graphType string) string {
	return getGraphTypeAsText(graphType) + "To" + getBoilerTypeAsText(boilType)
}

func getToDomain(boilType, graphType string) string {
	return getBoilerTypeAsText(boilType) + "To" + getGraphTypeAsText(graphType)
}

func getBoilerTypeAsText(boilType string) string {

	// backward compatible missed Dot
	if strings.HasPrefix(boilType, "types.") {
		boilType = strings.TrimPrefix(boilType, "types.")
		boilType = strcase.ToCamel(boilType)
		boilType = "Types" + boilType
	}

	// if strings.HasPrefix(boilType, "null.") {
	// 	boilType = strings.TrimPrefix(boilType, "null.")
	// 	boilType = strcase.ToCamel(boilType)
	// 	boilType = "NullDot" + boilType
	// }
	boilType = strings.Replace(boilType, ".", "Dot", -1)

	return strcase.ToCamel(boilType)
}

func getGraphTypeAsText(graphType string) string {
	if strings.HasPrefix(graphType, "*") {
		graphType = strings.TrimPrefix(graphType, "*")
		graphType = strcase.ToCamel(graphType)
		graphType = "Pointer" + graphType
	}
	return strcase.ToCamel(graphType)
}
