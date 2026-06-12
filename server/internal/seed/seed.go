// Package seed imports recipe/ingredient content from JSON files into the
// official catalogue. Imports are idempotent: ingredients upsert by
// case-insensitive name, recipes by slug, so re-running after editing a file
// updates rows in place. See README.md in this package for the file format.
package seed

import (
	"context"
	"fmt"
	"strings"

	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/Nate5461/tippsy/server/internal/recipes"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

// File is one seed JSON document.
type File struct {
	Ingredients []IngredientSpec `json:"ingredients"`
	Recipes     []RecipeSpec     `json:"recipes"`
}

type IngredientSpec struct {
	Name        string  `json:"name"`
	Kind        string  `json:"kind"`   // spirit, liqueur, fortified_wine, wine, beer_cider, bitters, juice, syrup, soda_mixer, dairy_egg, fruit, herb_spice, garnish, other
	Abv         float64 `json:"abv"`    // percentage, 0 for non-alcoholic
	Parent      string  `json:"parent"` // optional: name of the generic this is a brand/style of
	Description string  `json:"description"`
}

type RecipeSpec struct {
	Slug         string     `json:"slug"` // stable key, e.g. "old-fashioned"
	Name         string     `json:"name"`
	Description  string     `json:"description"`
	Instructions string     `json:"instructions"`
	Method       string     `json:"method"` // shaken, stirred, built, blended, other (default stirred)
	Glass        string     `json:"glass"`
	Attribution  string     `json:"attribution"`
	Sweetness    *int16     `json:"sweetness"` // 0 (bone dry) – 10 (dessert)
	ImageURL     string     `json:"imageUrl"`
	Ingredients  []LineSpec `json:"ingredients"`
}

type LineSpec struct {
	Name     string   `json:"name"` // ingredient name; must exist in this file or the catalogue
	Amount   *float64 `json:"amount"`
	Unit     string   `json:"unit"` // a units.code; empty for unmeasured lines
	Note     string   `json:"note"`
	Optional bool     `json:"optional"`
}

// Stats reports what an import touched.
type Stats struct {
	Ingredients int
	Recipes     int
}

var validKinds = map[string]sqlc.IngredientKind{}

func init() {
	for _, k := range []sqlc.IngredientKind{
		sqlc.IngredientKindSpirit, sqlc.IngredientKindLiqueur, sqlc.IngredientKindFortifiedWine,
		sqlc.IngredientKindWine, sqlc.IngredientKindBeerCider, sqlc.IngredientKindBitters,
		sqlc.IngredientKindJuice, sqlc.IngredientKindSyrup, sqlc.IngredientKindSodaMixer,
		sqlc.IngredientKindDairyEgg, sqlc.IngredientKindFruit, sqlc.IngredientKindHerbSpice,
		sqlc.IngredientKindGarnish, sqlc.IngredientKindOther,
	} {
		validKinds[string(k)] = k
	}
}

var validMethods = map[string]sqlc.RecipeMethod{
	string(sqlc.RecipeMethodShaken):  sqlc.RecipeMethodShaken,
	string(sqlc.RecipeMethodStirred): sqlc.RecipeMethodStirred,
	string(sqlc.RecipeMethodBuilt):   sqlc.RecipeMethodBuilt,
	string(sqlc.RecipeMethodBlended): sqlc.RecipeMethodBlended,
	string(sqlc.RecipeMethodOther):   sqlc.RecipeMethodOther,
}

func key(name string) string { return strings.ToLower(strings.TrimSpace(name)) }

// Import applies one seed file. The caller supplies q bound to a transaction
// so a bad file rolls back atomically.
func Import(ctx context.Context, q *sqlc.Queries, f File) (Stats, error) {
	var stats Stats

	unitRows, err := q.ListUnits(ctx)
	if err != nil {
		return stats, fmt.Errorf("load units: %w", err)
	}
	units := make(map[string]sqlc.Unit, len(unitRows))
	for _, u := range unitRows {
		units[u.Code] = u
	}

	glassRows, err := q.ListGlassTypes(ctx)
	if err != nil {
		return stats, fmt.Errorf("load glass types: %w", err)
	}
	glasses := make(map[string]bool, len(glassRows))
	for _, g := range glassRows {
		glasses[g.Slug] = true
	}

	// Pass 1: upsert ingredients by name.
	byName := make(map[string]sqlc.Ingredient, len(f.Ingredients))
	for _, spec := range f.Ingredients {
		if strings.TrimSpace(spec.Name) == "" {
			return stats, fmt.Errorf("ingredient with empty name")
		}
		kind, ok := validKinds[spec.Kind]
		if !ok {
			return stats, fmt.Errorf("ingredient %q: unknown kind %q", spec.Name, spec.Kind)
		}
		if spec.Abv < 0 || spec.Abv > 100 {
			return stats, fmt.Errorf("ingredient %q: abv out of range", spec.Name)
		}
		ing, err := q.UpsertOfficialIngredient(ctx, sqlc.UpsertOfficialIngredientParams{
			ID:          uuid.New(),
			Name:        strings.TrimSpace(spec.Name),
			Kind:        kind,
			Abv:         spec.Abv,
			Description: optional(spec.Description),
		})
		if err != nil {
			return stats, fmt.Errorf("upsert ingredient %q: %w", spec.Name, err)
		}
		byName[key(spec.Name)] = ing
		stats.Ingredients++
	}

	// resolve finds an ingredient named in this file or already in the catalogue.
	resolve := func(name string) (sqlc.Ingredient, error) {
		if ing, ok := byName[key(name)]; ok {
			return ing, nil
		}
		ing, err := q.GetOfficialIngredientByName(ctx, name)
		if err != nil {
			return sqlc.Ingredient{}, fmt.Errorf("ingredient %q not found in file or catalogue", name)
		}
		byName[key(name)] = ing
		return ing, nil
	}

	// Pass 2: wire up parents (brand -> generic) now that everything exists.
	for _, spec := range f.Ingredients {
		if spec.Parent == "" {
			continue
		}
		parent, err := resolve(spec.Parent)
		if err != nil {
			return stats, fmt.Errorf("ingredient %q: parent: %w", spec.Name, err)
		}
		child := byName[key(spec.Name)]
		if parent.ID == child.ID {
			return stats, fmt.Errorf("ingredient %q: cannot be its own parent", spec.Name)
		}
		if err := q.SetIngredientParent(ctx, sqlc.SetIngredientParentParams{
			ID:       child.ID,
			ParentID: pgtype.UUID{Bytes: parent.ID, Valid: true},
		}); err != nil {
			return stats, fmt.Errorf("ingredient %q: set parent: %w", spec.Name, err)
		}
	}

	// Pass 3: upsert recipes and replace their lines.
	for _, spec := range f.Recipes {
		if strings.TrimSpace(spec.Slug) == "" || strings.TrimSpace(spec.Name) == "" {
			return stats, fmt.Errorf("recipe %q/%q: slug and name are required", spec.Slug, spec.Name)
		}
		method := sqlc.RecipeMethodStirred
		if spec.Method != "" {
			m, ok := validMethods[spec.Method]
			if !ok {
				return stats, fmt.Errorf("recipe %q: unknown method %q", spec.Slug, spec.Method)
			}
			method = m
		}
		if spec.Sweetness != nil && (*spec.Sweetness < 0 || *spec.Sweetness > 10) {
			return stats, fmt.Errorf("recipe %q: sweetness out of range", spec.Slug)
		}
		glass := strings.TrimSpace(spec.Glass)
		if !glasses[glass] {
			return stats, fmt.Errorf("recipe %q: unknown glass %q", spec.Slug, spec.Glass)
		}
		if len(spec.Ingredients) == 0 {
			return stats, fmt.Errorf("recipe %q: needs at least one ingredient", spec.Slug)
		}

		type resolvedLine struct {
			ingredient sqlc.Ingredient
			unitCode   *string
			spec       LineSpec
		}
		lines := make([]resolvedLine, 0, len(spec.Ingredients))
		strengthLines := make([]recipes.Line, 0, len(spec.Ingredients))
		for _, ls := range spec.Ingredients {
			ing, err := resolve(ls.Name)
			if err != nil {
				return stats, fmt.Errorf("recipe %q: %w", spec.Slug, err)
			}
			var unitCode *string
			var unit *sqlc.Unit
			if ls.Unit != "" {
				u, ok := units[ls.Unit]
				if !ok {
					return stats, fmt.Errorf("recipe %q: unknown unit %q", spec.Slug, ls.Unit)
				}
				unit = &u
				unitCode = &u.Code
			}
			if ls.Amount != nil && *ls.Amount <= 0 {
				return stats, fmt.Errorf("recipe %q: amount must be positive", spec.Slug)
			}
			lines = append(lines, resolvedLine{ingredient: ing, unitCode: unitCode, spec: ls})
			// Garnish dresses the drink; it does not count toward its strength.
			if ing.Kind != sqlc.IngredientKindGarnish {
				strengthLines = append(strengthLines, recipes.Line{Ml: recipes.LineMl(ls.Amount, unit), Abv: ing.Abv})
			}
		}

		var estAbv *float64
		if est, ok := recipes.EstimateABV(method, strengthLines); ok {
			estAbv = &est
		}

		rec, err := q.UpsertRecipeBySlug(ctx, sqlc.UpsertRecipeBySlugParams{
			ID:           uuid.New(),
			Slug:         strings.TrimSpace(spec.Slug),
			Name:         strings.TrimSpace(spec.Name),
			Description:  optional(spec.Description),
			Instructions: optional(spec.Instructions),
			Method:       method,
			Glass:        glass,
			Attribution:  optional(spec.Attribution),
			Sweetness:    spec.Sweetness,
			EstAbv:       estAbv,
			ImageUrl:     optional(spec.ImageURL),
		})
		if err != nil {
			return stats, fmt.Errorf("upsert recipe %q: %w", spec.Slug, err)
		}
		if err := q.DeleteRecipeIngredients(ctx, rec.ID); err != nil {
			return stats, fmt.Errorf("recipe %q: clear lines: %w", spec.Slug, err)
		}
		for i, line := range lines {
			if err := q.InsertRecipeIngredient(ctx, sqlc.InsertRecipeIngredientParams{
				RecipeID:     rec.ID,
				Position:     int16(i + 1),
				IngredientID: line.ingredient.ID,
				Amount:       line.spec.Amount,
				UnitCode:     line.unitCode,
				Note:         optional(line.spec.Note),
				IsOptional:   line.spec.Optional,
				IsGarnish:    line.ingredient.Kind == sqlc.IngredientKindGarnish,
			}); err != nil {
				return stats, fmt.Errorf("recipe %q: insert line %d: %w", spec.Slug, i+1, err)
			}
		}
		stats.Recipes++
	}

	return stats, nil
}

func optional(s string) *string {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil
	}
	return &s
}
