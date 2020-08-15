package utils

import "github.com/volatiletech/null/v8"

func NullDotBoolToPointerBool(v null.Bool) *bool {
	return v.Ptr()
}

func BoolToPointerBool(v bool) *bool {
	return &v
}

func PointerBoolToBool(v *bool) bool {
	if v == nil {
		return false
	}
	return *v
}

func PointerBoolToNullDotBool(v *bool) null.Bool {
	return null.BoolFromPtr(v)
}

func BoolToInt(v bool) int {
	if v {
		return 1
	}
	return 0
}

func NullDotBoolToPointerInt(v null.Bool) *int {
	if !v.Valid {
		return nil
	}

	if v.Bool {
		i := 1
		return &i
	}
	i := 0
	return &i
}
