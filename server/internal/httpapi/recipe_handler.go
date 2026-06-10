package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/Nate5461/tippsy/server/internal/auth"
	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/Nate5461/tippsy/server/internal/recipes"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

const maxRecipeLines = 30

var recipeMethods = map[string]sqlc.RecipeMethod{
	string(sqlc.RecipeMethodShaken):  sqlc.RecipeMethodShaken,
	string(sqlc.RecipeMethodStirred): sqlc.RecipeMethodStirred,
	string(sqlc.RecipeMethodBuilt):   sqlc.RecipeMethodBuilt,
	string(sqlc.RecipeMethodBlended): sqlc.RecipeMethodBlended,
	string(sqlc.RecipeMethodOther):   sqlc.RecipeMethodOther,
}

type recipeLineRequest struct {
	IngredientID string   `json:"ingredientId"`
	Amount       *float64 `json:"amount"`
	Unit         *string  `json:"unit"`
	Note         *string  `json:"note"`
	Optional     bool     `json:"optional"`
}

type recipePayload struct {
	Name         string              `json:"name"`
	Description  *string             `json:"description"`
	Instructions *string             `json:"instructions"`
	Method       string              `json:"method"`
	Glass        *string             `json:"glass"`
	Sweetness    *int16              `json:"sweetness"`
	ImageURL     *string             `json:"imageUrl"`
	Ingredients  []recipeLineRequest `json:"ingredients"`
}

// validatedRecipe is a recipePayload after validation: enum-typed method, the
// computed strength, and insert-ready lines (RecipeID filled in later).
type validatedRecipe struct {
	method sqlc.RecipeMethod
	estAbv *float64
	lines  []sqlc.InsertRecipeIngredientParams
}

// validateRecipePayload checks the payload against the catalogue (ingredients
// must exist and be visible to the author; units must exist) and computes the
// estimated ABV. Returns a user-facing error message, or "" when valid.
func (s *Server) validateRecipePayload(ctx context.Context, userID uuid.UUID, p recipePayload) (validatedRecipe, string) {
	var v validatedRecipe

	if strings.TrimSpace(p.Name) == "" {
		return v, "name is required"
	}
	if p.Method == "" {
		v.method = sqlc.RecipeMethodStirred
	} else if m, ok := recipeMethods[p.Method]; ok {
		v.method = m
	} else {
		return v, "method must be one of: shaken, stirred, built, blended, other"
	}
	if p.Sweetness != nil && (*p.Sweetness < 0 || *p.Sweetness > 10) {
		return v, "sweetness must be between 0 (bone dry) and 10"
	}
	if len(p.Ingredients) == 0 || len(p.Ingredients) > maxRecipeLines {
		return v, "a recipe needs between 1 and 30 ingredients"
	}

	unitRows, err := s.q.ListUnits(ctx)
	if err != nil {
		return v, "could not load units"
	}
	units := make(map[string]sqlc.Unit, len(unitRows))
	for _, u := range unitRows {
		units[u.Code] = u
	}

	ids := make([]uuid.UUID, 0, len(p.Ingredients))
	for _, line := range p.Ingredients {
		id, err := uuid.Parse(line.IngredientID)
		if err != nil {
			return v, "every line needs a valid ingredientId"
		}
		ids = append(ids, id)
	}
	ingRows, err := s.q.GetIngredientsByIDs(ctx, ids)
	if err != nil {
		return v, "could not load ingredients"
	}
	ingredients := make(map[uuid.UUID]sqlc.Ingredient, len(ingRows))
	for _, ing := range ingRows {
		ingredients[ing.ID] = ing
	}

	strengthLines := make([]recipes.Line, 0, len(p.Ingredients))
	for i, line := range p.Ingredients {
		ing, ok := ingredients[ids[i]]
		if !ok {
			return v, "ingredient " + line.IngredientID + " does not exist"
		}
		// Custom ingredients are only usable by their creator.
		if ing.CreatedBy.Valid && uuid.UUID(ing.CreatedBy.Bytes) != userID {
			return v, "ingredient " + ing.Name + " is not available"
		}
		if line.Amount != nil && *line.Amount <= 0 {
			return v, "amounts must be greater than zero"
		}
		var unit *sqlc.Unit
		if line.Unit != nil {
			u, ok := units[*line.Unit]
			if !ok {
				return v, "unknown unit: " + *line.Unit
			}
			unit = &u
		}
		strengthLines = append(strengthLines, recipes.Line{Ml: recipes.LineMl(line.Amount, unit), Abv: ing.Abv})
		v.lines = append(v.lines, sqlc.InsertRecipeIngredientParams{
			Position:     int16(i + 1),
			IngredientID: ids[i],
			Amount:       line.Amount,
			UnitCode:     line.Unit,
			Note:         line.Note,
			IsOptional:   line.Optional,
		})
	}

	if est, ok := recipes.EstimateABV(v.method, strengthLines); ok {
		v.estAbv = &est
	}
	return v, ""
}

func (s *Server) handleCreateRecipe(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.GetUserID(r.Context())

	var p recipePayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	v, msg := s.validateRecipePayload(r.Context(), userID, p)
	if msg != "" {
		writeError(w, http.StatusBadRequest, msg)
		return
	}

	id := uuid.New()
	tx, err := s.pool.Begin(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not create recipe")
		return
	}
	defer tx.Rollback(r.Context())
	qtx := s.q.WithTx(tx)

	_, err = qtx.CreateRecipe(r.Context(), sqlc.CreateRecipeParams{
		ID:           id,
		Slug:         slugify(p.Name) + "-" + id.String()[:8],
		Name:         strings.TrimSpace(p.Name),
		Description:  p.Description,
		Instructions: p.Instructions,
		Method:       v.method,
		Glass:        p.Glass,
		Source:       sqlc.RecipeSourceCommunity,
		AuthorID:     pgUUID(userID),
		Sweetness:    p.Sweetness,
		EstAbv:       v.estAbv,
		ImageUrl:     p.ImageURL,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not create recipe")
		return
	}
	if msg := insertRecipeLines(r.Context(), qtx, id, v.lines); msg != "" {
		writeError(w, http.StatusInternalServerError, msg)
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		writeError(w, http.StatusInternalServerError, "could not create recipe")
		return
	}

	s.writeRecipeDetail(w, r.Context(), http.StatusCreated, id)
}

func (s *Server) handleUpdateRecipe(w http.ResponseWriter, r *http.Request) {
	id, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	userID, _ := auth.GetUserID(r.Context())

	var p recipePayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	v, msg := s.validateRecipePayload(r.Context(), userID, p)
	if msg != "" {
		writeError(w, http.StatusBadRequest, msg)
		return
	}

	tx, err := s.pool.Begin(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not update recipe")
		return
	}
	defer tx.Rollback(r.Context())
	qtx := s.q.WithTx(tx)

	// The WHERE clause enforces ownership and that only community recipes are
	// editable, so a miss here is indistinguishable from "not found".
	_, err = qtx.UpdateRecipe(r.Context(), sqlc.UpdateRecipeParams{
		Name:         strings.TrimSpace(p.Name),
		Description:  p.Description,
		Instructions: p.Instructions,
		Method:       v.method,
		Glass:        p.Glass,
		Sweetness:    p.Sweetness,
		EstAbv:       v.estAbv,
		ImageUrl:     p.ImageURL,
		ID:           id,
		AuthorID:     pgUUID(userID),
	})
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "recipe not found, or you cannot edit it")
			return
		}
		writeError(w, http.StatusInternalServerError, "could not update recipe")
		return
	}
	if err := qtx.DeleteRecipeIngredients(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, "could not update recipe")
		return
	}
	if msg := insertRecipeLines(r.Context(), qtx, id, v.lines); msg != "" {
		writeError(w, http.StatusInternalServerError, msg)
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		writeError(w, http.StatusInternalServerError, "could not update recipe")
		return
	}

	s.writeRecipeDetail(w, r.Context(), http.StatusOK, id)
}

func insertRecipeLines(ctx context.Context, q *sqlc.Queries, recipeID uuid.UUID, lines []sqlc.InsertRecipeIngredientParams) string {
	for _, line := range lines {
		line.RecipeID = recipeID
		if err := q.InsertRecipeIngredient(ctx, line); err != nil {
			return "could not save recipe ingredients"
		}
	}
	return ""
}

func (s *Server) handleDeleteRecipe(w http.ResponseWriter, r *http.Request) {
	id, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	userID, _ := auth.GetUserID(r.Context())

	rows, err := s.q.DeleteRecipe(r.Context(), sqlc.DeleteRecipeParams{ID: id, AuthorID: pgUUID(userID)})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not delete recipe")
		return
	}
	if rows == 0 {
		writeError(w, http.StatusNotFound, "recipe not found, or you cannot delete it")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "Recipe deleted"})
}

func (s *Server) handleGetRecipe(w http.ResponseWriter, r *http.Request) {
	id, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	s.writeRecipeDetail(w, r.Context(), http.StatusOK, id)
}

// writeRecipeDetail responds with the full structured recipe (summary + lines).
func (s *Server) writeRecipeDetail(w http.ResponseWriter, ctx context.Context, status int, id uuid.UUID) {
	rec, err := s.q.GetRecipeByID(ctx, id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "recipe not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "could not load recipe")
		return
	}
	lineRows, err := s.q.ListRecipeIngredients(ctx, id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load recipe ingredients")
		return
	}
	lines := make([]recipeLineDTO, 0, len(lineRows))
	for _, row := range lineRows {
		lines = append(lines, toRecipeLineDTO(row))
	}
	writeJSON(w, status, recipeDetailDTO{
		recipeSummaryDTO: s.toRecipeSummaryDTO(fieldsFromGetRecipe(rec)),
		Instructions:     rec.Instructions,
		Ingredients:      lines,
	})
}

func (s *Server) handleSearchRecipes(w http.ResponseWriter, r *http.Request) {
	params := sqlc.SearchRecipesParams{
		Pattern: "%" + r.URL.Query().Get("query") + "%",
	}
	if src := r.URL.Query().Get("source"); src != "" {
		if src != string(sqlc.RecipeSourceOfficial) && src != string(sqlc.RecipeSourceCommunity) {
			writeError(w, http.StatusBadRequest, "source must be official or community")
			return
		}
		s := sqlc.RecipeSource(src)
		params.Source = &s
	}
	if raw := r.URL.Query().Get("maxAbv"); raw != "" {
		maxAbv, err := strconv.ParseFloat(raw, 64)
		if err != nil {
			writeError(w, http.StatusBadRequest, "maxAbv must be a number")
			return
		}
		params.MaxAbv = &maxAbv
	}

	rows, err := s.q.SearchRecipes(r.Context(), params)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not search recipes")
		return
	}
	out := make([]recipeSummaryDTO, 0, len(rows))
	for _, row := range rows {
		out = append(out, s.toRecipeSummaryDTO(fieldsFromSearchRecipe(row)))
	}
	writeJSON(w, http.StatusOK, out)
}

// slugify reduces a recipe name to a url-safe slug fragment; the caller
// appends a uuid fragment for uniqueness.
func slugify(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	var b strings.Builder
	prevDash := true // also trims leading dashes
	for _, r := range s {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
			prevDash = false
		} else if !prevDash {
			b.WriteByte('-')
			prevDash = true
		}
	}
	return strings.TrimSuffix(b.String(), "-")
}
