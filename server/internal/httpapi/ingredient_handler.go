package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/Nate5461/tippsy/server/internal/auth"
	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
)

var ingredientKinds = map[string]sqlc.IngredientKind{
	string(sqlc.IngredientKindSpirit):        sqlc.IngredientKindSpirit,
	string(sqlc.IngredientKindLiqueur):       sqlc.IngredientKindLiqueur,
	string(sqlc.IngredientKindFortifiedWine): sqlc.IngredientKindFortifiedWine,
	string(sqlc.IngredientKindWine):          sqlc.IngredientKindWine,
	string(sqlc.IngredientKindBeerCider):     sqlc.IngredientKindBeerCider,
	string(sqlc.IngredientKindBitters):       sqlc.IngredientKindBitters,
	string(sqlc.IngredientKindJuice):         sqlc.IngredientKindJuice,
	string(sqlc.IngredientKindSyrup):         sqlc.IngredientKindSyrup,
	string(sqlc.IngredientKindSodaMixer):     sqlc.IngredientKindSodaMixer,
	string(sqlc.IngredientKindDairyEgg):      sqlc.IngredientKindDairyEgg,
	string(sqlc.IngredientKindFruit):         sqlc.IngredientKindFruit,
	string(sqlc.IngredientKindHerbSpice):     sqlc.IngredientKindHerbSpice,
	string(sqlc.IngredientKindGarnish):       sqlc.IngredientKindGarnish,
	string(sqlc.IngredientKindOther):         sqlc.IngredientKindOther,
}

func (s *Server) handleListUnits(w http.ResponseWriter, r *http.Request) {
	rows, err := s.q.ListUnits(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load units")
		return
	}
	out := make([]unitDTO, 0, len(rows))
	for _, u := range rows {
		out = append(out, toUnitDTO(u))
	}
	writeJSON(w, http.StatusOK, out)
}

func (s *Server) handleListGlasses(w http.ResponseWriter, r *http.Request) {
	rows, err := s.q.ListGlassTypes(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load glass types")
		return
	}
	out := make([]glassDTO, 0, len(rows))
	for _, g := range rows {
		out = append(out, toGlassDTO(g))
	}
	writeJSON(w, http.StatusOK, out)
}

// handleSearchIngredients backs GET /ingredients in three modes, resolved in
// priority order:
//   - ?parentId=<uuid> lists the brands/styles under a generic (the drill-in);
//   - ?topLevel=true   lists the top-level generics for the browse grid, most
//     common first;
//   - otherwise        it is a free-text catalogue search (the long tail).
//
// An optional ?kind filters the grid and search modes.
func (s *Server) handleSearchIngredients(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.GetUserID(r.Context())
	query := r.URL.Query()

	var kind *sqlc.IngredientKind
	if raw := query.Get("kind"); raw != "" {
		k, ok := ingredientKinds[raw]
		if !ok {
			writeError(w, http.StatusBadRequest, "unknown ingredient kind")
			return
		}
		kind = &k
	}

	var rows []sqlc.Ingredient
	var err error
	switch {
	case query.Get("parentId") != "": // brands under a generic
		parentID, perr := uuid.Parse(query.Get("parentId"))
		if perr != nil {
			writeError(w, http.StatusBadRequest, "invalid parentId")
			return
		}
		rows, err = s.q.ListIngredientChildren(r.Context(), sqlc.ListIngredientChildrenParams{
			Parent: pgUUID(parentID),
			Viewer: pgUUID(userID),
		})
	case query.Get("topLevel") == "true": // most-common browse grid
		rows, err = s.q.ListTopLevelIngredients(r.Context(), sqlc.ListTopLevelIngredientsParams{
			Viewer: pgUUID(userID),
			Kind:   kind,
		})
	default: // free-text search (long tail)
		rows, err = s.q.SearchIngredients(r.Context(), sqlc.SearchIngredientsParams{
			Viewer: pgUUID(userID),
			Query:  strings.TrimSpace(query.Get("query")),
			Kind:   kind,
			Lim:    searchTypeLimit,
		})
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load ingredients")
		return
	}

	out := make([]ingredientDTO, 0, len(rows))
	for _, i := range rows {
		out = append(out, s.toIngredientDTO(i))
	}
	writeJSON(w, http.StatusOK, out)
}

type createIngredientRequest struct {
	Name        string   `json:"name"`
	Kind        string   `json:"kind"`
	Abv         *float64 `json:"abv"`
	ParentID    *string  `json:"parentId"`
	Description *string  `json:"description"`
}

// handleCreateIngredient adds a custom ingredient, visible only to its creator
// (and anywhere their recipes are shown) until promoted into the official
// catalogue.
func (s *Server) handleCreateIngredient(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.GetUserID(r.Context())

	var req createIngredientRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		writeError(w, http.StatusBadRequest, "name is required")
		return
	}
	kind, ok := ingredientKinds[req.Kind]
	if !ok {
		writeError(w, http.StatusBadRequest, "unknown ingredient kind")
		return
	}
	abv := 0.0
	if req.Abv != nil {
		abv = *req.Abv
	}
	if abv < 0 || abv > 100 {
		writeError(w, http.StatusBadRequest, "abv must be between 0 and 100")
		return
	}

	// Optional parent ties a brand/style to its generic (Grey Goose -> vodka).
	parentID := pgtype.UUID{}
	if req.ParentID != nil {
		pid, err := uuid.Parse(*req.ParentID)
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid parentId")
			return
		}
		parent, err := s.q.GetIngredient(r.Context(), pid)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				writeError(w, http.StatusBadRequest, "parent ingredient not found")
				return
			}
			writeError(w, http.StatusInternalServerError, "could not verify parent ingredient")
			return
		}
		if parent.CreatedBy.Valid && uuid.UUID(parent.CreatedBy.Bytes) != userID {
			writeError(w, http.StatusBadRequest, "parent ingredient not found")
			return
		}
		parentID = pgUUID(pid)
	}

	ing, err := s.q.CreateIngredient(r.Context(), sqlc.CreateIngredientParams{
		ID:          uuid.New(),
		Name:        req.Name,
		Kind:        kind,
		ParentID:    parentID,
		Abv:         abv,
		Description: req.Description,
		CreatedBy:   pgUUID(userID),
	})
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			writeError(w, http.StatusConflict, "you already have an ingredient with this name")
			return
		}
		writeError(w, http.StatusInternalServerError, "could not create ingredient")
		return
	}
	writeJSON(w, http.StatusCreated, s.toIngredientDTO(ing))
}
