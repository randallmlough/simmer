package utils

import "github.com/volatiletech/null/v8"

func NullUintToNullInt(u null.Uint) null.Int {
	return null.Int{
		Int:   int(u.Uint),
		Valid: u.Valid,
	}
}

func NullDotUintToPointerInt(v null.Uint) *int {
	if !v.Valid {
		return nil
	}
	u := int(v.Uint)
	return &u
}

func NullDotUintToUint(v null.Uint) uint {
	return v.Uint
}

func NullDotUintIsFilled(v null.Uint) bool {
	return !v.IsZero()
}

func UintIsFilled(v uint) bool {
	return v != 0
}
