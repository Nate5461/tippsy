// Package httpapi contains the HTTP transport layer: router, middleware, and handlers.
package httpapi

import (
	"time"

	"github.com/Nate5461/tippsy/server/internal/config"
	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/Nate5461/tippsy/server/internal/email"
	"github.com/Nate5461/tippsy/server/internal/storage"
)

// Server holds the dependencies shared by all handlers.
type Server struct {
	q     *sqlc.Queries
	cfg   config.Config
	files *storage.Storage
	mailer email.Sender
}

// NewServer constructs a Server.
func NewServer(q *sqlc.Queries, cfg config.Config, files *storage.Storage, mailer email.Sender) *Server {
	return &Server{q: q, cfg: cfg, files: files, mailer: mailer}
}

// absoluteURL turns a stored relative path ("/uploads/x.jpg") into a full URL
// using the configured public base. Returns nil if there is no path.
func (s *Server) absoluteURL(rel *string) *string {
	if rel == nil || *rel == "" {
		return nil
	}
	full := s.cfg.PublicBaseURL + *rel
	return &full
}

// --- Response DTOs (clean, consistent camelCase JSON) ---

type followerDTO struct {
	ID             string  `json:"id"`
	Username       string  `json:"username"`
	ProfilePicture *string `json:"profilePicture"`
}

type preferencesDTO struct {
	Drink []string `json:"drink"`
}

type userDTO struct {
	ID             string         `json:"id"`
	Username       string         `json:"username"`
	Email          string         `json:"email"`
	DisplayName    *string        `json:"displayName"`
	Bio            *string        `json:"bio"`
	ProfilePicture *string        `json:"profilePicture"`
	Preferences    preferencesDTO `json:"preferences"`
	Followers      []followerDTO  `json:"followers"`
	Following      []followerDTO  `json:"following"`
}

type reviewDTO struct {
	ID              string    `json:"id"`
	DrinkName       string    `json:"drinkName"`
	Rating          int16     `json:"rating"`
	Comment         *string   `json:"comment"`
	ImpairmentLevel *int16    `json:"impairmentLevel"`
	PhotoURL        *string   `json:"photoUrl"`
	UserID          string    `json:"userId"`
	Username        string    `json:"username"`
	CreatedAt       time.Time `json:"createdAt"`
}

type recipeDTO struct {
	Ingredients  []string `json:"ingredients"`
	Instructions *string  `json:"instructions"`
}

type drinkDTO struct {
	ID            string    `json:"id"`
	Name          string    `json:"name"`
	Category      string    `json:"category"`
	Recipe        recipeDTO `json:"recipe"`
	AverageRating float64   `json:"averageRating"`
	TotalReviews  int64     `json:"totalReviews"`
}

type profileResponse struct {
	User    userDTO     `json:"user"`
	Reviews []reviewDTO `json:"reviews"`
}

type authUser struct {
	ID       string `json:"id"`
	Username string `json:"username"`
}

type authResponse struct {
	Token string   `json:"token"`
	User  authUser `json:"user"`
}
