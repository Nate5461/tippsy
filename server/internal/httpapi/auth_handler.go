package httpapi

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/Nate5461/tippsy/server/internal/auth"
	"github.com/Nate5461/tippsy/server/internal/db/sqlc"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

const (
	otpLength      = 6
	otpTTL         = 15 * time.Minute
	maxOTPAttempts = 5
)

// generateOTP returns a zero-padded 6-digit numeric code and its SHA-256 hex hash.
func generateOTP() (code string, hash string, err error) {
	b := make([]byte, 4)
	if _, err = rand.Read(b); err != nil {
		return "", "", fmt.Errorf("generate otp: %w", err)
	}
	// Fold into 0–999999 and zero-pad to 6 digits.
	n := (uint32(b[0])<<24 | uint32(b[1])<<16 | uint32(b[2])<<8 | uint32(b[3])) % 1_000_000
	code = fmt.Sprintf("%06d", n)
	sum := sha256.Sum256([]byte(code))
	hash = fmt.Sprintf("%x", sum)
	return code, hash, nil
}

// hashOTP returns the SHA-256 hex hash of a code — used when verifying.
func hashOTP(code string) string {
	sum := sha256.Sum256([]byte(code))
	return fmt.Sprintf("%x", sum)
}

// --- Register ---

type registerRequest struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (s *Server) handleRegister(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}
	req.Username = strings.TrimSpace(req.Username)
	req.Email = strings.TrimSpace(req.Email)
	if req.Username == "" || req.Email == "" || req.Password == "" {
		writeError(w, http.StatusBadRequest, "username, email and password are required")
		return
	}

	hash, err := auth.HashPassword(req.Password)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not hash password")
		return
	}

	// Look up any account already holding this email.
	existing, err := s.q.GetUserByEmail(r.Context(), req.Email)
	switch {
	case err == nil && existing.VerifiedAt.Valid:
		// A verified account owns this email — genuinely taken.
		writeError(w, http.StatusConflict, "an account with that email already exists")
		return

	case err == nil:
		// An unverified account holds this email. Nobody has proven ownership, so
		// let this registration reclaim it: overwrite the credentials and re-issue
		// a code. The real owner receives the code in their inbox and wins.
		if taken, terr := s.usernameTakenByOther(r.Context(), req.Username, &existing.ID); terr != nil {
			writeError(w, http.StatusInternalServerError, "could not check username")
			return
		} else if taken {
			writeError(w, http.StatusConflict, "that username is taken")
			return
		}

		user, uerr := s.q.UpdateUnverifiedUserCredentials(r.Context(), sqlc.UpdateUnverifiedUserCredentialsParams{
			ID:           existing.ID,
			Username:     req.Username,
			PasswordHash: hash,
		})
		if uerr != nil {
			writeError(w, http.StatusInternalServerError, "could not update registration")
			return
		}
		s.finishRegistration(w, r, user.ID, user.Email, user.Username)
		return

	case errors.Is(err, pgx.ErrNoRows):
		// Email is free — make sure the username isn't taken, then create.
		if taken, terr := s.usernameTakenByOther(r.Context(), req.Username, nil); terr != nil {
			writeError(w, http.StatusInternalServerError, "could not check username")
			return
		} else if taken {
			writeError(w, http.StatusConflict, "that username is taken")
			return
		}

		user, cerr := s.q.CreateUser(r.Context(), sqlc.CreateUserParams{
			ID:           uuid.New(),
			Username:     req.Username,
			Email:        req.Email,
			PasswordHash: hash,
		})
		if cerr != nil {
			writeError(w, http.StatusInternalServerError, "could not create user")
			return
		}
		s.finishRegistration(w, r, user.ID, user.Email, user.Username)
		return

	default:
		writeError(w, http.StatusInternalServerError, "could not check existing users")
		return
	}
}

// usernameTakenByOther reports whether the username is held by a user other than
// excludeID (pass nil when there is no account to exclude). Stale unverified
// holders count as taken; the cleanup job frees them over time.
func (s *Server) usernameTakenByOther(ctx context.Context, username string, excludeID *uuid.UUID) (bool, error) {
	u, err := s.q.GetUserByUsername(ctx, username)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	if excludeID != nil && u.ID == *excludeID {
		return false, nil
	}
	return true, nil
}

// finishRegistration issues and emails an OTP, then writes the pending-verification
// response shared by the create and reclaim paths.
func (s *Server) finishRegistration(w http.ResponseWriter, r *http.Request, userID uuid.UUID, email, username string) {
	if err := s.issueAndSendOTP(r, userID, email, username); err != nil {
		log.Printf("register: issueAndSendOTP for %s: %v", email, err)
		writeError(w, http.StatusInternalServerError, "could not send verification email")
		return
	}

	writeJSON(w, http.StatusCreated, map[string]any{
		"message":              "Registration successful! Please check your email for a verification code.",
		"pending_verification": true,
		"user_id":              userID.String(),
	})
}

// issueAndSendOTP generates an OTP, stores its hash, and emails it.
func (s *Server) issueAndSendOTP(r *http.Request, userID uuid.UUID, email, username string) error {
	code, codeHash, err := generateOTP()
	if err != nil {
		return err
	}

	if err := s.q.CreateEmailVerification(r.Context(), sqlc.CreateEmailVerificationParams{
		UserID:    userID,
		CodeHash:  codeHash,
		ExpiresAt: pgtype.Timestamptz{Time: time.Now().Add(otpTTL), Valid: true},
	}); err != nil {
		return fmt.Errorf("store verification: %w", err)
	}

	if err := s.mailer.SendOTP(email, username, code); err != nil {
		return fmt.Errorf("send otp email: %w", err)
	}
	return nil
}

// --- Verify email ---

type verifyEmailRequest struct {
	UserID string `json:"user_id"`
	Code   string `json:"code"`
}

func (s *Server) handleVerifyEmail(w http.ResponseWriter, r *http.Request) {
	var req verifyEmailRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	userID, err := uuid.Parse(req.UserID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user_id")
		return
	}
	req.Code = strings.TrimSpace(req.Code)
	if req.Code == "" {
		writeError(w, http.StatusBadRequest, "code is required")
		return
	}

	verification, err := s.q.GetEmailVerification(r.Context(), userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusBadRequest, "no pending verification for this user")
			return
		}
		writeError(w, http.StatusInternalServerError, "could not load verification")
		return
	}

	if verification.Attempts >= maxOTPAttempts {
		_ = s.q.DeleteEmailVerification(r.Context(), userID)
		writeError(w, http.StatusBadRequest, "too many incorrect attempts; please request a new code")
		return
	}

	if time.Now().After(verification.ExpiresAt.Time) {
		_ = s.q.DeleteEmailVerification(r.Context(), userID)
		writeError(w, http.StatusBadRequest, "verification code has expired; please request a new one")
		return
	}

	if hashOTP(req.Code) != verification.CodeHash {
		_ = s.q.IncrementVerificationAttempts(r.Context(), userID)
		remaining := maxOTPAttempts - int(verification.Attempts) - 1
		writeError(w, http.StatusUnauthorized, fmt.Sprintf("incorrect code; %d attempt(s) remaining", remaining))
		return
	}

	// Code is correct — mark verified and clean up.
	if err := s.q.MarkUserVerified(r.Context(), userID); err != nil {
		writeError(w, http.StatusInternalServerError, "could not mark user as verified")
		return
	}
	_ = s.q.DeleteEmailVerification(r.Context(), userID)

	user, err := s.q.GetUserByID(r.Context(), userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not load user")
		return
	}

	token, err := auth.IssueToken(s.cfg.JWTSecret, userID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not issue token")
		return
	}

	writeJSON(w, http.StatusOK, authResponse{
		Token: token,
		User:  authUser{ID: userID.String(), Username: user.Username},
	})
}

// --- Resend verification ---

type resendVerificationRequest struct {
	UserID string `json:"user_id"`
}

func (s *Server) handleResendVerification(w http.ResponseWriter, r *http.Request) {
	var req resendVerificationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	userID, err := uuid.Parse(req.UserID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user_id")
		return
	}

	user, err := s.q.GetUserByID(r.Context(), userID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Don't leak whether the user exists.
			writeJSON(w, http.StatusOK, map[string]string{"message": "If that account exists, a new code has been sent."})
			return
		}
		writeError(w, http.StatusInternalServerError, "could not load user")
		return
	}

	if user.VerifiedAt.Valid {
		writeError(w, http.StatusBadRequest, "this account is already verified")
		return
	}

	if err := s.issueAndSendOTP(r, user.ID, user.Email, user.Username); err != nil {
		log.Printf("resend: issueAndSendOTP for %s: %v", user.Email, err)
		writeError(w, http.StatusInternalServerError, "could not send verification email")
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"message": "A new verification code has been sent to your email."})
}

// --- Login ---

type loginRequest struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (s *Server) handleLogin(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON body")
		return
	}

	user, err := s.q.GetUserByEmail(r.Context(), strings.TrimSpace(req.Email))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusUnauthorized, "invalid credentials")
			return
		}
		writeError(w, http.StatusInternalServerError, "could not look up user")
		return
	}

	if !auth.CheckPassword(user.PasswordHash, req.Password) {
		writeError(w, http.StatusUnauthorized, "invalid credentials")
		return
	}

	if !user.VerifiedAt.Valid {
		writeError(w, http.StatusForbidden, "email address not verified; please check your inbox for a verification code")
		return
	}

	token, err := auth.IssueToken(s.cfg.JWTSecret, user.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not issue token")
		return
	}

	writeJSON(w, http.StatusOK, authResponse{
		Token: token,
		User:  authUser{ID: user.ID.String(), Username: user.Username},
	})
}
