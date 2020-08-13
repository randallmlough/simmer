package schema

import (
	"github.com/stretchr/testify/require"
	"testing"
)

func TestBuildType(t *testing.T) {
	t.Parallel()

	schema, err := loadSchema([]string{
		"testdata/spec/**/*.graphql",
	})
	if err != nil {
		t.Errorf("expected to parse schema file: %#v", err)
		return
	}

	t.Run("create new Type from user schema", func(t *testing.T) {

		userSource, err := filesToAstSources("testdata/spec/types/user.graphql")
		if err != nil {
			t.Errorf("expected to parse schema file: %#v", err)
			return
		}
		got, err := buildType(schema, userSource[0])
		if err != nil {
			t.Errorf("buildType() error = %v", err)
			return
		}

		require.ElementsMatch(t,
			[]FuncType{
				{
					Name:       "id",
					Type:       "ID",
					IsRequired: true,
					IsSlice:    false,
				},
			},
			got.Methods[0].Args)
	})
}
