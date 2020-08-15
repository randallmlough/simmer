package utils

import (
	"github.com/ericlagergren/decimal"
	"github.com/volatiletech/null/v8"
	"github.com/volatiletech/sqlboiler/v4/types"
)

func FloatsToInterfaces(fs []float64) []interface{} {
	interfaces := make([]interface{}, len(fs))
	for index, number := range fs {
		interfaces[index] = number
	}
	return interfaces
}

func Float64ToTypesNullDecimal(v float64) types.NullDecimal {
	d := new(decimal.Big)
	d.SetFloat64(v)
	return types.NewNullDecimal(d)
}

func Float64ToTypesDecimal(v float64) types.Decimal {
	d := new(decimal.Big)
	d.SetFloat64(v)
	return types.NewDecimal(d)
}

func Float64ToPointerFloat64(v float64) *float64 {
	return &v
}

func PointerFloat64ToFloat64(v *float64) float64 {
	return *v
}
func PointerFloat64ToTypesDecimal(v *float64) types.Decimal {
	if v == nil {
		return types.NewDecimal(decimal.New(0, 0))
	}
	d := new(decimal.Big)
	d.SetFloat64(*v)
	return types.NewDecimal(d)
}

func PointerFloat64ToTypesNullDecimal(v *float64) types.NullDecimal {
	if v == nil {
		return types.NewNullDecimal(nil)
	}
	return Float64ToTypesNullDecimal(*v)
}

func NullDotFloat64ToPointerFloat64(v null.Float64) *float64 {
	return v.Ptr()
}

func PointerFloat64ToNullDotFloat64(v *float64) null.Float64 {
	return null.Float64FromPtr(v)
}

func PointerFloat64ToNullDotFloat32(v *float64) null.Float32 {
	val := null.Float32{}
	if v != nil {
		val.SetValid(float32(*v))
	}

	return val
}

func NullDotFloat32ToPointerFloat64(v null.Float32) *float64 {
	if v.IsZero() {
		return nil
	}

	val := new(float64)

	*val = float64(v.Float32)
	return val
}
