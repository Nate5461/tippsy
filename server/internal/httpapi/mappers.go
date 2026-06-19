package httpapi

import (
	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/Nate5461/tippsy/server/internal/recipes"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

// reviewFields is the common set of columns returned by every review query.
// It lets us map the four sqlc row types through one converter.
type reviewFields struct {
	ID              uuid.UUID
	Rating          *int16
	Comment         *string
	ImpairmentLevel *int16
	PhotoUrl        *string
	UserID          uuid.UUID
	CreatedAt       pgtype.Timestamptz
	RecipeName      string
	Username        string
}

func (s *Server) toReviewDTO(f reviewFields) reviewDTO {
	return reviewDTO{
		ID:              f.ID.String(),
		RecipeName:      f.RecipeName,
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
	return reviewFields{r.ID, r.Rating, r.Comment, r.ImpairmentLevel, r.PhotoUrl, r.UserID, r.CreatedAt, r.RecipeName, r.Username}
}

func fieldsFromUser(r sqlc.ListReviewsByUserRow) reviewFields {
	return reviewFields{r.ID, r.Rating, r.Comment, r.ImpairmentLevel, r.PhotoUrl, r.UserID, r.CreatedAt, r.RecipeName, r.Username}
}

func fieldsFromRecipe(r sqlc.ListReviewsByRecipeRow) reviewFields {
	return reviewFields{r.ID, r.Rating, r.Comment, r.ImpairmentLevel, r.PhotoUrl, r.UserID, r.CreatedAt, r.RecipeName, r.Username}
}

func fieldsFromFollowing(r sqlc.FollowingReviewsRow) reviewFields {
	return reviewFields{r.ID, r.Rating, r.Comment, r.ImpairmentLevel, r.PhotoUrl, r.UserID, r.CreatedAt, r.RecipeName, r.Username}
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

// --- ingredients & units ---

func (s *Server) toIngredientDTO(i sqlc.Ingredient) ingredientDTO {
	return ingredientDTO{
		ID:          i.ID.String(),
		Name:        i.Name,
		Kind:        string(i.Kind),
		ParentID:    pgUUIDString(i.ParentID),
		Abv:         i.Abv,
		Description: i.Description,
		ImageURL:    s.absoluteURL(i.ImageUrl),
		Popularity:  i.Popularity,
		Custom:      i.CreatedBy.Valid,
	}
}

func toUnitDTO(u sqlc.Unit) unitDTO {
	return unitDTO{Code: u.Code, Name: u.Name, Abbrev: u.Abbrev, Kind: string(u.Kind), MlEquiv: u.MlEquiv}
}

func toGlassDTO(g sqlc.GlassType) glassDTO {
	return glassDTO{Slug: g.Slug, Name: g.Name}
}

// --- recipes ---

// recipeSummaryFields is the common set of columns returned by every recipe
// list/detail query (search, makeable, favourites, get-by-id).
type recipeSummaryFields struct {
	ID               uuid.UUID
	Slug             string
	Name             string
	Description      *string
	Method           sqlc.RecipeMethod
	Glass            string
	GlassName        string
	Source           sqlc.RecipeSource
	AuthorID         pgtype.UUID
	AuthorName       *string
	Attribution      *string
	ParentRecipeID   pgtype.UUID
	ParentRecipeName *string
	Sweetness        *int16
	EstAbv           *float64
	ImageUrl         *string
	CreatedAt        pgtype.Timestamptz
	AverageRating    float64
	TotalReviews     int64
}

func (s *Server) toRecipeSummaryDTO(f recipeSummaryFields) recipeSummaryDTO {
	return recipeSummaryDTO{
		ID:               f.ID.String(),
		Slug:             f.Slug,
		Name:             f.Name,
		Description:      f.Description,
		Method:           string(f.Method),
		Glass:            f.Glass,
		GlassName:        f.GlassName,
		Source:           string(f.Source),
		AuthorID:         pgUUIDString(f.AuthorID),
		AuthorName:       f.AuthorName,
		Attribution:      f.Attribution,
		ParentRecipeID:   pgUUIDString(f.ParentRecipeID),
		ParentRecipeName: f.ParentRecipeName,
		Sweetness:        f.Sweetness,
		EstAbv:           f.EstAbv,
		Strength:         recipes.StrengthBand(f.EstAbv),
		ImageURL:         s.absoluteURL(f.ImageUrl),
		AverageRating:    f.AverageRating,
		TotalReviews:     f.TotalReviews,
		CreatedAt:        f.CreatedAt.Time,
	}
}

func fieldsFromGetRecipe(r sqlc.GetRecipeByIDRow) recipeSummaryFields {
	return recipeSummaryFields{r.ID, r.Slug, r.Name, r.Description, r.Method, r.Glass, r.GlassName,
		r.Source, r.AuthorID, r.AuthorName, r.Attribution, r.ParentRecipeID, r.ParentRecipeName,
		r.Sweetness, r.EstAbv, r.ImageUrl, r.CreatedAt, r.AverageRating, r.TotalReviews}
}

func fieldsFromSearchRecipe(r sqlc.SearchRecipesRow) recipeSummaryFields {
	return recipeSummaryFields{r.ID, r.Slug, r.Name, r.Description, r.Method, r.Glass, r.GlassName,
		r.Source, r.AuthorID, r.AuthorName, r.Attribution, r.ParentRecipeID, r.ParentRecipeName,
		r.Sweetness, r.EstAbv, r.ImageUrl, r.CreatedAt, r.AverageRating, r.TotalReviews}
}

func fieldsFromMakeable(r sqlc.MakeableRecipesRow) recipeSummaryFields {
	return recipeSummaryFields{r.ID, r.Slug, r.Name, r.Description, r.Method, r.Glass, r.GlassName,
		r.Source, r.AuthorID, r.AuthorName, r.Attribution, r.ParentRecipeID, r.ParentRecipeName,
		r.Sweetness, r.EstAbv, r.ImageUrl, r.CreatedAt, r.AverageRating, r.TotalReviews}
}

func fieldsFromFavourite(r sqlc.ListFavouritesRow) recipeSummaryFields {
	return recipeSummaryFields{r.ID, r.Slug, r.Name, r.Description, r.Method, r.Glass, r.GlassName,
		r.Source, r.AuthorID, r.AuthorName, r.Attribution, r.ParentRecipeID, r.ParentRecipeName,
		r.Sweetness, r.EstAbv, r.ImageUrl, r.CreatedAt, r.AverageRating, r.TotalReviews}
}

// toRecipeLineDTO renders one structured recipe line, including the measure
// pre-formatted in both unit systems.
func toRecipeLineDTO(row sqlc.ListRecipeIngredientsRow) recipeLineDTO {
	var unit *sqlc.Unit
	if row.UnitCode != nil {
		unit = &sqlc.Unit{
			Code:    *row.UnitCode,
			Name:    *row.UnitName,
			Abbrev:  *row.UnitAbbrev,
			Kind:    *row.UnitKind,
			MlEquiv: row.MlEquiv,
		}
	}
	metric, imperial := recipes.DisplayMeasures(row.Amount, unit)
	return recipeLineDTO{
		Position:       row.Position,
		IngredientID:   row.IngredientID.String(),
		IngredientName: row.IngredientName,
		IngredientKind: string(row.IngredientKind),
		Abv:            row.Abv,
		Amount:         row.Amount,
		Unit:           row.UnitCode,
		Note:           row.Note,
		Optional:       row.IsOptional,
		Garnish:        row.IsGarnish,
		Display:        measureDTO{Metric: metric, Imperial: imperial},
	}
}
