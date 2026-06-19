package httpapi

import (
	"context"
	"net/http"
	"strings"

	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/google/uuid"
)

// maxTags caps how many tags a single recipe or menu may carry.
const maxTags = 20

// syncTags normalizes free-form tag labels to slugs (reusing slugify), upserts
// each into the shared tag pool, and returns their ids. Blank and duplicate
// entries are dropped, and the list is capped at maxTags. Pass the tx-scoped
// queries to run inside a transaction.
func (s *Server) syncTags(ctx context.Context, q *sqlc.Queries, labels []string) ([]uuid.UUID, error) {
	ids := make([]uuid.UUID, 0, len(labels))
	seen := make(map[string]struct{}, len(labels))
	for _, raw := range labels {
		label := strings.TrimSpace(raw)
		slug := slugify(label)
		if slug == "" {
			continue
		}
		if _, dup := seen[slug]; dup {
			continue
		}
		seen[slug] = struct{}{}
		tag, err := q.UpsertTag(ctx, sqlc.UpsertTagParams{ID: uuid.New(), Slug: slug, Label: label})
		if err != nil {
			return nil, err
		}
		ids = append(ids, tag.ID)
		if len(ids) >= maxTags {
			break
		}
	}
	return ids, nil
}

// applyRecipeTags replaces a recipe's tags with the given labels (delete + insert
// inside the caller's transaction). Returns a user-facing message, or "".
func (s *Server) applyRecipeTags(ctx context.Context, q *sqlc.Queries, recipeID uuid.UUID, labels []string) string {
	if err := q.DeleteRecipeTags(ctx, recipeID); err != nil {
		return "could not save recipe tags"
	}
	ids, err := s.syncTags(ctx, q, labels)
	if err != nil {
		return "could not save recipe tags"
	}
	for _, tid := range ids {
		if err := q.InsertRecipeTag(ctx, sqlc.InsertRecipeTagParams{RecipeID: recipeID, TagID: tid}); err != nil {
			return "could not save recipe tags"
		}
	}
	return ""
}

// applyMenuTags replaces a menu's tags with the given labels.
func (s *Server) applyMenuTags(ctx context.Context, q *sqlc.Queries, menuID uuid.UUID, labels []string) string {
	if err := q.DeleteMenuTags(ctx, menuID); err != nil {
		return "could not save menu tags"
	}
	ids, err := s.syncTags(ctx, q, labels)
	if err != nil {
		return "could not save menu tags"
	}
	for _, tid := range ids {
		if err := q.InsertMenuTag(ctx, sqlc.InsertMenuTagParams{MenuID: menuID, TagID: tid}); err != nil {
			return "could not save menu tags"
		}
	}
	return ""
}

// handleSearchTags powers tag autocomplete (GET /search/tags?query=su). An empty
// query returns the first tags alphabetically.
func (s *Server) handleSearchTags(w http.ResponseWriter, r *http.Request) {
	prefix := strings.TrimSpace(r.URL.Query().Get("query"))
	rows, err := s.q.SearchTags(r.Context(), &prefix)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not search tags")
		return
	}
	writeJSON(w, http.StatusOK, tagDTOs(rows))
}
