package auth

import (
	"context"

	"github.com/google/uuid"
)

// ctxKey is an unexported type so the context key can never collide with keys
// set by other packages.
type ctxKey struct{}

var userIDKey = ctxKey{}

// WithUserID returns a copy of ctx carrying the authenticated user's ID.
func WithUserID(ctx context.Context, id uuid.UUID) context.Context {
	return context.WithValue(ctx, userIDKey, id)
}

// GetUserID returns the authenticated user's ID from ctx, if present.
func GetUserID(ctx context.Context) (uuid.UUID, bool) {
	id, ok := ctx.Value(userIDKey).(uuid.UUID)
	return id, ok
}
