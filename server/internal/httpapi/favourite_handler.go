package httpapi

import (
	"errors"
	"net/http"

	"github.com/Nate5461/tippsy/server/internal/auth"
	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/jackc/pgx/v5"
)

func (s *Server) handleAddFavourite(w http.ResponseWriter, r *http.Request) {
	recipeID, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	userID, _ := auth.GetUserID(r.Context())

	if _, err := s.q.GetRecipeByID(r.Context(), recipeID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "recipe not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "could not verify recipe")
		return
	}

	if err := s.q.AddFavourite(r.Context(), sqlc.AddFavouriteParams{UserID: userID, RecipeID: recipeID}); err != nil {
		writeError(w, http.StatusInternalServerError, "could not favourite recipe")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]string{"message": "Recipe favourited"})
}

func (s *Server) handleRemoveFavourite(w http.ResponseWriter, r *http.Request) {
	recipeID, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	userID, _ := auth.GetUserID(r.Context())

	if err := s.q.RemoveFavourite(r.Context(), sqlc.RemoveFavouriteParams{UserID: userID, RecipeID: recipeID}); err != nil {
		writeError(w, http.StatusInternalServerError, "could not unfavourite recipe")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "Recipe unfavourited"})
}

func (s *Server) handleListFavourites(w http.ResponseWriter, r *http.Request) {
	id, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	rows, err := s.q.ListFavourites(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load favourites")
		return
	}
	out := make([]recipeSummaryDTO, 0, len(rows))
	for _, row := range rows {
		out = append(out, s.toRecipeSummaryDTO(fieldsFromFavourite(row)))
	}
	writeJSON(w, http.StatusOK, out)
}
