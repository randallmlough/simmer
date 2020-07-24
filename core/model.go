package core

import "github.com/randallmlough/simmer/database"

type Model struct {
	Name  string
	Table database.Table
}
