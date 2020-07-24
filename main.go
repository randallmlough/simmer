package main

import (
	"github.com/randallmlough/simmer/config"
	"github.com/randallmlough/simmer/core"
	"github.com/randallmlough/simmer/task"
	"github.com/randallmlough/simmer/utils"
	"github.com/spf13/viper"
	"log"
	"os"
	"path/filepath"
)

//go:generate go-bindata -nometadata -pkg templatebin -prefix templates -o templatebin/bindata.go templates/...

func initConfig() {
	var err error
	viper.SetConfigName("simmer")

	configHome := os.Getenv("XDG_CONFIG_HOME")
	homePath := os.Getenv("HOME")
	wd, err := os.Getwd()
	if err != nil {
		wd = "."
	}

	configPaths := []string{wd}
	if len(configHome) > 0 {
		configPaths = append(configPaths, filepath.Join(configHome, "simmer"))
	} else {
		configPaths = append(configPaths, filepath.Join(homePath, ".config/simmer"))
	}

	for _, p := range configPaths {
		viper.AddConfigPath(p)
	}

	// Ignore errors here, fallback to other validation methods.
	// Users can use environment variables if a config is not found.
	_ = viper.ReadInConfig()
}

func createConfigPaths() []string {
	configHome := os.Getenv("XDG_CONFIG_HOME")
	homePath := os.Getenv("HOME")
	wd, err := os.Getwd()
	if err != nil {
		wd = "."
	}

	configPaths := []string{wd}
	if len(configHome) > 0 {
		configPaths = append(configPaths, filepath.Join(configHome, "simmer"))
	} else {
		configPaths = append(configPaths, filepath.Join(homePath, ".config/simmer"))
	}

	supportedExtensions := []string{".json", ".yml", ".yaml"}
	possibleConfigPaths := make([]string, len(configPaths)*len(supportedExtensions))
	for _, path := range configPaths {
		for _, ext := range supportedExtensions {
			file := "simmer" + ext
			possibleConfigPaths = append(possibleConfigPaths, filepath.Join(path, file))
		}
	}

	return possibleConfigPaths
}

func configExists(path string) bool {
	return utils.FileExists(path)
}

func main() {
	paths := createConfigPaths()
	var configPath string
	for _, path := range paths {
		if configExists(path) {
			configPath = path
		}
	}

	cfg, err := config.LoadConfig(configPath)
	if err != nil {
		log.Fatal(err)
		return
	}

	tasks, err := task.NewTasks(cfg.Tasks)
	if err != nil {
		log.Fatal(err)
		return
	}

	if err := core.Runner(cfg, tasks...); err != nil {
		log.Fatal(err)
		return
	}

}
