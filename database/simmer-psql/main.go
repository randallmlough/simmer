package main

import (
	"github.com/randallmlough/simmer/database"
	"github.com/randallmlough/simmer/database/simmer-psql/driver"
)

func main() {
	database.DriverMain(&driver.PostgresDriver{})
}
