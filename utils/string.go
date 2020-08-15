package utils

import (
	"github.com/ericlagergren/decimal"
	"github.com/volatiletech/null/v8"
	"github.com/volatiletech/sqlboiler/v4/types"
)

func StringsToInterfaces(strings []string) []interface{} {
	interfaces := make([]interface{}, len(strings))
	for index, v := range strings {
		interfaces[index] = v
	}
	return interfaces
}

func NullDotStringToPointerString(v null.String) *string {
	return v.Ptr()
}

func NullDotStringToString(v null.String) string {
	if !v.Valid {
		return ""
	}

	return v.String
}

func PointerStringToString(v *string) string {
	if v == nil {
		return ""
	}
	return *v
}

func StringToPointerString(v string) *string {
	return &v
}

func StringToNullDotString(v string) null.String {
	return null.StringFrom(v)
}

func PointerStringToNullDotString(v *string) null.String {
	return null.StringFromPtr(v)
}

func PointerStringToTypesNullDecimal(v *string) types.NullDecimal {
	if v == nil {
		return types.NewNullDecimal(nil)
	}
	d := new(decimal.Big)
	if _, ok := d.SetString(*v); !ok {
		nd := types.NewNullDecimal(nil)
		if err := d.Context.Err(); err != nil {
			return nd
		}
		// TODO: error handling maybe write log line here
		// https://github.com/volatiletech/sqlboiler/blob/master/types/decimal.go#L156
		return nd
	}

	return types.NewNullDecimal(d)
}

func NullDotStringIsFilled(v null.String) bool {
	return !v.IsZero()
}

func StringIsFilled(v string) bool {
	return v != ""
}
