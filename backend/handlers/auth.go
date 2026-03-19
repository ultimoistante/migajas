package handlers

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"errors"
	"net/http"
	"strings"
	"time"
	"unicode"

	"github.com/jmoiron/sqlx"
	"migajas/backend/config"
	"migajas/backend/middleware"
	"migajas/backend/models"
	"migajas/backend/utils"
)

type AuthHandler struct {
	db  *sqlx.DB
	cfg *config.Config
}

func NewAuthHandler(db *sqlx.DB, cfg *config.Config) *AuthHandler {
	return &AuthHandler{db: db, cfg: cfg}
}

// ── Register ──────────────────────────────────────────────────────────────────

type registerRequest struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := decodeJSON(r, &req); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	req.Username = strings.TrimSpace(req.Username)
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))

	// Self-registration check
	if !AllowSelfRegistration(h.db) {
		jsonError(w, http.StatusForbidden, "self-registration is disabled on this server")
		return
	}

	if err := validateRegister(req); err != nil {
		jsonError(w, http.StatusUnprocessableEntity, err.Error())
		return
	}

	hash, err := utils.HashPassword(req.Password)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to hash password")
		return
	}
	id, err := utils.RandomID(16)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to generate id")
		return
	}

	_, err = h.db.Exec(
		`INSERT INTO users (id, username, email, password_hash) VALUES (?,?,?,?)`,
		id, req.Username, req.Email, hash,
	)
	if err != nil {
		if isUniqueConstraintError(err) {
			jsonError(w, http.StatusConflict, "username or email already taken")
			return
		}
		jsonError(w, http.StatusInternalServerError, "failed to create user")
		return
	}

	jsonResponse(w, http.StatusCreated, map[string]string{"message": "account created"})
}

func validateRegister(req registerRequest) error {
	if len(req.Username) < 3 || len(req.Username) > 32 {
		return errors.New("username must be 3-32 characters")
	}
	for _, c := range req.Username {
		if !unicode.IsLetter(c) && !unicode.IsDigit(c) && c != '_' && c != '-' {
			return errors.New("username may only contain letters, digits, _ or -")
		}
	}
	if !strings.Contains(req.Email, "@") {
		return errors.New("invalid email address")
	}
	if len(req.Password) < 8 {
		return errors.New("password must be at least 8 characters")
	}
	return nil
}

// ── Login ─────────────────────────────────────────────────────────────────────

type loginRequest struct {
	UsernameOrEmail string `json:"username_or_email"`
	Password        string `json:"password"`
}

type loginResponse struct {
	AccessToken  string            `json:"access_token"`
	User         models.UserPublic `json:"user"`
	RefreshToken string            `json:"refresh_token,omitempty"` // non-empty only for Capacitor clients
}

func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := decodeJSON(r, &req); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	req.UsernameOrEmail = strings.TrimSpace(req.UsernameOrEmail)

	var user models.User
	err := h.db.Get(&user,
		`SELECT * FROM users WHERE username=? OR email=? LIMIT 1`,
		req.UsernameOrEmail, strings.ToLower(req.UsernameOrEmail),
	)
	if errors.Is(err, sql.ErrNoRows) || !utils.CheckPassword(req.Password, user.PasswordHash) {
		jsonError(w, http.StatusUnauthorized, "invalid credentials")
		return
	}
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "database error")
		return
	}

	accessToken, err := utils.GenerateAccessToken(user.ID, user.Username, h.cfg.JWTSecret, h.cfg.AccessTokenTTL)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to generate token")
		return
	}

	// Refresh token — also capture raw token for Capacitor clients that cannot use httpOnly cookies
	rawRefreshToken, err := h.issueRefreshTokenRaw(w, user.ID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to issue refresh token")
		return
	}

	resp := loginResponse{
		AccessToken: accessToken,
		User:        user.Public(),
	}
	// Only expose the raw token to Capacitor clients (WebView cannot use httpOnly cookies cross-origin)
	if r.Header.Get("X-Client-Type") == "capacitor" {
		resp.RefreshToken = rawRefreshToken
	}

	jsonResponse(w, http.StatusOK, resp)
}

// ── Refresh ───────────────────────────────────────────────────────────────────

func (h *AuthHandler) Refresh(w http.ResponseWriter, r *http.Request) {
	var rawToken string

	// Prefer httpOnly cookie (web clients); fall back to request body (Capacitor clients)
	cookie, cookieErr := r.Cookie("refresh_token")
	if cookieErr == nil {
		rawToken = cookie.Value
	} else {
		// Try JSON body: { "refresh_token": "..." }
		var body struct {
			RefreshToken string `json:"refresh_token"`
		}
		// decodeJSON reads up to EOF — safe to ignore error when body is empty
		_ = decodeJSON(r, &body)
		rawToken = body.RefreshToken
	}

	if rawToken == "" {
		// No token by any means — not an error, just no active session
		w.WriteHeader(http.StatusNoContent)
		return
	}
	tokenHash := hashToken(rawToken)

	var row struct {
		ID        string    `db:"id"`
		UserID    string    `db:"user_id"`
		ExpiresAt time.Time `db:"expires_at"`
	}
	err := h.db.Get(&row,
		`SELECT id, user_id, expires_at FROM refresh_tokens WHERE token_hash=?`, tokenHash,
	)
	if errors.Is(err, sql.ErrNoRows) || time.Now().After(row.ExpiresAt) {
		jsonError(w, http.StatusUnauthorized, "invalid or expired refresh token")
		return
	}
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "database error")
		return
	}

	// Rotate: delete old token
	h.db.Exec(`DELETE FROM refresh_tokens WHERE id=?`, row.ID)

	var user models.User
	if err := h.db.Get(&user, `SELECT * FROM users WHERE id=?`, row.UserID); err != nil {
		jsonError(w, http.StatusUnauthorized, "user not found")
		return
	}

	accessToken, err := utils.GenerateAccessToken(user.ID, user.Username, h.cfg.JWTSecret, h.cfg.AccessTokenTTL)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to generate token")
		return
	}
	newRaw, err := h.issueRefreshTokenRaw(w, user.ID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to issue refresh token")
		return
	}

	resp := map[string]string{"access_token": accessToken}
	if r.Header.Get("X-Client-Type") == "capacitor" {
		resp["refresh_token"] = newRaw
	}
	jsonResponse(w, http.StatusOK, resp)
}

// ── Logout ────────────────────────────────────────────────────────────────────

func (h *AuthHandler) Logout(w http.ResponseWriter, r *http.Request) {
	cookie, err := r.Cookie("refresh_token")
	if err == nil {
		tokenHash := hashToken(cookie.Value)
		h.db.Exec(`DELETE FROM refresh_tokens WHERE token_hash=?`, tokenHash)
	}
	http.SetCookie(w, &http.Cookie{
		Name:     "refresh_token",
		Value:    "",
		MaxAge:   -1,
		HttpOnly: true,
		SameSite: http.SameSiteStrictMode,
		Path:     "/",
	})
	jsonResponse(w, http.StatusOK, map[string]string{"message": "logged out"})
}

// ── Me ────────────────────────────────────────────────────────────────────────

func (h *AuthHandler) Me(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	var user models.User
	if err := h.db.Get(&user, `SELECT * FROM users WHERE id=?`, userID); err != nil {
		jsonError(w, http.StatusNotFound, "user not found")
		return
	}
	jsonResponse(w, http.StatusOK, user.Public())
}

// ── Vault setup ───────────────────────────────────────────────────────────────

type vaultSetupRequest struct {
	Type       string `json:"type"`       // "pin" or "password"
	Credential string `json:"credential"` // the PIN or password value
}

func (h *AuthHandler) SetupVault(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	var req vaultSetupRequest
	if err := decodeJSON(r, &req); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Type != "pin" && req.Type != "password" {
		jsonError(w, http.StatusUnprocessableEntity, "type must be 'pin' or 'password'")
		return
	}
	if req.Type == "pin" {
		for _, c := range req.Credential {
			if c < '0' || c > '9' {
				jsonError(w, http.StatusUnprocessableEntity, "PIN must be numeric")
				return
			}
		}
		if len(req.Credential) < 4 || len(req.Credential) > 8 {
			jsonError(w, http.StatusUnprocessableEntity, "PIN must be 4-8 digits")
			return
		}
	} else {
		if len(req.Credential) < 6 {
			jsonError(w, http.StatusUnprocessableEntity, "vault password must be at least 6 characters")
			return
		}
	}

	credHash, err := utils.HashPassword(req.Credential)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to hash credential")
		return
	}
	salt, err := utils.NewSalt()
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to generate salt")
		return
	}

	var query string
	if req.Type == "pin" {
		query = `UPDATE users SET vault_pin_hash=?, vault_salt=?, updated_at=strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id=?`
	} else {
		query = `UPDATE users SET vault_pass_hash=?, vault_salt=?, updated_at=strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id=?`
	}
	if _, err := h.db.Exec(query, credHash, salt, userID); err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to save vault credential")
		return
	}

	jsonResponse(w, http.StatusOK, map[string]string{"message": "vault credential set"})
}

// ── Vault rotate ──────────────────────────────────────────────────────────────

type vaultRotateRequest struct {
	Type          string `json:"type"`           // "pin" or "password"
	OldCredential string `json:"old_credential"` // current credential to verify & decrypt
	NewCredential string `json:"new_credential"` // replacement credential to re-encrypt with
}

// RotateVault verifies the old vault credential, re-encrypts every secret note
// for the user with a fresh key derived from the new credential, then persists
// the new hash and salt — all inside a single SQLite transaction so nothing is
// left in a half-migrated state on failure.
func (h *AuthHandler) RotateVault(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())

	var req vaultRotateRequest
	if err := decodeJSON(r, &req); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Type != "pin" && req.Type != "password" {
		jsonError(w, http.StatusUnprocessableEntity, "type must be 'pin' or 'password'")
		return
	}
	if req.OldCredential == "" {
		jsonError(w, http.StatusUnprocessableEntity, "old_credential is required")
		return
	}
	// Validate new credential format
	if req.Type == "pin" {
		for _, c := range req.NewCredential {
			if c < '0' || c > '9' {
				jsonError(w, http.StatusUnprocessableEntity, "PIN must be numeric")
				return
			}
		}
		if len(req.NewCredential) < 4 || len(req.NewCredential) > 8 {
			jsonError(w, http.StatusUnprocessableEntity, "PIN must be 4-8 digits")
			return
		}
	} else {
		if len(req.NewCredential) < 6 {
			jsonError(w, http.StatusUnprocessableEntity, "vault password must be at least 6 characters")
			return
		}
	}

	// Load user to verify old credential and obtain current salt
	var user models.User
	if err := h.db.Get(&user, `SELECT * FROM users WHERE id=?`, userID); err != nil {
		jsonError(w, http.StatusInternalServerError, "database error")
		return
	}
	if user.VaultSalt == nil {
		jsonError(w, http.StatusUnprocessableEntity, "no vault credential configured; use initial setup instead")
		return
	}

	validOld := false
	if user.VaultPinHash != nil && utils.CheckPassword(req.OldCredential, *user.VaultPinHash) {
		validOld = true
	}
	if !validOld && user.VaultPassHash != nil && utils.CheckPassword(req.OldCredential, *user.VaultPassHash) {
		validOld = true
	}
	if !validOld {
		jsonError(w, http.StatusUnauthorized, "old credential is incorrect")
		return
	}

	// Fetch all encrypted secret notes for this user
	type secretNote struct {
		ID        string `db:"id"`
		Body      string `db:"body"`
		BodyNonce string `db:"body_nonce"`
	}
	var notes []secretNote
	if err := h.db.Select(&notes,
		`SELECT id, body, body_nonce FROM notes WHERE user_id=? AND is_secret=1`,
		userID,
	); err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to fetch secret notes")
		return
	}

	// Derive old AES key
	oldSalt := *user.VaultSalt
	oldKey, err := utils.DeriveKey(req.OldCredential, oldSalt)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to derive old key")
		return
	}

	// Generate new salt and derive new AES key
	newSalt, err := utils.NewSalt()
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to generate new salt")
		return
	}
	newKey, err := utils.DeriveKey(req.NewCredential, newSalt)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to derive new key")
		return
	}

	// Re-encrypt each note body
	type reencryptedNote struct {
		id        string
		newBody   string
		newNonce  string
	}
	reencrypted := make([]reencryptedNote, 0, len(notes))
	for _, n := range notes {
		plaintext, err := utils.DecryptBodyWithKey(n.Body, n.BodyNonce, oldKey)
		if err != nil {
			jsonError(w, http.StatusInternalServerError, "failed to decrypt note "+n.ID+": "+err.Error())
			return
		}
		newBody, newNonce, err := utils.EncryptBodyWithKey(plaintext, newKey)
		if err != nil {
			jsonError(w, http.StatusInternalServerError, "failed to re-encrypt note "+n.ID)
			return
		}
		reencrypted = append(reencrypted, reencryptedNote{id: n.ID, newBody: newBody, newNonce: newNonce})
	}

	// Hash new credential
	newCredHash, err := utils.HashPassword(req.NewCredential)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to hash new credential")
		return
	}

	// Commit everything atomically
	tx, err := h.db.Beginx()
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to begin transaction")
		return
	}
	defer func() {
		if err != nil {
			tx.Rollback()
		}
	}()

	// Update each re-encrypted note
	for _, rn := range reencrypted {
		if _, err = tx.Exec(
			`UPDATE notes SET body=?, body_nonce=?, updated_at=strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id=?`,
			rn.newBody, rn.newNonce, rn.id,
		); err != nil {
			jsonError(w, http.StatusInternalServerError, "failed to update note during re-encryption")
			return
		}
	}

	// Update user vault credential
	var userQuery string
	if req.Type == "pin" {
		userQuery = `UPDATE users SET vault_pin_hash=?, vault_pass_hash=NULL, vault_salt=?, updated_at=strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id=?`
	} else {
		userQuery = `UPDATE users SET vault_pass_hash=?, vault_pin_hash=NULL, vault_salt=?, updated_at=strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id=?`
	}
	if _, err = tx.Exec(userQuery, newCredHash, newSalt, userID); err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to update vault credential")
		return
	}

	if err = tx.Commit(); err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to commit transaction")
		return
	}

	jsonResponse(w, http.StatusOK, map[string]string{"message": "vault credential rotated"})
}

// ── helpers ───────────────────────────────────────────────────────────────────

// issueRefreshTokenRaw persists a refresh token, sets the httpOnly cookie,
// and returns the raw token value so callers can embed it in the response body
// for clients (e.g. Capacitor) that cannot use cross-origin httpOnly cookies.
func (h *AuthHandler) issueRefreshTokenRaw(w http.ResponseWriter, userID string) (string, error) {
	raw, err := utils.RandomID(32)
	if err != nil {
		return "", err
	}
	tokenHash := hashToken(raw)
	id, err := utils.RandomID(16)
	if err != nil {
		return "", err
	}
	expiresAt := time.Now().Add(time.Duration(h.cfg.RefreshTokenTTL) * 24 * time.Hour)
	_, err = h.db.Exec(
		`INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at) VALUES (?,?,?,?)`,
		id, userID, tokenHash, expiresAt.UTC().Format(time.RFC3339),
	)
	if err != nil {
		return "", err
	}
	http.SetCookie(w, &http.Cookie{
		Name:     "refresh_token",
		Value:    raw,
		Expires:  expiresAt,
		HttpOnly: true,
		SameSite: http.SameSiteStrictMode,
		Path:     "/",
	})
	return raw, nil
}

func hashToken(raw string) string {
	h := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(h[:])
}

func isUniqueConstraintError(err error) bool {
	return strings.Contains(err.Error(), "UNIQUE constraint failed")
}
