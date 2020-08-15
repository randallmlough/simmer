package utils

import (
	"github.com/volatiletech/null/v8"
	"time"
)

func IntsToInterfaces(ints []int) []interface{} {
	interfaces := make([]interface{}, len(ints))
	for index, number := range ints {
		interfaces[index] = number
	}
	return interfaces
}

func IntToTimeTime(v int) time.Time {
	return time.Unix(int64(v), 0)
}

func PointerIntToNullDotTime(v *int) null.Time {
	return null.TimeFrom(time.Unix(int64(*v), 0))
}

func PointerIntToInt(v *int) int {
	if v == nil {
		return 0
	}
	return *v
}

func PointerIntToNullDotInt(v *int) null.Int {
	return null.IntFromPtr((v))
}

func PointerIntToNullDotUint(v *int) null.Uint {
	if v == nil {
		return null.UintFromPtr(nil)
	}
	uv := *v
	return null.UintFrom(uint(uv))
}

func NullDotIntToPointerInt(v null.Int) *int {
	return v.Ptr()
}

func IntToInt8(v int) int8 {
	return int8(v)
}

func Int8ToInt(v int8) int {
	return int(v)
}

func IntToUint(v int) uint {
	return uint(v)
}

func UintToInt(v uint) int {
	return int(v)
}

func Int16ToInt(v int16) int {
	return int(v)
}

func IntToInt16(v int) int16 {
	return int16(v)
}

func PointerIntToInt16(v *int) int16 {
	if v != nil {
		return int16(*v)
	}

	return 0
}

func IntToBool(v int) bool {
	return v == 1
}

func PointerIntToNullDotBool(v *int) null.Bool {
	if v == nil {
		return null.Bool{
			Valid: false,
		}
	}
	return null.Bool{
		Valid: v != nil,
		Bool:  *v == 1,
	}
}

func NullDotIntToUint(v null.Int) uint {
	return uint(v.Int)
}

func NullDotIntIsFilled(v null.Int) bool {
	return !v.IsZero()
}

func IntIsFilled(v int) bool {
	return v != 0
}

func PointerIntToTimeTime(v *int) time.Time {
	if v == nil {
		return time.Time{}
	}

	return time.Unix(int64(*v), 0)
}

func PointerIntToNullDotInt16(v *int) null.Int16 {
	val := null.Int16{}
	if v != nil {
		val.SetValid(int16(*v))
	}

	return val
}

func NullDotInt16ToPointerInt(v null.Int16) *int {
	if v.IsZero() {
		return nil
	}

	val := new(int)

	*val = int(v.Int16)
	return val
}
