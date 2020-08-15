package utils

import (
	"github.com/volatiletech/null/v8"
	"time"
)

func NullDotTimeToInt(v null.Time) int {
	if !v.Valid {
		return 0
	}
	u := int(v.Time.Unix())
	return u
}

func NullDotTimeToPointerInt(v null.Time) *int {
	if !v.Valid {
		return nil
	}
	u := int(v.Time.Unix())
	return &u
}

func TimeTimeToInt(v time.Time) int {
	return int(v.Unix())
}

func TimeTimeToPointerInt(v time.Time) *int {
	u := TimeTimeToInt(v)
	return &u
}

func TimeDotTimeToPointerTimeTime(v time.Time) *time.Time {
	ret := new(time.Time)
	*ret = v
	return ret
}

func TimeTimeToPointerTimeTime(v time.Time) *time.Time {
	if v.IsZero() {
		return nil
	}

	val := new(time.Time)
	*val = v

	return val
}

func PointerTimeTimeToTimeDotTime(v *time.Time) time.Time {
	if v == nil {
		return time.Time{}
	}
	return *v
}

func NullDotTimeToTimeTime(v null.Time) time.Time {
	if !v.Valid {
		return time.Time{}
	}

	return v.Time
}

func NullDotTimeToPointerTimeTime(v null.Time) *time.Time {
	if !v.Valid {
		return nil
	}

	return TimeTimeToPointerTimeTime(v.Time)
}

func TimeTimeToNullDotTime(v time.Time) null.Time {
	return null.TimeFrom(v)
}

func PointerTimeTimeToNullDotTime(v *time.Time) null.Time {
	return null.TimeFromPtr(v)
}

func PointerTimeToTimeTime(v *time.Time) time.Time {
	if v == nil {
		return time.Time{}
	}

	return *v
}
