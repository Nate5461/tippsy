package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"

	"github.com/Nate5461/tippsy/server/internal/auth"
	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// parseIDParam reads a UUID path parameter, writing a 400 on failure.
func parseIDParam(w http.ResponseWriter, r *http.Request, name string) (uuid.UUID, bool) {
	id, err := uuid.Parse(chi.URLParam(r, name))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid "+name)
		return uuid.Nil, false
	}
	return id, true
}

// buildUserDTO assembles the full public user view (profile + social lists + prefs).
func (s *Server) buildUserDTO(ctx context.Context, u sqlc.User) (userDTO, error) {
	followers, err := s.q.ListFollowers(ctx, u.ID)
	if err != nil {
		return userDTO{}, err
	}
	following, err := s.q.ListFollowing(ctx, u.ID)
	if err != nil {
		return userDTO{}, err
	}
	prefs, err := s.q.ListUserDrinkPreferences(ctx, u.ID)
	if err != nil {
		return userDTO{}, err
	}
	if prefs == nil {
		prefs = []string{}
	}
	return userDTO{
		ID:             u.ID.String(),
		Username:       u.Username,
		Email:          u.Email,
		ProfilePicture: u.ProfilePicture,
		Preferences:    preferencesDTO{Drink: prefs},
		Followers:      followerDTOsFromFollowers(followers),
		Following:      followerDTOsFromFollowing(following),
	}, nil
}

func (s *Server) handleGetUser(w http.ResponseWriter, r *http.Request) {
	id, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}

	user, err := s.q.GetUserByID(r.Context(), id)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "user not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "could not load user")
		return
	}

	dto, err := s.buildUserDTO(r.Context(), user)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load user profile")
		return
	}

	rows, err := s.q.ListReviewsByUser(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load reviews")
		return
	}
	reviews := make([]reviewDTO, 0, len(rows))
	for _, row := range rows {
		reviews = append(reviews, s.toReviewDTO(fieldsFromUser(row)))
	}

	writeJSON(w, http.StatusOK, profileResponse{User: dto, Reviews: reviews})
}

type updateUserRequest struct {
	Username       *string `json:"username"`
	ProfilePicture *string `json:"profile_picture"`
}

func (s *Server) handleUpdateUser(w http.ResponseWriter, r *http.Request) {
	id, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	authUserID, _ := auth.GetUserID(r.Context())
	if authUserID != id {
		writeError(w, http.StatusForbidden, "you can only update your own profile")
		return
	}

	var req updateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	user, err := s.q.UpdateUser(r.Context(), sqlc.UpdateUserParams{
		Username:       req.Username,
		ProfilePicture: req.ProfilePicture,
		ID:             id,
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not update user")
		return
	}

	dto, err := s.buildUserDTO(r.Context(), user)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load updated profile")
		return
	}
	writeJSON(w, http.StatusOK, dto)
}

func (s *Server) handleFollow(w http.ResponseWriter, r *http.Request) {
	followeeID, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	followerID, _ := auth.GetUserID(r.Context())
	if followerID == followeeID {
		writeError(w, http.StatusBadRequest, "you cannot follow yourself")
		return
	}

	if err := s.q.FollowUser(r.Context(), sqlc.FollowUserParams{
		FollowerID: followerID,
		FolloweeID: followeeID,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, "could not follow user")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "Successfully followed the user"})
}

func (s *Server) handleUnfollow(w http.ResponseWriter, r *http.Request) {
	followeeID, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	followerID, _ := auth.GetUserID(r.Context())

	if err := s.q.UnfollowUser(r.Context(), sqlc.UnfollowUserParams{
		FollowerID: followerID,
		FolloweeID: followeeID,
	}); err != nil {
		writeError(w, http.StatusInternalServerError, "could not unfollow user")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "Successfully unfollowed the user"})
}

func (s *Server) handleFollowers(w http.ResponseWriter, r *http.Request) {
	id, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	rows, err := s.q.ListFollowers(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load followers")
		return
	}
	writeJSON(w, http.StatusOK, followerDTOsFromFollowers(rows))
}

func (s *Server) handleFollowing(w http.ResponseWriter, r *http.Request) {
	id, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	rows, err := s.q.ListFollowing(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load following")
		return
	}
	writeJSON(w, http.StatusOK, followerDTOsFromFollowing(rows))
}

func (s *Server) handleFollowingReviews(w http.ResponseWriter, r *http.Request) {
	id, ok := parseIDParam(w, r, "id")
	if !ok {
		return
	}
	rows, err := s.q.FollowingReviews(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load feed")
		return
	}
	out := make([]reviewDTO, 0, len(rows))
	for _, row := range rows {
		out = append(out, s.toReviewDTO(fieldsFromFollowing(row)))
	}
	writeJSON(w, http.StatusOK, out)
}

func (s *Server) handleTopUsers(w http.ResponseWriter, r *http.Request) {
	rows, err := s.q.TopUsers(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load top users")
		return
	}
	out := make([]userDTO, 0, len(rows))
	for _, row := range rows {
		dto, err := s.buildUserDTO(r.Context(), sqlc.User{
			ID:             row.ID,
			Username:       row.Username,
			Email:          row.Email,
			ProfilePicture: row.ProfilePicture,
			Location:       row.Location,
			CreatedAt:      row.CreatedAt,
		})
		if err != nil {
			writeError(w, http.StatusInternalServerError, "could not load top users")
			return
		}
		out = append(out, dto)
	}
	writeJSON(w, http.StatusOK, out)
}
