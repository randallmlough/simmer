package utils

import (
	"fmt"
	"golang.org/x/mod/modfile"
	"io/ioutil"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
)

var pathRegex *regexp.Regexp

func init() {
	var initError error
	pathRegex, initError = regexp.Compile(`src\/(.*)`)
	if initError != nil {
		fmt.Println("could not compile the path regex")
	}
}

func GetTemplate(filename string) string {
	// load path relative to calling source file
	_, callerFile, _, _ := runtime.Caller(1)
	rootDir := filepath.Dir(callerFile)
	content, err := ioutil.ReadFile(path.Join(rootDir, filename))
	if err != nil {
		fmt.Println("Could not read .gotpl file", err)
		return "Could not read .gotpl file"
	}
	return string(content)
}

func GetRootImportPath() string {
	importPath, err := RootImportPath()
	if err != nil {
		fmt.Printf("error while getting root import path %v", err)
		return ""
	}
	return importPath
}

func getGoImportFromFile(dir string) string {
	dir = strings.TrimPrefix(dir, "/")
	importPath, err := RootImportPath()
	if err != nil {
		fmt.Printf("error while getting root import path %v", err)
		return ""
	}

	return path.Join(importPath, dir)
}

func RootImportPath() (string, error) {
	projectPath, err := GetWorkingPath()
	if err != nil {
		// TODO: adhering to your original error handling
		//  should consider doing something here rather than continuing
		//  since this step occurs during generation, panicing or fatal error should be okay
		return "", fmt.Errorf("error while getting working directory %w", err)
	}
	if hasGoMod(projectPath) {
		modulePath, err := getModulePath(projectPath)
		if err != nil {
			// TODO: adhering to your original error handling
			//  should consider doing something here rather than continuing
			//  since this step occurs during generation, panicing or fatal error should be okay
			return "", fmt.Errorf("error while getting module path %w", err)
		}
		return modulePath, nil
	}

	return gopathImport(projectPath), nil
}
func GetProjectPath(dir string) (string, error) {
	longPath, err := filepath.Abs(dir)
	if err != nil {
		return "", fmt.Errorf("error while trying to convert folder to gopath %w", err)
	}
	return strings.TrimSuffix(longPath, dir), nil
}

// getWorkingPath gets the current working directory
func GetWorkingPath() (string, error) {
	wd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	return wd, nil
}
func hasGoMod(projectPath string) bool {
	filePath := path.Join(projectPath, "go.mod")
	return FileExists(filePath)
}

func FileExists(filename string) bool {
	info, err := os.Stat(filename)
	if os.IsNotExist(err) {
		return false
	}
	return !info.IsDir()
}

func getModulePath(projectPath string) (string, error) {
	filePath := path.Join(projectPath, "go.mod")
	file, err := ioutil.ReadFile(filePath)
	if err != nil {
		return "", fmt.Errorf("error while trying to read go mods path %w", err)
	}

	modPath := modfile.ModulePath(file)
	if modPath == "" {
		return "", fmt.Errorf("could not determine mod path \n")
	}
	return modPath, nil
}

func gopathImport(dir string) string {
	return strings.TrimPrefix(pathRegex.FindString(dir), "src/")
}
