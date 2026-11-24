package recipes

import (
	"testing"

	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
)

func fp(v float64) *float64 { return &v }

func unit(code, name, abbrev string, kind sqlc.UnitKind, mlEquiv *float64) *sqlc.Unit {
	return &sqlc.Unit{Code: code, Name: name, Abbrev: abbrev, Kind: kind, MlEquiv: mlEquiv}
}

var (
	ml       = unit("ml", "millilitre", "ml", sqlc.UnitKindVolume, fp(1))
	cl       = unit("cl", "centilitre", "cl", sqlc.UnitKindVolume, fp(10))
	oz       = unit("oz", "ounce", "oz", sqlc.UnitKindVolume, fp(30))
	dash     = unit("dash", "dash", "dash", sqlc.UnitKindVolume, fp(0.9))
	top      = unit("top", "top up", "top", sqlc.UnitKindVolume, fp(90))
	wedge    = unit("wedge", "wedge", "wedge", sqlc.UnitKindCount, nil)
	barspoon = unit("barspoon", "barspoon", "barspoon", sqlc.UnitKindVolume, fp(5))
)

func TestLineMl(t *testing.T) {
	tests := []struct {
		name   string
		amount *float64
		unit   *sqlc.Unit
		want   float64
	}{
		{"45 ml", fp(45), ml, 45},
		{"1.5 oz", fp(1.5), oz, 45},
		{"2 dashes", fp(2), dash, 1.8},
		{"top without amount counts as one unit", nil, top, 90},
		{"count unit contributes nothing", fp(1), wedge, 0},
		{"no unit contributes nothing", fp(2), nil, 0},
	}
	for _, tt := range tests {
		if got := LineMl(tt.amount, tt.unit); got != tt.want {
			t.Errorf("%s: LineMl = %v, want %v", tt.name, got, tt.want)
		}
	}
}

func TestEstimateABV(t *testing.T) {
	// Negroni: 30 ml gin (42%), 30 ml Campari (25%), 30 ml sweet vermouth (16%),
	// stirred. (30*42 + 30*25 + 30*16) / (90 * 1.20) = 23.06 → 23.1.
	negroni := []Line{{30, 42}, {30, 25}, {30, 16}}
	got, ok := EstimateABV(sqlc.RecipeMethodStirred, negroni)
	if !ok || got != 23.1 {
		t.Errorf("negroni: got %v ok=%v, want 23.1 ok=true", got, ok)
	}

	// Mojito: 45 ml rum (40%) + 25 ml lime + 15 ml syrup + 90 ml soda top, built.
	mojito := []Line{{45, 40}, {25, 0}, {15, 0}, {90, 0}}
	got, ok = EstimateABV(sqlc.RecipeMethodBuilt, mojito)
	if !ok || got != 9.4 {
		t.Errorf("mojito: got %v ok=%v, want 9.4 ok=true", got, ok)
	}

	// Garnish-only "recipe" has no measurable volume.
	if _, ok := EstimateABV(sqlc.RecipeMethodShaken, []Line{{0, 0}}); ok {
		t.Error("zero-volume recipe should not be estimable")
	}

	// Unknown method falls back to the 'other' dilution rather than panicking.
	if _, ok := EstimateABV(sqlc.RecipeMethod("weird"), negroni); !ok {
		t.Error("unknown method should still estimate")
	}
}

func TestStrengthBand(t *testing.T) {
	tests := []struct {
		abv  *float64
		want int
	}{
		{nil, 0},
		{fp(3), 1},
		{fp(9.4), 2},
		{fp(18), 3},
		{fp(23.1), 4},
		{fp(32), 5},
	}
	for _, tt := range tests {
		if got := StrengthBand(tt.abv); got != tt.want {
			t.Errorf("StrengthBand(%v) = %d, want %d", tt.abv, got, tt.want)
		}
	}
}

func TestDisplayMeasures(t *testing.T) {
	tests := []struct {
		name         string
		amount       *float64
		unit         *sqlc.Unit
		wantMetric   string
		wantImperial string
	}{
		{"ml converts to bar-rounded oz", fp(45), ml, "45 ml", "1.5 oz"},
		{"awkward ml rounds to nearest quarter oz", fp(25), ml, "25 ml", "0.75 oz"},
		{"oz converts with the 30 ml convention", fp(1.5), oz, "45 ml", "1.5 oz"},
		{"fractional oz", fp(0.75), oz, "22.5 ml", "0.75 oz"},
		{"cl converts via ml", fp(4.5), cl, "4.5 cl", "1.5 oz"},
		{"dash stays a dash in both systems", fp(2), dash, "2 dash", "2 dash"},
		{"barspoon stays put", fp(1), barspoon, "1 barspoon", "1 barspoon"},
		{"count units stay put", fp(1), wedge, "1 wedge", "1 wedge"},
		{"amountless unit renders its name", nil, top, "top up", "top up"},
		{"no unit renders nothing", fp(2), nil, "", ""},
	}
	for _, tt := range tests {
		metric, imperial := DisplayMeasures(tt.amount, tt.unit)
		if metric != tt.wantMetric || imperial != tt.wantImperial {
			t.Errorf("%s: got (%q, %q), want (%q, %q)", tt.name, metric, imperial, tt.wantMetric, tt.wantImperial)
		}
	}
}
