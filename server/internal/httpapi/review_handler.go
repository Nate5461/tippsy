package httpapi

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/Nate5461/tippsy/server/internal/auth"
	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// maxUploadBytes caps the multipart body size for review photo uploads.
const maxUploadBytes = 10 << 20 // 10 MB

func (s *Server) handleCreateReview(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseMultipartForm(maxUploadBytes); err != nil {
		writeError(w, http.StatusBadRequest, "could not parse multipart form")
		return
	}
	userID, _ := auth.GetUserID(r.Context())

	drinkID, err := uuid.Parse(r.FormValue("drink_id"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "valid drink_id is required")
		return
	}

	rating, err := strconv.Atoi(r.FormValue("rating"))
	if err != nil || rating < 1 || rating > 5 {
		writeError(w, http.StatusBadRequest, "rating must be an integer between 1 and 5")
		return
	}

	// Confirm the drink exists so we can return a clean 400 rather than a FK error.
	if _, err := s.q.GetDrinkByID(r.Context(), drinkID); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusBadRequest, "drink not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "could not verify drink")
		return
	}

	params := sqlc.CreateReviewParams{
		ID:              uuid.New(),
		UserID:          userID,
		DrinkID:         drinkID,
		Rating:          int16(rating),
		Comment:         optionalString(r.FormValue("comment")),
		ImpairmentLevel: optionalInt16(r.FormValue("impairment_level")),
	}

	// Photo is optional.
	if file, header, err := r.FormFile("photo"); err == nil {
		defer file.Close()
		rel, err := s.files.Save(file, header)
		if err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		params.PhotoUrl = &rel
	} else if !errors.Is(err, http.ErrMissingFile) {
		writeError(w, http.StatusBadRequest, "could not read uploaded photo")
		return
	}

	review, err := s.q.CreateReview(r.Context(), params)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not create review")
		return
	}

	writeJSON(w, http.StatusCreated, map[string]any{
		"message":  "Review added successfully!",
		"photoUrl": s.absoluteURL(review.PhotoUrl),
	})
}

func (s *Server) handleListReviews(w http.ResponseWriter, r *http.Request) {
	rows, err := s.q.ListReviews(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load reviews")
		return
	}
	out := make([]reviewDTO, 0, len(rows))
	for _, row := range rows {
		out = append(out, s.toReviewDTO(fieldsFromList(row)))
	}
	writeJSON(w, http.StatusOK, out)
}

func (s *Server) handleReviewsByDrink(w http.ResponseWriter, r *http.Request) {
	drinkID, err := uuid.Parse(r.URL.Query().Get("drinkId"))
	if err != nil {
		writeError(w, http.StatusBadRequest, "valid drinkId query parameter is required")
		return
	}
	rows, err := s.q.ListReviewsByDrink(r.Context(), drinkID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load reviews")
		return
	}
	out := make([]reviewDTO, 0, len(rows))
	for _, row := range rows {
		out = append(out, s.toReviewDTO(fieldsFromDrink(row)))
	}
	writeJSON(w, http.StatusOK, out)
}

// optionalString returns nil for an empty/whitespace string, else a pointer to it.
func optionalString(v string) *string {
	v = strings.TrimSpace(v)
	if v == "" {
		return nil
	}
	return &v
}

// optionalInt16 parses an optional small integer form field; nil if absent/invalid.
func optionalInt16(v string) *int16 {
	v = strings.TrimSpace(v)
	if v == "" {
		return nil
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return nil
	}
	i := int16(n)
	return &i
}
