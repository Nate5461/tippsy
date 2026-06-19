package httpapi

import (
	"context"
	"net/http"
	"strconv"
	"strings"

	"github.com/Nate5461/tippsy/server/internal/auth"
	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/google/uuid"
)

// Per-type result caps: small when blending every type into one response, larger
// when the caller has narrowed to a single type.
const (
	searchAllLimit  = 8
	searchTypeLimit = 50
)

// handleSearch is the unified, Instagram-style search surface. With type=all (the
// default) it blends a few results from every type; with a single type it returns
// just that bucket honoring that type's filters. The response always uses the
// grouped shape, so unset buckets are simply omitted.
func (s *Server) handleSearch(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.GetUserID(r.Context())
	q := r.URL.Query()
	query := strings.TrimSpace(q.Get("query"))
	typ := q.Get("type")
	if typ == "" {
		typ = "all"
	}
	tag := optionalParam(r, "tag")

	var res searchResultsDTO
	var err error
	switch typ {
	case "all":
		if res.Recipes, err = s.searchRecipes(r.Context(), query, nil, nil, tag, searchAllLimit); err == nil {
			if res.Menus, err = s.searchMenus(r.Context(), query, tag, searchAllLimit); err == nil {
				if res.Users, err = s.searchUsers(r.Context(), query, searchAllLimit); err == nil {
					res.Ingredients, err = s.searchIngredients(r.Context(), userID, query, nil, searchAllLimit)
				}
			}
		}
	case "recipes":
		source, msg := parseSourceParam(r)
		if msg != "" {
			writeError(w, http.StatusBadRequest, msg)
			return
		}
		maxAbv, msg := parseMaxAbvParam(r)
		if msg != "" {
			writeError(w, http.StatusBadRequest, msg)
			return
		}
		res.Recipes, err = s.searchRecipes(r.Context(), query, source, maxAbv, tag, searchTypeLimit)
	case "menus":
		res.Menus, err = s.searchMenus(r.Context(), query, tag, searchTypeLimit)
	case "users":
		res.Users, err = s.searchUsers(r.Context(), query, searchTypeLimit)
	case "ingredients":
		kind, msg := parseKindParam(r)
		if msg != "" {
			writeError(w, http.StatusBadRequest, msg)
			return
		}
		res.Ingredients, err = s.searchIngredients(r.Context(), userID, query, kind, searchTypeLimit)
	default:
		writeError(w, http.StatusBadRequest, "type must be one of: all, recipes, menus, users, ingredients")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "search failed")
		return
	}
	writeJSON(w, http.StatusOK, res)
}

// handleSearchUsers backs GET /search/users (the type-specific shortcut). It
// accepts ?query and, for the legacy client, falls back to ?username.
func (s *Server) handleSearchUsers(w http.ResponseWriter, r *http.Request) {
	query := strings.TrimSpace(r.URL.Query().Get("query"))
	if query == "" {
		query = strings.TrimSpace(r.URL.Query().Get("username"))
	}
	out, err := s.searchUsers(r.Context(), query, searchTypeLimit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not search users")
		return
	}
	writeJSON(w, http.StatusOK, out)
}

// --- per-type search helpers (shared by handleSearch and the type endpoints) ---

func (s *Server) searchRecipes(ctx context.Context, query string, source *sqlc.RecipeSource, maxAbv *float64, tag *string, lim int64) ([]recipeSummaryDTO, error) {
	rows, err := s.q.SearchRecipes(ctx, sqlc.SearchRecipesParams{
		Query:  query,
		Source: source,
		MaxAbv: maxAbv,
		Tag:    tag,
		Lim:    lim,
	})
	if err != nil {
		return nil, err
	}
	out := make([]recipeSummaryDTO, 0, len(rows))
	for _, row := range rows {
		out = append(out, s.toRecipeSummaryDTO(fieldsFromSearchRecipe(row)))
	}
	return out, nil
}

func (s *Server) searchUsers(ctx context.Context, query string, lim int64) ([]userSummaryDTO, error) {
	rows, err := s.q.SearchUsers(ctx, sqlc.SearchUsersParams{Query: query, Lim: lim})
	if err != nil {
		return nil, err
	}
	out := make([]userSummaryDTO, 0, len(rows))
	for _, u := range rows {
		out = append(out, s.toUserSummaryDTO(u))
	}
	return out, nil
}

func (s *Server) searchIngredients(ctx context.Context, viewer uuid.UUID, query string, kind *sqlc.IngredientKind, lim int64) ([]ingredientDTO, error) {
	rows, err := s.q.SearchIngredients(ctx, sqlc.SearchIngredientsParams{
		Viewer: pgUUID(viewer),
		Query:  query,
		Kind:   kind,
		Lim:    lim,
	})
	if err != nil {
		return nil, err
	}
	out := make([]ingredientDTO, 0, len(rows))
	for _, i := range rows {
		out = append(out, s.toIngredientDTO(i))
	}
	return out, nil
}

// --- query param parsing (returns a user-facing message instead of an error) ---

func parseSourceParam(r *http.Request) (*sqlc.RecipeSource, string) {
	raw := r.URL.Query().Get("source")
	if raw == "" {
		return nil, ""
	}
	if raw != string(sqlc.RecipeSourceOfficial) && raw != string(sqlc.RecipeSourceCommunity) {
		return nil, "source must be official or community"
	}
	src := sqlc.RecipeSource(raw)
	return &src, ""
}

func parseMaxAbvParam(r *http.Request) (*float64, string) {
	raw := r.URL.Query().Get("maxAbv")
	if raw == "" {
		return nil, ""
	}
	v, err := strconv.ParseFloat(raw, 64)
	if err != nil {
		return nil, "maxAbv must be a number"
	}
	return &v, ""
}

func parseKindParam(r *http.Request) (*sqlc.IngredientKind, string) {
	raw := r.URL.Query().Get("kind")
	if raw == "" {
		return nil, ""
	}
	k, ok := ingredientKinds[raw]
	if !ok {
		return nil, "unknown ingredient kind"
	}
	return &k, ""
}

// optionalParam returns a pointer to a trimmed query value, or nil when absent.
func optionalParam(r *http.Request, key string) *string {
	if v := strings.TrimSpace(r.URL.Query().Get(key)); v != "" {
		return &v
	}
	return nil
}
