# Simmer - Automated code generation.

Simmer's mission is to allow developers the ability to easily generate code based on their data models and client facing schema. Simmer can be leveraged to create a reflectionless ORM, domain driven services, conversion tools and much. Use Simmer as a task running CLI or as a library to fit your process and your needs.  

### Overview
For most applications your data models and client data types are fairly static. You want to receive data in a specific way and store your data in a specific. In-between the request, storage, and response a number of things may happen to ensure data integrity and reliability, such as; validation, normalization, conversion, error handling and so on. It's these in between steps where a lot of boilerplate code comes in and where Simmer aims to help.

### How it works
At a high level, Simmer is pretty simple. It's only job is to retrieve and connect your `models` to your `objects` and vice versa. 

We gather your `models` by connecting to your SQL database to aggregate all of its tables, constraints, and relationships. 

For your `objects`, Simmer will parse GraphQL files to efficiently build your client data types. Note: a GraphQL endpoint, resolvers or service isn't required for Simmer to work, we just use the `*.graphql` schema files to know what data types you want to receive. Simmer is GraphQL agnostic, it will easily work for REST endpoints and others.

## How to install
Simmer is still in high development mode, as a result Go (Golang) must be installed and added to your path. 

To install the Simmer CLI binary and library
```shell script
GO111MODULE=off go get github.com/randallmlough/simmer
```

Currently, Simmer needs to have our postgres database driver installed as well
```shell script
GO111MODULE=off go get github.com/randallmlough/simmer/database/simmer-psql
```
 
Once completed make sure to `source` or restart your shell so the `simmer` command is available in your terminal.

## How to use
For the CLI tool, add a `simmer.yml` (or `.json`) config file at the root of your project directory. Add your database credentials, and the tasks your wish Simmer to run. 

Once you are ready to generate your files simple invoke `simmer` in your command line

```shell script
simmer
```

### Config File
Simmer supports both yaml and json config files. Place a `simmer.yml` or `.json` at the root of your project.

```yaml
# Tell Simmer how it can connect to your database.
# Simmer can also digest and parse .env variables as shown in the pass field. Values after :- is used as a fallback value if an ENV variable isn't present.
database:
  dbname: raaloo
  host: localhost
  port: 5432
  user: postgres
  pass: ${DB_PASSWORD:-password}
  sslmode: disable
  blacklist:
    - migrations

# Tasks you wish Simmer to run
tasks:
  # the `orm` key is a keyword for simmer. If present, Simmer will understand that additional processing needs to be made to make deeper relationships. 
  orm:
    output: models
    wipe: true

  # a simple task to be run
  repository: # name of the task is required
    no_generated_header: true
    output: db # where you want the generated files to go
    template_dirs: # where simmer can find the templates you want to use relative to your project directory
      - relative/path/to/templates
    imports: # what imports should simmer add 
      all:
        standard:
          - '"context"'
          - '"database/sql"'
        third_party:
          - '"github.com/pkg/errors"'
          - '"github.com/raaloo/raaloo/models"'
      singleton: # singletons is a file that should only be generated once. This would be an `errors.go` file for example.
        db: # name of the singleton file. ie. `db.go.tpl`
          standard:
            - '"context"'
            - '"database/sql"'
          third_party:
            - '_ "github.com/jackc/pgx/v4/stdlib"'
            - '"github.com/randallmlough/simmer/simmer"'
        queries:
          standard:
            - '"strings"'
          third_party:
            - '"github.com/randallmlough/simmer/queries"'
        errors:
          third_party:
            - '"github.com/pkg/errors"'
```

### Supported Features
Currently, Simmer is in high active development that is evolving and changing rapidly. Simmer currently supports file generation from your data models and a PostgreSQL database. 

### Roadmap
- [ ] Objects from `*.graphql` schema files
- [ ] Database pkg refactoring to return interfaces rather than `sql.*` structs to support other databases libraries, like, PGX
- [ ] More command line options, like managing migrations or building the binary
- [ ] Tests, tests, and more tests

## Inspiration and credits
Simmer is currently a heavily restructured and modified fork of [SQLBoiler](https://github.com/volatiletech/sqlboiler) an amazing SQL ORM generator. For me, SQLBoiler was limited on what I could do with it outside of generating ORM files, I wanted a tool that not only could handle my data models but also my client data types. To achieve this a lot of restructuring needed to happen to lay the groundwork for more generalized data structure file generation.  