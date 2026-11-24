package httpapi

import (
	"net/http"
	"strings"

	"github.com/Nate5461/tippsy/server/internal/auth"
)

// RequireAuth returns middleware that verifies a Bearer JWT and injects the
// authenticated user's ID into the request context. Requests without a valid
// token are rejected with 401.
func RequireAuth(secret []byte) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			header := r.Header.Get("Authorization")
			token, ok := strings.CutPrefix(header, "Bearer ")
			if !ok || token == "" {
				writeError(w, http.StatusUnauthorized, "missing or malformed Authorization header")
				return
			}

			userID, err := auth.ParseToken(secret, token)
			if err != nil {
				writeError(w, http.StatusUnauthorized, "invalid or expired token")
				return
			}

			ctx := auth.WithUserID(r.Context(), userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
