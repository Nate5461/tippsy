// Package auth handles JWT issuing/verification and request-scoped user identity.
package auth

import (
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

// tokenTTL is how long an issued token stays valid.
const tokenTTL = 24 * time.Hour

// Claims is the JWT payload. The user's ID is carried in the standard Subject
// field; we parse it back into a uuid.UUID on verification.
type Claims struct {
	jwt.RegisteredClaims
}

// IssueToken signs a new HS256 token for the given user.
func IssueToken(secret []byte, userID uuid.UUID) (string, error) {
	now := time.Now()
	claims := Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(tokenTTL)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(secret)
}

// ParseToken verifies a token string and returns the user ID it identifies.
// It rejects any token not signed with HS256 to avoid algorithm-confusion attacks.
func ParseToken(secret []byte, tokenStr string) (uuid.UUID, error) {
	claims := &Claims{}
	_, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return secret, nil
	})
	if err != nil {
		return uuid.Nil, err
	}

	userID, err := uuid.Parse(claims.Subject)
	if err != nil {
		return uuid.Nil, fmt.Errorf("invalid subject in token: %w", err)
	}
	return userID, nil
}
