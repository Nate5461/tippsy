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
	TagSlugs         []string
	TagLabels        []string
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
		Tags:             tagDTOsFromSlugsLabels(f.TagSlugs, f.TagLabels),
		CreatedAt:        f.CreatedAt.Time,
	}
}

func fieldsFromGetRecipe(r sqlc.GetRecipeByIDRow) recipeSummaryFields {
	return recipeSummaryFields{r.ID, r.Slug, r.Name, r.Description, r.Method, r.Glass, r.GlassName,
		r.Source, r.AuthorID, r.AuthorName, r.Attribution, r.ParentRecipeID, r.ParentRecipeName,
		r.Sweetness, r.EstAbv, r.ImageUrl, r.CreatedAt, r.AverageRating, r.TotalReviews, nil, nil}
}

func fieldsFromSearchRecipe(r sqlc.SearchRecipesRow) recipeSummaryFields {
	return recipeSummaryFields{r.ID, r.Slug, r.Name, r.Description, r.Method, r.Glass, r.GlassName,
		r.Source, r.AuthorID, r.AuthorName, r.Attribution, r.ParentRecipeID, r.ParentRecipeName,
		r.Sweetness, r.EstAbv, r.ImageUrl, r.CreatedAt, r.AverageRating, r.TotalReviews, r.TagSlugs, r.TagLabels}
}

func fieldsFromMakeable(r sqlc.MakeableRecipesRow) recipeSummaryFields {
	return recipeSummaryFields{r.ID, r.Slug, r.Name, r.Description, r.Method, r.Glass, r.GlassName,
		r.Source, r.AuthorID, r.AuthorName, r.Attribution, r.ParentRecipeID, r.ParentRecipeName,
		r.Sweetness, r.EstAbv, r.ImageUrl, r.CreatedAt, r.AverageRating, r.TotalReviews, nil, nil}
}

func fieldsFromFavourite(r sqlc.ListFavouritesRow) recipeSummaryFields {
	return recipeSummaryFields{r.ID, r.Slug, r.Name, r.Description, r.Method, r.Glass, r.GlassName,
		r.Source, r.AuthorID, r.AuthorName, r.Attribution, r.ParentRecipeID, r.ParentRecipeName,
		r.Sweetness, r.EstAbv, r.ImageUrl, r.CreatedAt, r.AverageRating, r.TotalReviews, nil, nil}
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

// fieldsFromMenuItem maps a menu line (recipe + position/note) to the shared
// recipe summary fields. Per-recipe tags are not fetched for menu contents.
func fieldsFromMenuItem(r sqlc.ListMenuItemsRow) recipeSummaryFields {
	return recipeSummaryFields{r.ID, r.Slug, r.Name, r.Description, r.Method, r.Glass, r.GlassName,
		r.Source, r.AuthorID, r.AuthorName, r.Attribution, r.ParentRecipeID, r.ParentRecipeName,
		r.Sweetness, r.EstAbv, r.ImageUrl, r.CreatedAt, r.AverageRating, r.TotalReviews, nil, nil}
}

// --- tags ---

func toTagDTO(t sqlc.Tag) tagDTO {
	return tagDTO{Slug: t.Slug, Label: t.Label}
}

func tagDTOs(rows []sqlc.Tag) []tagDTO {
	out := make([]tagDTO, 0, len(rows))
	for _, t := range rows {
		out = append(out, toTagDTO(t))
	}
	return out
}

// tagDTOsFromSlugsLabels zips the parallel slug/label arrays that the search and
// list queries aggregate into tag DTOs.
func tagDTOsFromSlugsLabels(slugs, labels []string) []tagDTO {
	out := make([]tagDTO, 0, len(slugs))
	for i := range slugs {
		label := slugs[i]
		if i < len(labels) {
			label = labels[i]
		}
		out = append(out, tagDTO{Slug: slugs[i], Label: label})
	}
	return out
}

// --- menus ---

// menuSummaryFields is the common column set shared by the menu list/detail/search
// queries, mapped through one converter.
type menuSummaryFields struct {
	ID          uuid.UUID
	UserID      uuid.UUID
	Name        string
	Description *string
	Visibility  sqlc.MenuVisibility
	ImageUrl    *string
	CreatedAt   pgtype.Timestamptz
	UpdatedAt   pgtype.Timestamptz
	AuthorName  string
	RecipeCount int64
	TagSlugs    []string
	TagLabels   []string
}

func (s *Server) toMenuSummaryDTO(f menuSummaryFields) menuSummaryDTO {
	return menuSummaryDTO{
		ID:          f.ID.String(),
		Name:        f.Name,
		Description: f.Description,
		Visibility:  string(f.Visibility),
		ImageURL:    s.absoluteURL(f.ImageUrl),
		AuthorID:    f.UserID.String(),
		AuthorName:  f.AuthorName,
		RecipeCount: f.RecipeCount,
		Tags:        tagDTOsFromSlugsLabels(f.TagSlugs, f.TagLabels),
		CreatedAt:   f.CreatedAt.Time,
		UpdatedAt:   f.UpdatedAt.Time,
	}
}

func menuFieldsFromGet(r sqlc.GetMenuByIDRow) menuSummaryFields {
	return menuSummaryFields{r.ID, r.UserID, r.Name, r.Description, r.Visibility, r.ImageUrl,
		r.CreatedAt, r.UpdatedAt, r.AuthorName, r.RecipeCount, r.TagSlugs, r.TagLabels}
}

func menuFieldsFromList(r sqlc.ListMenusByUserRow) menuSummaryFields {
	return menuSummaryFields{r.ID, r.UserID, r.Name, r.Description, r.Visibility, r.ImageUrl,
		r.CreatedAt, r.UpdatedAt, r.AuthorName, r.RecipeCount, r.TagSlugs, r.TagLabels}
}

func menuFieldsFromSearch(r sqlc.SearchMenusRow) menuSummaryFields {
	return menuSummaryFields{r.ID, r.UserID, r.Name, r.Description, r.Visibility, r.ImageUrl,
		r.CreatedAt, r.UpdatedAt, r.AuthorName, r.RecipeCount, r.TagSlugs, r.TagLabels}
}

// --- users (lightweight, for search) ---

func (s *Server) toUserSummaryDTO(u sqlc.User) userSummaryDTO {
	return userSummaryDTO{
		ID:             u.ID.String(),
		Username:       u.Username,
		DisplayName:    u.DisplayName,
		ProfilePicture: s.absoluteURL(u.ProfilePicture),
	}
}
