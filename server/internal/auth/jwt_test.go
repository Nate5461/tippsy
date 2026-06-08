package auth

import (
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

var testSecret = []byte("test-secret")

func TestIssueAndParseToken(t *testing.T) {
	userID := uuid.New()

	token, err := IssueToken(testSecret, userID)
	if err != nil {
		t.Fatalf("IssueToken: %v", err)
	}

	got, err := ParseToken(testSecret, token)
	if err != nil {
		t.Fatalf("ParseToken: %v", err)
	}
	if got != userID {
		t.Errorf("round-trip mismatch: got %s want %s", got, userID)
	}
}

func TestParseToken_Rejects(t *testing.T) {
	validToken, _ := IssueToken(testSecret, uuid.New())

	// Expired token, correctly signed.
	expiredClaims := Claims{RegisteredClaims: jwt.RegisteredClaims{
		Subject:   uuid.New().String(),
		ExpiresAt: jwt.NewNumericDate(time.Now().Add(-time.Hour)),
	}}
	expired, _ := jwt.NewWithClaims(jwt.SigningMethodHS256, expiredClaims).SignedString(testSecret)

	// Token signed with the "none" algorithm (the classic forgery attempt).
	noneToken, _ := jwt.NewWithClaims(jwt.SigningMethodNone, jwt.RegisteredClaims{
		Subject: uuid.New().String(),
	}).SignedString(jwt.UnsafeAllowNoneSignatureType)

	tests := map[string]struct {
		secret []byte
		token  string
	}{
		"wrong secret": {[]byte("other-secret"), validToken},
		"garbage":      {testSecret, "not.a.jwt"},
		"empty":        {testSecret, ""},
		"expired":      {testSecret, expired},
		"alg none":     {testSecret, noneToken},
	}

	for name, tc := range tests {
		t.Run(name, func(t *testing.T) {
			if _, err := ParseToken(tc.secret, tc.token); err == nil {
				t.Errorf("expected error for %s, got nil", name)
			}
		})
	}
}
