package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/Nate5461/tippsy/server/internal/auth"
	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// requireSelf parses the {id} path param and verifies it matches the
// authenticated user; the bar and menu are personal.
func requireSelf(w http.ResponseWriter, r *http.Request) (uuid.UUID, bool) {
	id, ok := parseIDParam(w, r, "id")
	if !ok {
		return uuid.Nil, false
	}
	authID, _ := auth.GetUserID(r.Context())
	if authID != id {
		writeError(w, http.StatusForbidden, "this is not your account")
		return uuid.Nil, false
	}
	return id, true
}

func (s *Server) handleListBar(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireSelf(w, r)
	if !ok {
		return
	}
	rows, err := s.q.ListBarItems(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load your bar")
		return
	}
	out := make([]barItemDTO, 0, len(rows))
	for _, row := range rows {
		out = append(out, barItemDTO{
			ingredientDTO: toIngredientDTO(sqlc.Ingredient{
				ID:          row.ID,
				Name:        row.Name,
				Kind:        row.Kind,
				ParentID:    row.ParentID,
				Abv:         row.Abv,
				Description: row.Description,
				CreatedBy:   row.CreatedBy,
			}),
			AddedAt: row.AddedAt.Time,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

func (s *Server) handleAddBarItem(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireSelf(w, r)
	if !ok {
		return
	}
	var req struct {
		IngredientID string `json:"ingredientId"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	ingredientID, err := uuid.Parse(req.IngredientID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "valid ingredientId is required")
		return
	}

	ing, err := s.q.GetIngredient(r.Context(), ingredientID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusBadRequest, "ingredient not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "could not verify ingredient")
		return
	}
	if ing.CreatedBy.Valid && uuid.UUID(ing.CreatedBy.Bytes) != userID {
		writeError(w, http.StatusBadRequest, "ingredient not found")
		return
	}

	if err := s.q.AddBarItem(r.Context(), sqlc.AddBarItemParams{UserID: userID, IngredientID: ingredientID}); err != nil {
		writeError(w, http.StatusInternalServerError, "could not add to your bar")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]string{"message": "Added to your bar"})
}

func (s *Server) handleRemoveBarItem(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireSelf(w, r)
	if !ok {
		return
	}
	ingredientID, ok := parseIDParam(w, r, "ingredientId")
	if !ok {
		return
	}
	if err := s.q.RemoveBarItem(r.Context(), sqlc.RemoveBarItemParams{UserID: userID, IngredientID: ingredientID}); err != nil {
		writeError(w, http.StatusInternalServerError, "could not remove from your bar")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "Removed from your bar"})
}
