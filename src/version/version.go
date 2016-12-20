// Package version implements version features.
package version

import (
	"regexp"
	"strings"

	version "github.com/hashicorp/go-version"
)

var ignoredVersions = map[string]bool{
	"86_64": true,
	"386":   true,
	"64":    true,
	"32":    true,
}

type Groups struct {
	Groups []Group
}

type Group struct {
	Versions         []Version
	PreferredVersion Version
	Urls             []string
}

type Version struct {
	Value      string
	Weight     int
	Prerelease bool
}

// NewGroups returns a new Groups instance.
func NewGroups() *Groups {
	return new(Groups)
}

// NewGroup returns a new Group instance. Array of version ("[]Version") can be
// passed.
func NewGroup(a ...interface{}) *Group {
	g := new(Group)
	if len(a) >= 1 {
		g.Versions = a[0].([]Version)
	}

	return g
}

// NewVersion returns a new Version instance. By default the weight is not set.
func NewVersion(version string, a ...interface{}) *Version {
	v := new(Version)
	v.Value = version
	if len(a) >= 1 {
		v.Weight = a[0].(int)
	}

	return v
}

// ExtractAll extracts from a string everything that looks like a version.
func ExtractAll(content string) []string {
	var versions []string

	// variants:
	//   `(?:\d+[._-])?(?:\d+[._-])?(?:\*|\d+)`
	//   `(?:[\d]+)(?:[._-](?:[\d])+)+`
	regexVersion := regexp.MustCompile(`(?:[\d]+)(?:[._-](?:[\d])+|(?:\w))+`)

	if regexVersion.MatchString(content) {
		versionMatches := regexVersion.FindAllStringSubmatch(content, -1)

		// create version array without skipped versions
		for _, match := range versionMatches {
			if ignoredVersions[match[0]] == true {
				// skip if ignored
				continue
			}
			versions = append(versions, match[0])
		}
	}

	return versions
}

// AddGroup adds a new group to the existing Groups.
func (self *Groups) AddGroup(group Group) {
	self.Groups = append(self.Groups, group)
}

// Weighten adds weights to each version of the each group. The weight
// represents how often the same version has been spotted in all the groups.
//
// Each version weight is the same in all groups.
func (self *Groups) Weighten() {
	weights := make(map[string]int)

	for _, group := range self.Groups {
		for _, version := range group.Versions {
			v := version.Value
			if weights[v] == 0 {
				weights[v] = 1
			} else {
				weights[v] += 1
			}
		}
	}

	// create same groups but with weights
	groups := NewGroups()
	for _, group := range self.Groups {
		var preferred Version

		g := NewGroup()
		g.Urls = group.Urls

		for _, v := range group.Versions {
			if preferred.Value == "" || preferred.Weight < weights[v.Value] {
				preferred = Version{
					Value:      v.Value,
					Weight:     weights[v.Value],
					Prerelease: v.Prerelease,
				}
			}
			g.AddVersion(v.Value, weights[v.Value])
			g.PreferredVersion = preferred
		}

		groups.AddGroup(*g)
	}

	self.Groups = groups.Groups
}

// GroupVersions groups urls in all groups by versions.
func (self *Groups) GroupVersions() {
	var keys []string
	encountered := map[string]bool{}
	urls := map[string][]string{}
	versions := map[string]Version{}

	groups := NewGroups()

	for _, group := range self.Groups {
		// by default the first extracted version is used
		v := group.Versions[0].Value

		// if preferred version is set use it instead
		if group.PreferredVersion.Value != "" {
			v = group.PreferredVersion.Value
		}

		u := group.Urls[0]
		if v != "" {
			if encountered[v] {
				urls[v] = append(urls[v], u)
			} else {
				keys = append(keys, v)
				encountered[v] = true
				urls[v] = []string{u}
				versions[v] = group.PreferredVersion
			}
		}
	}

	for _, key := range keys {
		g := NewGroup()
		g.AddVersion(versions[key].Value, versions[key].Weight, versions[key].Prerelease)
		g.Urls = urls[key]

		groups.AddGroup(*g)
	}

	self.Groups = groups.Groups
}

// CleanByWeights() calculates the average versions weight throughout all groups
// and eliminates all versions that have lesser weights.
//
// This helps to eliminate the total number of wrong positives during the
// version extraction.
func (self *Groups) CleanByWeights() {
	groups := NewGroups()

	w := 0
	for _, group := range self.Groups {
		w += group.PreferredVersion.Weight
	}
	averageWeight := w / len(self.Groups)

	for _, group := range self.Groups {
		// fmt.Println(group.PreferredVersion, averageWeight)
		if group.PreferredVersion.Weight >= averageWeight || len(group.Urls) > 0 {
			groups.AddGroup(group)
		}
	}

	self.Groups = groups.Groups
}

// AddVersion adds a version url to the existing Group. By default the weight is
// "0" and prerelease value is set to "false".
func (self *Group) AddVersion(version string, a ...interface{}) {
	weight := 0
	prerelease := false
	if len(a) == 1 {
		weight = a[0].(int)
	} else if len(a) == 2 {
		weight = a[0].(int)
		prerelease = a[1].(bool)
	}

	v := Version{version, weight, prerelease}
	self.Versions = append(self.Versions, v)

	// add preferred version if it's not set
	if self.PreferredVersion.Value == "" {
		self.PreferredVersion = v
	}
}

// AddUrl adds a new url to the existing Group.
func (self *Group) AddUrl(url string) {
	self.Urls = append(self.Urls, url)
}

// ExtractAll extracts from a string everything that looks like a version and
// adds them to the existing Group.
func (self *Group) ExtractAll(content string) {
	versions := ExtractAll(content)
	for _, version := range versions {
		self.AddVersion(version, 0)
	}
}

// LessThan compares if the version is less than the passed one.
func (self Version) LessThan(v *Version) (result bool, err error) {
	v1, err := version.NewVersion(self.Value)
	if err != nil {
		return false, err
	}

	v2, err := version.NewVersion(v.Value)
	if err != nil {
		return false, err
	}

	return v1.LessThan(v2), nil
}

// Major extracts the major semantic version part.
func (self Version) Major() string {
	re := regexp.MustCompile(`^\d`)
	return re.FindAllString(self.Value, -1)[0]
}

// Minor extracts the minor semantic version part.
func (self Version) Minor() string {
	re := regexp.MustCompile(`^(?:\d)\.(\d)`)
	return re.FindAllStringSubmatch(self.Value, -1)[0][1]
}

// Patch extracts the patch semantic version part.
func (self Version) Patch() string {
	re := regexp.MustCompile(`^(?:\d)\.(?:\d)\.(\d)`)
	return re.FindAllStringSubmatch(self.Value, -1)[0][1]
}

// MajorMinor extracts the major and minor semantic version parts.
func (self Version) MajorMinor() string {
	re := regexp.MustCompile(`^((?:\d)\.(?:\d))`)
	return re.FindAllString(self.Value, -1)[0]
}

// MajorMinorPatch extracts the major, minor and patch semantic version parts.
func (self Version) MajorMinorPatch() string {
	re := regexp.MustCompile(`^((?:\d)\.(?:\d)\.(?:\d))`)
	return re.FindAllString(self.Value, -1)[0]
}

// BeforeComma extract the part before comma.
func (self Version) BeforeComma() string {
	re := regexp.MustCompile(`(^.*)\,`)
	return re.FindAllStringSubmatch(self.Value, -1)[0][1]
}

// AfterComma extract the part after comma.
func (self Version) AfterComma() string {
	re := regexp.MustCompile(`\,(.*$)`)
	return re.FindAllStringSubmatch(self.Value, -1)[0][1]
}

// BeforeColon extract the part before colon.
func (self Version) BeforeColon() string {
	re := regexp.MustCompile(`(^.*)\:`)
	return re.FindAllStringSubmatch(self.Value, -1)[0][1]
}

// AfterColon extract the part after colon.
func (self Version) AfterColon() string {
	re := regexp.MustCompile(`\:(.*$)`)
	return re.FindAllStringSubmatch(self.Value, -1)[0][1]
}

// NoDots removes all dots from version.
func (self Version) NoDots() string {
	re := regexp.MustCompile(`\.`)
	return re.ReplaceAllString(self.Value, "")
}

// DotsToUnderscores convert all dots to underscores.
func (self Version) DotsToUnderscores() string {
	re := regexp.MustCompile(`\.`)
	return re.ReplaceAllString(self.Value, "_")
}

// DotsToHyphens convert all dots to hyphens.
func (self Version) DotsToHyphens() string {
	re := regexp.MustCompile(`\.`)
	return re.ReplaceAllString(self.Value, "-")
}

// InterpolateIntoString interpolates existing version into the provided string
// with Ruby interpolation syntax.
func (self Version) InterpolateIntoString(content string) (result string) {
	result = content

	regexInterpolations := regexp.MustCompile(`(#{version})|(#{version\.[^}]*.[^{]*})`)
	regexAllMethods := regexp.MustCompile(`(?:^#{version\.)(.*)}`)

	// find all version interpolations
	matches := regexInterpolations.FindAllStringSubmatch(content, -1)

	// for every version interpolation
	for _, m := range matches {
		match := m[0]

		// extract all methods
		methodsAll := regexAllMethods.FindAllStringSubmatch(match, -1)
		if len(methodsAll) < 1 {
			// when no methods, then it's just a version replace
			re := regexp.MustCompile(match)
			result = re.ReplaceAllString(result, self.Value)
			continue
		}

		methods := strings.Split(methodsAll[0][1], ".")

		// for every method
		part := self.Value
		for _, method := range methods {
			switch method {
			case "major":
				part = NewVersion(part).Major()
				break
			case "minor":
				part = NewVersion(part).Minor()
				break
			case "patch":
				part = NewVersion(part).Patch()
				break
			case "major_minor":
				part = NewVersion(part).MajorMinor()
				break
			case "major_minor_patch":
				part = NewVersion(part).MajorMinorPatch()
				break
			case "before_comma":
				part = NewVersion(part).BeforeComma()
				break
			case "after_comma":
				part = NewVersion(part).AfterComma()
				break
			case "before_colon":
				part = NewVersion(part).BeforeColon()
				break
			case "after_colon":
				part = NewVersion(part).AfterColon()
				break
			case "no_dots":
				part = NewVersion(part).NoDots()
				break
			case "dots_to_underscores":
				part = NewVersion(part).DotsToUnderscores()
				break
			case "dots_to_hyphens":
				part = NewVersion(part).DotsToHyphens()
				break
			default:
				// if one of the methods is unknown, then return full string without any replacements
				return result
			}
		}

		re := regexp.MustCompile(match)
		result = re.ReplaceAllString(result, part)
	}

	return result
}
