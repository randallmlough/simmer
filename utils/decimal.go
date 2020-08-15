package utils

import "github.com/volatiletech/sqlboiler/v4/types"

func TypesNullDecimalToFloat64(v types.NullDecimal) float64 {
	if v.Big == nil {
		return 0
	}
	f, _ := v.Float64()
	return f
}

func TypesDecimalToFloat64(v types.Decimal) float64 {
	if v.Big == nil {
		return 0
	}
	f, _ := v.Float64()
	return f
}

func TypesNullDecimalToPointerString(v types.NullDecimal) *string {
	s := v.String()
	if s == "" {
		return nil
	}
	return &s
}
