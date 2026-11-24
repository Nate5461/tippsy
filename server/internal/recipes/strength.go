// Package recipes holds drink-domain logic shared by the API and the seeder:
// strength (ABV) estimation and measure display/conversion.
package recipes

import (
	"math"
	"strconv"

	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
)

// dilutionByMethod approximates the water added during preparation, as a
// fraction of the mixed (pre-dilution) volume.
var dilutionByMethod = map[sqlc.RecipeMethod]float64{
	sqlc.RecipeMethodShaken:  0.25,
	sqlc.RecipeMethodStirred: 0.20,
	sqlc.RecipeMethodBuilt:   0.10,
	sqlc.RecipeMethodBlended: 0.35,
	sqlc.RecipeMethodOther:   0.15,
}

// Line is one recipe measure resolved to millilitres for strength estimation.
type Line struct {
	Ml  float64 // contributed liquid volume; 0 for count units / unmeasured lines
	Abv float64 // ingredient ABV percentage (0–100)
}

// LineMl resolves a recipe line to millilitres. Count units and lines without
// a unit contribute no volume; a volume unit without an amount (e.g. "top with
// soda") counts as one unit — units like "top" carry a nominal ml_equiv for
// exactly this case.
func LineMl(amount *float64, unit *sqlc.Unit) float64 {
	if unit == nil || unit.MlEquiv == nil {
		return 0
	}
	n := 1.0
	if amount != nil {
		n = *amount
	}
	return n * *unit.MlEquiv
}

// EstimateABV returns the estimated served ABV percentage of a recipe,
// accounting for dilution from preparation. ok is false when no line carries
// volume, in which case strength is unknowable.
func EstimateABV(method sqlc.RecipeMethod, lines []Line) (estAbv float64, ok bool) {
	var totalMl, alcoholMl float64
	for _, l := range lines {
		totalMl += l.Ml
		alcoholMl += l.Ml * l.Abv / 100
	}
	if totalMl <= 0 {
		return 0, false
	}
	dilution, found := dilutionByMethod[method]
	if !found {
		dilution = dilutionByMethod[sqlc.RecipeMethodOther]
	}
	served := totalMl * (1 + dilution)
	return math.Round(alcoholMl/served*1000) / 10, true
}

// StrengthBand maps an estimated ABV onto the 1–5 meter shown in the app.
// 0 means strength is unknown.
func StrengthBand(estAbv *float64) int {
	if estAbv == nil {
		return 0
	}
	switch v := *estAbv; {
	case v <= 5:
		return 1
	case v <= 12:
		return 2
	case v <= 20:
		return 3
	case v <= 28:
		return 4
	default:
		return 5
	}
}

// MlPerOz is the bartending convention (1.5 oz = 45 ml), not the literal 29.57.
const MlPerOz = 30

// DisplayMeasures renders a line's measure in both unit systems. ml/cl and oz
// convert into each other; every other unit (dash, barspoon, wedge, ...) reads
// the same in both systems. Lines without a unit return empty strings, and a
// unit without an amount (e.g. "top") renders the unit name alone.
func DisplayMeasures(amount *float64, unit *sqlc.Unit) (metric, imperial string) {
	if unit == nil {
		return "", ""
	}
	if amount == nil {
		return unit.Name, unit.Name
	}
	switch unit.Code {
	case "ml":
		return formatAmount(*amount, "ml"), formatAmount(ozFromMl(*amount), "oz")
	case "cl":
		return formatAmount(*amount, "cl"), formatAmount(ozFromMl(*amount*10), "oz")
	case "oz":
		return formatAmount(*amount*MlPerOz, "ml"), formatAmount(*amount, "oz")
	default:
		s := formatAmount(*amount, unit.Abbrev)
		return s, s
	}
}

// ozFromMl converts with the 30 ml convention, rounded to the nearest 1/4 oz.
func ozFromMl(ml float64) float64 {
	return math.Round(ml/MlPerOz*4) / 4
}

func formatAmount(v float64, abbrev string) string {
	return strconv.FormatFloat(v, 'f', -1, 64) + " " + abbrev
}
