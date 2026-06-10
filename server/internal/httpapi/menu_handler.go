package httpapi

import (
	"net/http"
)

// handleMyMenu is the "My Menu" discovery feature: popular recipes the user
// can make right now from their bar. Ranking is by popularity for the moment;
// smarter (AI-assisted) ranking can slot in here later without an API change.
func (s *Server) handleMyMenu(w http.ResponseWriter, r *http.Request) {
	userID, ok := requireSelf(w, r)
	if !ok {
		return
	}
	rows, err := s.q.MakeableRecipes(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not build your menu")
		return
	}
	out := make([]recipeSummaryDTO, 0, len(rows))
	for _, row := range rows {
		out = append(out, s.toRecipeSummaryDTO(fieldsFromMakeable(row)))
	}
	writeJSON(w, http.StatusOK, out)
}
