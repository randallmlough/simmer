package data

import (
	"strings"

	"github.com/randallmlough/simmer/database"
	"github.com/volatiletech/strmangle"
)

// txtNameToOne creates the local and foreign function names for
// one-to-many and one-to-one relationships, where local is the side with
// the foreign key.
//
// = many-to-one
// users - videos : user_id
// users - videos : producer_id
//
// fk == table = user.Videos         | video.User
// fk != table = user.ProducerVideos | video.Producer
//
// = many-to-one
// industries - industries : industry_id
// industries - industries : parent_id
//
// fk == table = industry.Industries | industry.Industry
// fk != table = industry.ParentIndustries | industry.Parent
//
// = one-to-one
// users - videos : user_id
// users - videos : producer_id
//
// fk == table = user.Video         | video.User
// fk != table = user.ProducerVideo | video.Producer
//
// = one-to-one
// industries - industries : parent_id
//
// fk == table = industry.Industry | industry.Industry
// fk != table = industry.ParentIndustry | industry.Industry
func txtNameToOne(fk database.ForeignKey) (localFn, foreignFn string) {
	foreignFn = strmangle.Singular(trimSuffixes(fk.Column))
	fkeyNotTableName := foreignFn != strmangle.Singular(fk.ForeignTable)
	foreignFn = strmangle.TitleCase(foreignFn)

	if fkeyNotTableName {
		localFn = foreignFn
	}

	plurality := strmangle.Plural
	if fk.Unique {
		plurality = strmangle.Singular
	}
	localFn += strmangle.TitleCase(plurality(fk.Table))

	return localFn, foreignFn
}

// txtNameToMany creates the local and foreign function names for
// many-to-many relationships where there are two foreign keys involved.
//
// The output of the foreign key is the name for that side of the relationship.
//
//   | tags |  | tags_videos      |  | videos |
//   | id   |  | tag_id, video_id |  | id     |
//
// In this setup the lhs is the tag_id foreign key, and so the lhsFn will
// refer to "how to name the lhs" which in this case should be tags. And
// videos for the rhs.
//
// cases:
// sponsors - contests
// sponsor_id contest_id
// fk == table = sponsor.Contests | contest.Sponsors
//
// sponsors - contests
// wiggle_id jiggle_id
// fk != table = sponsor.JiggleSponsors | contest.WiggleContests
//
// industries - industries
// industry_id  mapped_industry_id
// fk == table = industry.Industries
// fk != table = industry.MappedIndustryIndustry
func txtNameToMany(lhs, rhs database.ForeignKey) (lhsFn, rhsFn string) {
	lhsKey := strmangle.Singular(trimSuffixes(lhs.Column))
	rhsKey := strmangle.Singular(trimSuffixes(rhs.Column))

	if lhsKey != strmangle.Singular(lhs.ForeignTable) {
		lhsFn = strmangle.TitleCase(lhsKey)
	}
	lhsFn += strmangle.TitleCase(strmangle.Plural(lhs.ForeignTable))

	if rhsKey != strmangle.Singular(rhs.ForeignTable) {
		rhsFn = strmangle.TitleCase(rhsKey)
	}
	rhsFn += strmangle.TitleCase(strmangle.Plural(rhs.ForeignTable))

	return lhsFn, rhsFn
}

var identifierSuffixes = []string{"_id", "_uuid", "_guid", "_oid"}

// trimSuffixes from the identifier
func trimSuffixes(str string) string {
	ln := len(str)
	for _, s := range identifierSuffixes {
		str = strings.TrimSuffix(str, s)
		if len(str) != ln {
			break
		}
	}

	return str
}
