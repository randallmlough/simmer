{{- reserveImport "strings" -}}

func GenerateID(prefix string) string {
	id := rand.RandomString(12)
	if strings.HasSuffix(prefix, "_") {
		return prefix + id
	} else {
		return prefix + "_" + id
	}
}