package schema

import (
	"github.com/stretchr/testify/require"
	"github.com/vektah/gqlparser/v2/ast"
	"reflect"
	"strings"
	"testing"
)

func TestFilesToAstSources(t *testing.T) {
	t.Parallel()

	t.Run("parse single file", func(t *testing.T) {
		expected := []*ast.Source{
			{
				Name: "testdata/schema.graphql",
				Input: strings.TrimSpace(`
schema {
    query: Query
    mutation: Mutation
}

type Query {
    user(id: ID!): User
    users: [User]
    me: User
}

type Mutation {
    createUser(input: UserInput!): User!
    updateUser(id: ID!, input: UserInput!): User!
}

type User {
    id: ID!
    createdAt: Time!
    updatedAt: Time!
    name: String
}

input UserInput {
    name: String
}

# resolves to time.Time
scalar Time

# resolves to map[string]interface{}
scalar Map

# resolves to interface{}
scalar Any

# resolves to string of type Password
scalar Password
`),
				BuiltIn: false,
			},
		}

		got, err := filesToAstSources("testdata/schema.graphql")
		if err != nil {
			t.Errorf("expected to parse schema file: %#v", err)
			return
		}
		if match := reflect.DeepEqual(expected, got); !match {
			t.Errorf("expected: %#v got: %#v", expected, got)
		}
	})

	t.Run("glob files using wildcard", func(t *testing.T) {
		files, err := filesToAstSources("testdata/glob/**/*.graphql")
		if err != nil {
			t.Errorf("expected to parse schema file: %#v", err)
			return
		}
		var gotFileNames []string
		for _, file := range files {
			gotFileNames = append(gotFileNames, file.Name)
		}

		expectedFileNames := []string{
			"testdata/glob/directives.graphql",
			"testdata/glob/scalars.graphql",
			"testdata/glob/schema.graphql",
		}
		if match := reflect.DeepEqual(expectedFileNames, gotFileNames); !match {
			t.Errorf("expected: %#v got: %#v", expectedFileNames, gotFileNames)
		}
	})

	t.Run("glob sub directory", func(t *testing.T) {
		files, err := filesToAstSources("testdata/spec/**/*.graphql")
		if err != nil {
			t.Errorf("expected to parse schema file: %#v", err)
			return
		}
		var gotFileNames []string
		for _, file := range files {
			gotFileNames = append(gotFileNames, file.Name)
		}

		expectedFileNames := []string{
			"testdata/spec/directives.graphql",
			"testdata/spec/scalars.graphql",
			"testdata/spec/schema.graphql",
			"testdata/spec/types/account.graphql",
			"testdata/spec/types/auth.graphql",
			"testdata/spec/types/filter.graphql",
			"testdata/spec/types/rbac.graphql",
			"testdata/spec/types/user.graphql",
		}
		if match := reflect.DeepEqual(expectedFileNames, gotFileNames); !match {
			t.Errorf("expected: %#v got: %#v", expectedFileNames, gotFileNames)
		}
	})
}

func TestLoadSchema(t *testing.T) {
	t.Parallel()

	t.Run("multiple sources", func(t *testing.T) {
		sources := []*ast.Source{
			{
				Name: "scalars.graphql",
				Input: `
					# resolves to time.Time
					scalar Time
					
					# resolves to map[string]interface{}
					scalar Map
					
					# resolves to interface{}
					scalar Any
					
					# resolves to string of type Password
					scalar Password
				`,
				BuiltIn: false,
			},
			{
				Name: "schema.graphql",
				Input: `
					schema {
						query: Query
						mutation: Mutation
					}
					
					type Query {
						user(id: ID!): User
						users: [User]
						me: User
					}
					
					type Mutation {
						createUser(input: UserInput!): User!
						updateUser(id: ID!, input: UserInput!): User!
					}
					
					type User {
						id: ID!
						createdAt: Time!
						updatedAt: Time!
						name: String
					}
					
					input UserInput {
						name: String
					}
				`,
				BuiltIn: false,
			},
		}
		s, err := astSourceToAstSchema(sources...)
		if err != nil {
			t.Errorf("expected to load schema: %#v", err)
			return
		}

		if typ := s.Types["User"]; typ == nil {
			t.Error("expected to have type User")
		} else {
			if got := len(typ.Fields); got != 4 {
				t.Errorf("User should have 4 fields. Got: %#v", got)
			}

			if field := typ.Fields.ForName("id"); field == nil {
				t.Error("expected to have ID field. Got nil.")
			} else if required := field.Type.String(); required != "ID!" {
				t.Errorf("expected ID to be required. Got: %#v", required)
			}
		}

		if typ := s.Types["UserInput"]; typ == nil {
			t.Error("expected to have type UserInput")
		} else {
			if got := len(typ.Fields); got != 1 {
				t.Errorf("UserInput should have 1 field. Got: %#v", got)
			}

			if field := typ.Fields.ForName("name"); field == nil {
				t.Error("expected to have ID field. Got nil.")
			} else if fieldType := field.Type.String(); fieldType != "String" {
				t.Errorf("expected name to be of type String Got: %#v", fieldType)
			}
		}
	})
}

func TestSourceToSchemaDoc(t *testing.T) {
	t.Parallel()

	t.Run("parse simple source file", func(t *testing.T) {
		source := []*ast.Source{
			{
				Name: "schema.graphql",
				Input: strings.TrimSpace(`
type Query {
    me: User
}

type Mutation {
    createUser(input: UserInput!): User!
    updateUser(id: ID!, req: UserInput!): User!
}

type User{
    id: ID!
    createdAt: Time!
    updatedAt: Time!
    name: String
}

input UserInput{
    name: String
}
`),
				BuiltIn: false,
			},
		}

		got, err := sourceToSchemaDoc(source...)
		if err != nil {
			t.Errorf("TestSourceToSchemaDoc() error = %v", err)
		}
		require.Equal(t, "Query", got.Definitions[0].Name)
		require.Equal(t, "Mutation", got.Definitions[1].Name)
		require.Equal(t, "User", got.Definitions[2].Name)
	})
}

func TestParseSchemaDoc(t *testing.T) {
	t.Parallel()

	t.Run("parse simple source file", func(t *testing.T) {
		source := []*ast.Source{
			{
				Name: "schema.graphql",
				Input: strings.TrimSpace(`
type Query {
    user(id: ID!): User
    users: [User]
    me: User
}

type Mutation {
    createUser(input: UserInput!): UserPayload!
    updateUser(id: ID!, req: UserInput!): UserPayload!
}

type User{
    id: ID!
    createdAt: Time!
    updatedAt: Time!
    name: String
}

type UserPayload{
    success: Boolean!
    message: String!
    user: User
}

input UserInput{
    name: String
}
`),
				BuiltIn: false,
			},
		}

		schemaDoc, parseErr := sourceToSchemaDoc(source...)
		if parseErr != nil {
			t.Errorf("TestParseSchemaDoc() error = %v", parseErr)
		}
		s, err := astSchemaDocToAstSchema(schemaDoc)
		if err != nil {
			t.Errorf("TestParseSchemaDoc() error = %v", err)
		}
		require.Equal(t, "Query", s.Query.Name)
		require.Equal(t, "Mutation", s.Mutation.Name)
	})
}
