package httpapi

import "net/http"

func (s *Server) handleSearchUsers(w http.ResponseWriter, r *http.Request) {
	pattern := "%" + r.URL.Query().Get("username") + "%"
	users, err := s.q.SearchUsers(r.Context(), pattern)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not search users")
		return
	}
	out := make([]userDTO, 0, len(users))
	for _, u := range users {
		dto, err := s.buildUserDTO(r.Context(), u)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "could not load users")
			return
		}
		out = append(out, dto)
	}
	writeJSON(w, http.StatusOK, out)
}
