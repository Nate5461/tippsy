package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/Nate5461/tippsy/server/internal/auth"
	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

const maxMenuItems = 200

type menuPayload struct {
	Name        string   `json:"name"`
	Description *string  `json:"description"`
	Visibility  string   `json:"visibility"` // "public" (default) | "private"
	ImageURL    *string  `json:"imageUrl"`
	RecipeIDs   []string `json:"recipeIds"` // ordered; optional
	Tags        []string `json:"tags"`
}

type validatedMenu struct {
	visibility sqlc.MenuVisibility
	recipeIDs  []uuid.UUID // deduped, in submitted order
}

// validateMenuPayload checks the name, visibility, and that every referenced
// recipe exists. Returns a user-facing message, or "" when valid.
func (s *Server) validateMenuPayload(ctx context.Context, p menuPayload) (validatedMenu, string) {
	var v validatedMenu

	if strings.TrimSpace(p.Name) == "" {
		return v, "name is required"
	}
	switch p.Visibility {
	case "", string(sqlc.MenuVisibilityPublic):
		v.visibility = sqlc.MenuVisibilityPublic
	case string(sqlc.MenuVisibilityPrivate):
		v.visibility = sqlc.MenuVisibilityPrivate
	default:
		return v, "visibility must be public or private"
	}
	if len(p.RecipeIDs) > maxMenuItems {
		return v, "a menu can hold at most 200 recipes"
	}

	seen := make(map[uuid.UUID]struct{}, len(p.RecipeIDs))
	for _, raw := range p.RecipeIDs {
		id, err := uuid.Parse(raw)
		if err != nil {
			return v, "every recipeId must be a valid id"
		}
		if _, dup := seen[id]; dup {
			continue
		}
		seen[id] = struct{}{}
		if _, err := s.q.GetRecipeByID(ctx, id); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return v, "recipe " + id.String() + " not found"
			}
			return v, "could not verify recipes"
		}
		v.recipeIDs = append(v.recipeIDs, id)
	}
	return v, ""
}

func (s *Server) handleCreateMenu(w http.ResponseWriter, r *http.Request) {
	userID, _ := auth.GetUserID(r.Context())

	var p menuPayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	v, msg := s.validateMenuPayload(r.Context(), p)
	if msg != "" {
		writeError(w, http.StatusBadRequest, msg)
		return
	}

	id := uuid.New()
	tx, err := s.pool.Begin(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not create menu")
		return
	}
	defer tx.Rollback(r.Context())
	qtx := s.q.WithTx(tx)

	if _, err := qtx.CreateMenu(r.Context(), sqlc.CreateMenuParams{
		ID:          id,
		UserID:      userID,
		Name:        strings.TrimSpace(p.Name),
		Description: p.Description,
		Visibility:  v.visibility,
		ImageUrl:    p.ImageURL,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, "could not create menu")
		return
	}
	if msg := insertMenuItems(r.Context(), qtx, id, v.recipeIDs); msg != "" {
		writeError(w, http.StatusInternalServerError, msg)
		return
	}
	if msg := s.applyMenuTags(r.Context(), qtx, id, p.Tags); msg != "" {
		writeError(w, http.StatusInternalServerError, msg)
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		writeError(w, http.StatusInternalServerError, "could not create menu")
		return
	}
	s.writeMenuDetail(w, r.Context(), http.StatusCreated, id)
}

func (s *Server) handleUpdateMenu(w http.ResponseWriter, r *http.Request) {
	id, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	userID, _ := auth.GetUserID(r.Context())

	var p menuPayload
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	v, msg := s.validateMenuPayload(r.Context(), p)
	if msg != "" {
		writeError(w, http.StatusBadRequest, msg)
		return
	}

	tx, err := s.pool.Begin(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not update menu")
		return
	}
	defer tx.Rollback(r.Context())
	qtx := s.q.WithTx(tx)

	// The WHERE clause enforces ownership, so a miss is indistinguishable from
	// "not found".
	if _, err := qtx.UpdateMenu(r.Context(), sqlc.UpdateMenuParams{
		Name:        strings.TrimSpace(p.Name),
		Description: p.Description,
		Visibility:  v.visibility,
		ImageUrl:    p.ImageURL,
		ID:          id,
		UserID:      userID,
	}); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "menu not found, or you cannot edit it")
			return
		}
		writeError(w, http.StatusInternalServerError, "could not update menu")
		return
	}
	if err := qtx.DeleteMenuItems(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, "could not update menu")
		return
	}
	if msg := insertMenuItems(r.Context(), qtx, id, v.recipeIDs); msg != "" {
		writeError(w, http.StatusInternalServerError, msg)
		return
	}
	if msg := s.applyMenuTags(r.Context(), qtx, id, p.Tags); msg != "" {
		writeError(w, http.StatusInternalServerError, msg)
		return
	}
	if err := tx.Commit(r.Context()); err != nil {
		writeError(w, http.StatusInternalServerError, "could not update menu")
		return
	}
	s.writeMenuDetail(w, r.Context(), http.StatusOK, id)
}

func (s *Server) handleDeleteMenu(w http.ResponseWriter, r *http.Request) {
	id, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	userID, _ := auth.GetUserID(r.Context())

	rows, err := s.q.DeleteMenu(r.Context(), sqlc.DeleteMenuParams{ID: id, UserID: userID})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not delete menu")
		return
	}
	if rows == 0 {
		writeError(w, http.StatusNotFound, "menu not found, or you cannot delete it")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "Menu deleted"})
}

func (s *Server) handleGetMenu(w http.ResponseWriter, r *http.Request) {
	id, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	viewerID, _ := auth.GetUserID(r.Context())

	menu, err := s.q.GetMenuByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "menu not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "could not load menu")
		return
	}
	// Private menus are visible only to their owner; hide their existence.
	if menu.Visibility == sqlc.MenuVisibilityPrivate && menu.UserID != viewerID {
		writeError(w, http.StatusNotFound, "menu not found")
		return
	}
	s.writeMenuDetailRow(w, r.Context(), http.StatusOK, menu)
}

func (s *Server) handleListUserMenus(w http.ResponseWriter, r *http.Request) {
	id, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	viewerID, _ := auth.GetUserID(r.Context())

	rows, err := s.q.ListMenusByUser(r.Context(), sqlc.ListMenusByUserParams{
		Owner:          id,
		IncludePrivate: viewerID == id,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load menus")
		return
	}
	out := make([]menuSummaryDTO, 0, len(rows))
	for _, row := range rows {
		out = append(out, s.toMenuSummaryDTO(menuFieldsFromList(row)))
	}
	writeJSON(w, http.StatusOK, out)
}

func (s *Server) handleSearchMenus(w http.ResponseWriter, r *http.Request) {
	out, err := s.searchMenus(r.Context(), strings.TrimSpace(r.URL.Query().Get("query")), optionalParam(r, "tag"), searchTypeLimit)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not search menus")
		return
	}
	writeJSON(w, http.StatusOK, out)
}

type addMenuItemRequest struct {
	RecipeID string  `json:"recipeId"`
	Note     *string `json:"note"`
}

func (s *Server) handleAddMenuItem(w http.ResponseWriter, r *http.Request) {
	id, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	userID, _ := auth.GetUserID(r.Context())
	if !s.requireMenuOwner(w, r.Context(), id, userID) {
		return
	}

	var req addMenuItemRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	recipeID, err := uuid.Parse(req.RecipeID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid recipeId")
		return
	}
	if _, err := s.q.GetRecipeByID(r.Context(), recipeID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "recipe not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "could not verify recipe")
		return
	}
	if err := s.q.AddMenuItem(r.Context(), sqlc.AddMenuItemParams{MenuID: id, RecipeID: recipeID, Note: req.Note}); err != nil {
		writeError(w, http.StatusInternalServerError, "could not add recipe to menu")
		return
	}
	s.writeMenuDetail(w, r.Context(), http.StatusOK, id)
}

func (s *Server) handleRemoveMenuItem(w http.ResponseWriter, r *http.Request) {
	id, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	recipeID, ok := parseIDParam(w, r, "recipeId")
	if !ok {
		return
	}
	userID, _ := auth.GetUserID(r.Context())
	if !s.requireMenuOwner(w, r.Context(), id, userID) {
		return
	}

	rows, err := s.q.DeleteMenuItem(r.Context(), sqlc.DeleteMenuItemParams{MenuID: id, RecipeID: recipeID})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not remove recipe from menu")
		return
	}
	if rows == 0 {
		writeError(w, http.StatusNotFound, "that recipe is not in this menu")
		return
	}
	s.writeMenuDetail(w, r.Context(), http.StatusOK, id)
}

// requireMenuOwner loads the menu and verifies the caller owns it, writing the
// appropriate error and returning false otherwise.
func (s *Server) requireMenuOwner(w http.ResponseWriter, ctx context.Context, menuID, userID uuid.UUID) bool {
	menu, err := s.q.GetMenuByID(ctx, menuID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "menu not found")
			return false
		}
		writeError(w, http.StatusInternalServerError, "could not load menu")
		return false
	}
	if menu.UserID != userID {
		writeError(w, http.StatusForbidden, "this is not your menu")
		return false
	}
	return true
}

// searchMenus runs the ranked public-menu search and maps the rows to DTOs. Used
// by both GET /menus and the unified GET /search.
func (s *Server) searchMenus(ctx context.Context, query string, tag *string, lim int64) ([]menuSummaryDTO, error) {
	rows, err := s.q.SearchMenus(ctx, sqlc.SearchMenusParams{Query: query, Tag: tag, Lim: lim})
	if err != nil {
		return nil, err
	}
	out := make([]menuSummaryDTO, 0, len(rows))
	for _, row := range rows {
		out = append(out, s.toMenuSummaryDTO(menuFieldsFromSearch(row)))
	}
	return out, nil
}

func insertMenuItems(ctx context.Context, q *sqlc.Queries, menuID uuid.UUID, recipeIDs []uuid.UUID) string {
	for i, rid := range recipeIDs {
		if err := q.InsertMenuItem(ctx, sqlc.InsertMenuItemParams{
			MenuID:   menuID,
			RecipeID: rid,
			Position: int16(i),
		}); err != nil {
			return "could not save menu recipes"
		}
	}
	return ""
}

// writeMenuDetail loads the menu by id and responds with its detail (summary +
// ordered recipes).
func (s *Server) writeMenuDetail(w http.ResponseWriter, ctx context.Context, status int, id uuid.UUID) {
	menu, err := s.q.GetMenuByID(ctx, id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "menu not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "could not load menu")
		return
	}
	s.writeMenuDetailRow(w, ctx, status, menu)
}

func (s *Server) writeMenuDetailRow(w http.ResponseWriter, ctx context.Context, status int, menu sqlc.GetMenuByIDRow) {
	items, err := s.q.ListMenuItems(ctx, menu.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load menu recipes")
		return
	}
	recipeList := make([]recipeSummaryDTO, 0, len(items))
	for _, it := range items {
		recipeList = append(recipeList, s.toRecipeSummaryDTO(fieldsFromMenuItem(it)))
	}
	writeJSON(w, status, menuDetailDTO{
		menuSummaryDTO: s.toMenuSummaryDTO(menuFieldsFromGet(menu)),
		Recipes:        recipeList,
	})
}
