package httpapi

import (
	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

// reviewFields is the common set of columns returned by every review query.
// It lets us map the four sqlc row types through one converter.
type reviewFields struct {
	ID              uuid.UUID
	Rating          int16
	Comment         *string
	ImpairmentLevel *int16
	PhotoUrl        *string
	UserID          uuid.UUID
	CreatedAt       pgtype.Timestamptz
	DrinkName       string
	Username        string
}

func (s *Server) toReviewDTO(f reviewFields) reviewDTO {
	return reviewDTO{
		ID:              f.ID.String(),
		DrinkName:       f.DrinkName,
		Rating:          f.Rating,
		Comment:         f.Comment,
		ImpairmentLevel: f.ImpairmentLevel,
		PhotoURL:        s.absoluteURL(f.PhotoUrl),
		UserID:          f.UserID.String(),
		Username:        f.Username,
		CreatedAt:       f.CreatedAt.Time,
	}
}

func fieldsFromList(r sqlc.ListReviewsRow) reviewFields {
	return reviewFields{r.ID, r.Rating, r.Comment, r.ImpairmentLevel, r.PhotoUrl, r.UserID, r.CreatedAt, r.DrinkName, r.Username}
}

func fieldsFromUser(r sqlc.ListReviewsByUserRow) reviewFields {
	return reviewFields{r.ID, r.Rating, r.Comment, r.ImpairmentLevel, r.PhotoUrl, r.UserID, r.CreatedAt, r.DrinkName, r.Username}
}

func fieldsFromDrink(r sqlc.ListReviewsByDrinkRow) reviewFields {
	return reviewFields{r.ID, r.Rating, r.Comment, r.ImpairmentLevel, r.PhotoUrl, r.UserID, r.CreatedAt, r.DrinkName, r.Username}
}

func fieldsFromFollowing(r sqlc.FollowingReviewsRow) reviewFields {
	return reviewFields{r.ID, r.Rating, r.Comment, r.ImpairmentLevel, r.PhotoUrl, r.UserID, r.CreatedAt, r.DrinkName, r.Username}
}

// followerDTOsFrom maps follower/following rows (both share the same shape).
func followerDTOsFromFollowers(rows []sqlc.ListFollowersRow) []followerDTO {
	out := make([]followerDTO, 0, len(rows))
	for _, r := range rows {
		out = append(out, followerDTO{ID: r.ID.String(), Username: r.Username, ProfilePicture: r.ProfilePicture})
	}
	return out
}

func followerDTOsFromFollowing(rows []sqlc.ListFollowingRow) []followerDTO {
	out := make([]followerDTO, 0, len(rows))
	for _, r := range rows {
		out = append(out, followerDTO{ID: r.ID.String(), Username: r.Username, ProfilePicture: r.ProfilePicture})
	}
	return out
}
