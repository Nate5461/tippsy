package httpapi

import (
	"net/http"

	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
)

func (s *Server) handleSearchDrinks(w http.ResponseWriter, r *http.Request) {
	pattern := "%" + r.URL.Query().Get("query") + "%"
	rows, err := s.q.SearchDrinks(r.Context(), pattern)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not search drinks")
		return
	}
	out := make([]drinkDTO, 0, len(rows))
	for _, d := range rows {
		out = append(out, drinkDTO{
			ID:            d.ID.String(),
			Name:          d.Name,
			Category:      d.Category,
			Recipe:        recipeDTO{Ingredients: d.RecipeIngredients, Instructions: d.RecipeInstructions},
			AverageRating: d.AverageRating,
			TotalReviews:  d.TotalReviews,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

type drinkNameDTO struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

func (s *Server) handleAllDrinks(w http.ResponseWriter, r *http.Request) {
	rows, err := s.q.ListAllDrinks(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load drinks")
		return
	}
	out := make([]drinkNameDTO, 0, len(rows))
	for _, d := range rows {
		out = append(out, drinkNameDTO{ID: d.ID.String(), Name: d.Name})
	}
	writeJSON(w, http.StatusOK, out)
}

func (s *Server) handleMostReviewedDrinks(w http.ResponseWriter, r *http.Request) {
	rows, err := s.q.MostReviewedDrinks(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load drinks")
		return
	}
	out := make([]drinkDTO, 0, len(rows))
	for _, d := range rows {
		out = append(out, mostReviewedToDTO(d))
	}
	writeJSON(w, http.StatusOK, out)
}

func mostReviewedToDTO(d sqlc.MostReviewedDrinksRow) drinkDTO {
	return drinkDTO{
		ID:           d.ID.String(),
		Name:         d.Name,
		Category:     d.Category,
		Recipe:       recipeDTO{Ingredients: d.RecipeIngredients, Instructions: d.RecipeInstructions},
		TotalReviews: d.TotalReviews,
	}
}
