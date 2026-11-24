// Package httpapi contains the HTTP transport layer: router, middleware, and handlers.
package httpapi

import (
	"time"

	"github.com/Nate5461/tippsy/server/internal/config"
	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/Nate5461/tippsy/server/internal/email"
	"github.com/Nate5461/tippsy/server/internal/storage"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Server holds the dependencies shared by all handlers.
type Server struct {
	pool   *pgxpool.Pool // for multi-statement transactions (recipe + lines)
	q      *sqlc.Queries
	cfg    config.Config
	files  *storage.Storage
	mailer email.Sender
}

// NewServer constructs a Server.
func NewServer(pool *pgxpool.Pool, q *sqlc.Queries, cfg config.Config, files *storage.Storage, mailer email.Sender) *Server {
	return &Server{pool: pool, q: q, cfg: cfg, files: files, mailer: mailer}
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

// pgUUID wraps a uuid for nullable uuid columns (parent_id, author_id, ...).
func pgUUID(id uuid.UUID) pgtype.UUID {
	return pgtype.UUID{Bytes: id, Valid: true}
}

// pgUUIDString renders a nullable uuid column as a *string for DTOs.
func pgUUIDString(id pgtype.UUID) *string {
	if !id.Valid {
		return nil
	}
	s := uuid.UUID(id.Bytes).String()
	return &s
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
	MeasurePref    string         `json:"measurePref"`
	Preferences    preferencesDTO `json:"preferences"`
	Followers      []followerDTO  `json:"followers"`
	Following      []followerDTO  `json:"following"`
}

type reviewDTO struct {
	ID              string    `json:"id"`
	RecipeName      string    `json:"recipeName"`
	Rating          *int16    `json:"rating"` // null = bare log ("I made this")
	Comment         *string   `json:"comment"`
	ImpairmentLevel *int16    `json:"impairmentLevel"`
	PhotoURL        *string   `json:"photoUrl"`
	UserID          string    `json:"userId"`
	Username        string    `json:"username"`
	CreatedAt       time.Time `json:"createdAt"`
}

type ingredientDTO struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Kind        string  `json:"kind"`
	ParentID    *string `json:"parentId"`
	Abv         float64 `json:"abv"`
	Description *string `json:"description"`
	ImageURL    *string `json:"imageUrl"`   // absolute; null until artwork is added
	Popularity  int32   `json:"popularity"` // higher = more common on the browse grid
	Custom      bool    `json:"custom"`     // true = user-created, not in the official catalogue
}

type unitDTO struct {
	Code    string   `json:"code"`
	Name    string   `json:"name"`
	Abbrev  string   `json:"abbrev"`
	Kind    string   `json:"kind"`
	MlEquiv *float64 `json:"mlEquiv"`
}

type glassDTO struct {
	Slug string `json:"slug"`
	Name string `json:"name"`
}

type barItemDTO struct {
	ingredientDTO
	AddedAt time.Time `json:"addedAt"`
}

// measureDTO carries a line's measure pre-rendered in both unit systems so
// clients just pick the one matching the user's measurePref.
type measureDTO struct {
	Metric   string `json:"metric"`
	Imperial string `json:"imperial"`
}

type recipeLineDTO struct {
	Position       int16      `json:"position"`
	IngredientID   string     `json:"ingredientId"`
	IngredientName string     `json:"ingredientName"`
	IngredientKind string     `json:"ingredientKind"`
	Abv            float64    `json:"abv"`
	Amount         *float64   `json:"amount"`
	Unit           *string    `json:"unit"`
	Note           *string    `json:"note"`
	Optional       bool       `json:"optional"`
	Garnish        bool       `json:"garnish"` // rendered in the garnish sub-section
	Display        measureDTO `json:"display"`
}

type recipeSummaryDTO struct {
	ID               string    `json:"id"`
	Slug             string    `json:"slug"`
	Name             string    `json:"name"`
	Description      *string   `json:"description"`
	Method           string    `json:"method"`
	Glass            string    `json:"glass"`     // glass_types slug
	GlassName        string    `json:"glassName"` // display name for the slug
	Source           string    `json:"source"`
	AuthorID         *string   `json:"authorId"`   // null = Tippsy official
	AuthorName       *string   `json:"authorName"` // null = Tippsy official
	Attribution      *string   `json:"attribution"`
	ParentRecipeID   *string   `json:"parentRecipeId"` // set = modified variant of that recipe
	ParentRecipeName *string   `json:"parentRecipeName"`
	Sweetness        *int16    `json:"sweetness"` // author-set 0 (bone dry) – 10 (dessert)
	EstAbv           *float64  `json:"estAbv"`
	Strength         int       `json:"strength"` // 1–5 meter; 0 = unknown
	ImageURL         *string   `json:"imageUrl"`
	AverageRating    float64   `json:"averageRating"`
	TotalReviews     int64     `json:"totalReviews"`
	Tags             []tagDTO  `json:"tags,omitempty"`
	CreatedAt        time.Time `json:"createdAt"`
}

type recipeDetailDTO struct {
	recipeSummaryDTO
	Instructions *string         `json:"instructions"`
	Ingredients  []recipeLineDTO `json:"ingredients"`
}

// --- tags, menus, and search ---

type tagDTO struct {
	Slug  string `json:"slug"`
	Label string `json:"label"`
}

type menuSummaryDTO struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Description *string   `json:"description"`
	Visibility  string    `json:"visibility"` // "public" | "private"
	ImageURL    *string   `json:"imageUrl"`
	AuthorID    string    `json:"authorId"`
	AuthorName  string    `json:"authorName"`
	RecipeCount int64     `json:"recipeCount"`
	Tags        []tagDTO  `json:"tags"`
	CreatedAt   time.Time `json:"createdAt"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

type menuDetailDTO struct {
	menuSummaryDTO
	Recipes []recipeSummaryDTO `json:"recipes"`
}

// userSummaryDTO is the lightweight user shape used in search results, avoiding
// the followers/following round-trips that the full userDTO performs.
type userSummaryDTO struct {
	ID             string  `json:"id"`
	Username       string  `json:"username"`
	DisplayName    *string `json:"displayName"`
	ProfilePicture *string `json:"profilePicture"`
}

// searchResultsDTO is the grouped shape returned by GET /search. Buckets not
// requested (or empty) are omitted, so a single-type search returns just one.
type searchResultsDTO struct {
	Recipes     []recipeSummaryDTO `json:"recipes,omitempty"`
	Menus       []menuSummaryDTO   `json:"menus,omitempty"`
	Users       []userSummaryDTO   `json:"users,omitempty"`
	Ingredients []ingredientDTO    `json:"ingredients,omitempty"`
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
