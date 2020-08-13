package templates

import (
	"crypto/sha256"
	"encoding"
	"encoding/base64"
	"fmt"
	"github.com/pkg/errors"
	"github.com/randallmlough/simmer/templatebin"
	"io/ioutil"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"text/template"
	"unicode"
)

type dirExtMap map[string]map[string][]string

// groupTemplates takes templates and groups them according to their output directory
// and file extension.
func groupTemplates(templates *TemplateList) dirExtMap {
	tplNames := templates.Templates()
	dirs := make(map[string]map[string][]string)
	for _, tplName := range tplNames {
		normalized, isSingleton, _, _ := outputFilenameParts(tplName)
		if isSingleton {
			continue
		}

		dir := filepath.Dir(normalized)
		if dir == "." {
			dir = ""
		}

		extensions, ok := dirs[dir]
		if !ok {
			extensions = make(map[string][]string)
			dirs[dir] = extensions
		}

		ext := getLongExt(tplName)
		ext = strings.TrimSuffix(ext, ".tpl")
		slice := extensions[ext]
		extensions[ext] = append(slice, tplName)
	}

	return dirs
}

// FindTemplates uses a root path: (/home/user/gopath/src/../sqlboiler/)
// and a base path: /templates
// to create a bunch of file loaders of the form:
// templates/00_struct.tpl -> /absolute/path/to/that/file
// Note the missing leading slash, this is important for the --replace argument
func FindTemplates(root, base string) (map[string]TemplateLoader, error) {
	templates := make(map[string]TemplateLoader)
	rootBase := filepath.Join(root, base)
	err := filepath.Walk(rootBase, func(path string, fi os.FileInfo, err error) error {
		if fi.IsDir() {
			return nil
		}

		ext := filepath.Ext(path)
		if ext != ".tpl" {
			return nil
		}

		relative, err := filepath.Rel(root, path)
		if err != nil {
			return errors.Wrapf(err, "could not find relative path to base root: %s", rootBase)
		}

		relative = strings.TrimLeft(relative, string(os.PathSeparator))
		templates[relative] = FileLoader(path)
		return nil
	})

	if err != nil {
		return nil, err
	}

	return templates, nil
}

type TemplateList struct {
	*template.Template
}

type templateNameList []string

func (t templateNameList) Len() int {
	return len(t)
}

func (t templateNameList) Swap(k, j int) {
	t[k], t[j] = t[j], t[k]
}

func (t templateNameList) Less(k, j int) bool {
	// Make sure "struct" goes to the front
	if t[k] == "struct.tpl" {
		return true
	}

	res := strings.Compare(t[k], t[j])
	if res <= 0 {
		return true
	}

	return false
}

// Templates returns the name of all the templates defined in the template list
func (t TemplateList) Templates() []string {
	tplList := t.Template.Templates()

	if len(tplList) == 0 {
		return nil
	}

	ret := make([]string, 0, len(tplList))
	for _, tpl := range tplList {
		if name := tpl.Name(); strings.HasSuffix(name, ".tpl") {
			ret = append(ret, name)
		}
	}

	sort.Sort(templateNameList(ret))

	return ret
}

type LazyTemplates []LazyTemplate

func LoadTemplates(templateDir []string, assetPrefix string) (LazyTemplates, error) {

	tmps := make(map[string]TemplateLoader)
	if len(templateDir) != 0 {
		for _, dir := range templateDir {
			abs, err := filepath.Abs(dir)
			if err != nil {
				return nil, errors.Wrap(err, "could not find abs dir of templates directory")
			}

			base := filepath.Base(abs)
			root := filepath.Dir(abs)
			tpls, err := FindTemplates(root, base)
			if err != nil {
				return nil, err
			}

			mergeTemplates(tmps, tpls)
		}
	} else {
		for _, a := range templatebin.AssetNames() {
			if strings.HasSuffix(a, ".tpl") {
				if assetPrefix == "" || strings.HasPrefix(a, assetPrefix) {
					tmps[NormalizeSlashes(a)] = AssetLoader(a)
				}
			}
		}
	}

	// For stability, sort keys to traverse the map and turn it into a slice
	keys := make([]string, 0, len(tmps))
	for k := range tmps {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	lazyTemplates := make([]LazyTemplate, 0, len(tmps))
	for _, k := range keys {
		lazyTemplates = append(lazyTemplates, LazyTemplate{
			Name:   k,
			Loader: tmps[k],
		})
	}

	return lazyTemplates, nil
}

func (lt LazyTemplates) Replacements(replacements []string) error {
	for _, replace := range replacements {
		splits := strings.Split(replace, ";")
		if len(splits) != 2 {
			return errors.Errorf("replace parameters must have 2 arguments, given: %s", replace)
		}

		original, replacement := NormalizeSlashes(splits[0]), splits[1]

		for _, lazyTemplate := range lt {
			if lazyTemplate.Name == original {
				lazyTemplate.Loader = FileLoader(replacement)
				continue
			}
		}

		// if you get here, the template must not exist yet, therefore there's nothing to replace.
		return errors.Errorf("replace can only replace existing templates, %s does not exist", original)
	}

	return nil
}

func (lt *LazyTemplates) AppendBase64Templates(base64Templates map[string]string) {
	for template, contents := range base64Templates {

		for _, lazyTemplate := range *lt {
			if lazyTemplate.Name == template {
				lazyTemplate.Loader = Base64Loader(contents)
				continue
			}
		}
		*lt = append(*lt, LazyTemplate{
			Name:   template,
			Loader: Base64Loader(contents),
		})
	}
}

func mergeTemplates(dst, src map[string]TemplateLoader) {
	for k, v := range src {
		dst[k] = v
	}
}

func ParseTemplates(lazyTemplates []LazyTemplate, testTemplates bool, funcMap TemplateFuncs) (*TemplateList, error) {

	if funcMap == nil {
		funcMap = TemplateFunctions
	}

	tpl := template.New("")

	for _, t := range lazyTemplates {
		firstDir := strings.Split(t.Name, string(filepath.Separator))[0]
		isTest := strings.HasSuffix(firstDir, "_test")
		if testTemplates && !isTest || !testTemplates && isTest {
			continue
		}

		byt, err := t.Loader.Load()
		if err != nil {
			return nil, errors.Wrapf(err, "failed to load template: %s", t.Name)
		}

		_, err = tpl.New(t.Name).Funcs(template.FuncMap(funcMap)).Parse(string(byt))
		if err != nil {
			return nil, errors.Wrapf(err, "failed to parse template: %s", t.Name)
		}
	}

	return &TemplateList{Template: tpl}, nil
}

type LazyTemplate struct {
	Name   string         `json:"name"`
	Loader TemplateLoader `json:"loader"`
}

type TemplateLoader interface {
	encoding.TextMarshaler
	Load() ([]byte, error)
}

type TemplateLoaderMap map[string]TemplateLoader

type FileLoader string

func (f FileLoader) Load() ([]byte, error) {
	fname := string(f)
	b, err := ioutil.ReadFile(fname)
	if err != nil {
		return nil, errors.Wrapf(err, "failed to load template: %s", fname)
	}
	return b, nil
}

func (f FileLoader) MarshalText() ([]byte, error) {
	return []byte(f.String()), nil
}

func (f FileLoader) String() string {
	return "file:" + string(f)
}

type Base64Loader string

func (b Base64Loader) Load() ([]byte, error) {
	byt, err := base64.StdEncoding.DecodeString(string(b))
	if err != nil {
		return nil, errors.Wrap(err, "failed to decode driver's template, should be base64)")
	}
	return byt, nil
}

func (b Base64Loader) MarshalText() ([]byte, error) {
	return []byte(b.String()), nil
}

func (b Base64Loader) String() string {
	byt, err := base64.StdEncoding.DecodeString(string(b))
	if err != nil {
		panic("trying to debug output base64 loader, but was not proper base64!")
	}
	sha := sha256.Sum256(byt)
	return fmt.Sprintf("base64:(sha256 of content): %x", sha)
}

type AssetLoader string

func (a AssetLoader) Load() ([]byte, error) {
	return templatebin.Asset(string(a))
}

func (a AssetLoader) MarshalText() ([]byte, error) {
	return []byte(a.String()), nil
}

func (a AssetLoader) String() string {
	return "asset:" + string(a)
}

// NormalizeSlashes takes a path that was made on linux or windows and converts it
// to a native path.
func NormalizeSlashes(path string) string {
	path = strings.ReplaceAll(path, `/`, string(os.PathSeparator))
	path = strings.ReplaceAll(path, `\`, string(os.PathSeparator))
	return path
}

// DenormalizeSlashes takes any backslashes and converts them to linux style slashes
func DenormalizeSlashes(path string) string {
	path = strings.ReplaceAll(path, `\`, `/`)
	return path
}

func ToGo(name string) string {
	if name == "_" {
		return "_"
	}
	runes := make([]rune, 0, len(name))

	wordWalker(name, func(info *wordInfo) {
		word := info.Word
		if info.MatchCommonInitial {
			word = strings.ToUpper(word)
		} else if !info.HasCommonInitial {
			if strings.ToUpper(word) == word || strings.ToLower(word) == word {
				// FOO or foo → Foo
				// FOo → FOo
				word = UcFirst(strings.ToLower(word))
			}
		}
		runes = append(runes, []rune(word)...)
	})

	return string(runes)
}

func ToGoPrivate(name string) string {
	if name == "_" {
		return "_"
	}
	runes := make([]rune, 0, len(name))

	first := true
	wordWalker(name, func(info *wordInfo) {
		word := info.Word
		switch {
		case first:
			if strings.ToUpper(word) == word || strings.ToLower(word) == word {
				// ID → id, CAMEL → camel
				word = strings.ToLower(info.Word)
			} else {
				// ITicket → iTicket
				word = LcFirst(info.Word)
			}
			first = false
		case info.MatchCommonInitial:
			word = strings.ToUpper(word)
		case !info.HasCommonInitial:
			word = UcFirst(strings.ToLower(word))
		}
		runes = append(runes, []rune(word)...)
	})

	return sanitizeKeywords(string(runes))
}

type wordInfo struct {
	Word               string
	MatchCommonInitial bool
	HasCommonInitial   bool
}

// This function is based on the following code.
// https://github.com/golang/lint/blob/06c8688daad7faa9da5a0c2f163a3d14aac986ca/lint.go#L679
func wordWalker(str string, f func(*wordInfo)) {
	runes := []rune(strings.TrimFunc(str, isDelimiter))
	w, i := 0, 0 // index of start of word, scan
	hasCommonInitial := false
	for i+1 <= len(runes) {
		eow := false // whether we hit the end of a word
		switch {
		case i+1 == len(runes):
			eow = true
		case isDelimiter(runes[i+1]):
			// underscore; shift the remainder forward over any run of underscores
			eow = true
			n := 1
			for i+n+1 < len(runes) && isDelimiter(runes[i+n+1]) {
				n++
			}

			// Leave at most one underscore if the underscore is between two digits
			if i+n+1 < len(runes) && unicode.IsDigit(runes[i]) && unicode.IsDigit(runes[i+n+1]) {
				n--
			}

			copy(runes[i+1:], runes[i+n+1:])
			runes = runes[:len(runes)-n]
		case unicode.IsLower(runes[i]) && !unicode.IsLower(runes[i+1]):
			// lower->non-lower
			eow = true
		}
		i++

		// [w,i) is a word.
		word := string(runes[w:i])
		if !eow && commonInitialisms[word] && !unicode.IsLower(runes[i]) {
			// through
			// split IDFoo → ID, Foo
			// but URLs → URLs
		} else if !eow {
			if commonInitialisms[word] {
				hasCommonInitial = true
			}
			continue
		}

		matchCommonInitial := false
		if commonInitialisms[strings.ToUpper(word)] {
			hasCommonInitial = true
			matchCommonInitial = true
		}

		f(&wordInfo{
			Word:               word,
			MatchCommonInitial: matchCommonInitial,
			HasCommonInitial:   hasCommonInitial,
		})
		hasCommonInitial = false
		w = i
	}
}

var keywords = []string{
	"break",
	"default",
	"func",
	"interface",
	"select",
	"case",
	"defer",
	"go",
	"map",
	"struct",
	"chan",
	"else",
	"goto",
	"package",
	"switch",
	"const",
	"fallthrough",
	"if",
	"range",
	"type",
	"continue",
	"for",
	"import",
	"return",
	"var",
	"_",
}

// sanitizeKeywords prevents collisions with go keywords for arguments to resolver functions
func sanitizeKeywords(name string) string {
	for _, k := range keywords {
		if name == k {
			return name + "Arg"
		}
	}
	return name
}

// commonInitialisms is a set of common initialisms.
// Only add entries that are highly unlikely to be non-initialisms.
// For instance, "ID" is fine (Freudian code is rare), but "AND" is not.
var commonInitialisms = map[string]bool{
	"ACL":   true,
	"API":   true,
	"ASCII": true,
	"CPU":   true,
	"CSS":   true,
	"DNS":   true,
	"EOF":   true,
	"GUID":  true,
	"HTML":  true,
	"HTTP":  true,
	"HTTPS": true,
	"ID":    true,
	"IP":    true,
	"JSON":  true,
	"LHS":   true,
	"QPS":   true,
	"RAM":   true,
	"RHS":   true,
	"RPC":   true,
	"SLA":   true,
	"SMTP":  true,
	"SQL":   true,
	"SSH":   true,
	"TCP":   true,
	"TLS":   true,
	"TTL":   true,
	"UDP":   true,
	"UI":    true,
	"UID":   true,
	"UUID":  true,
	"URI":   true,
	"URL":   true,
	"UTF8":  true,
	"VM":    true,
	"XML":   true,
	"XMPP":  true,
	"XSRF":  true,
	"XSS":   true,
}

func isDelimiter(c rune) bool {
	return c == '-' || c == '_' || unicode.IsSpace(c)
}

func UcFirst(s string) string {
	if s == "" {
		return ""
	}
	r := []rune(s)
	r[0] = unicode.ToUpper(r[0])
	return string(r)
}

func LcFirst(s string) string {
	if s == "" {
		return ""
	}

	r := []rune(s)
	r[0] = unicode.ToLower(r[0])
	return string(r)
}
