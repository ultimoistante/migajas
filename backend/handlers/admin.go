package handlers

import (
	"database/sql"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jmoiron/sqlx"
	"migajas/backend/middleware"
	"migajas/backend/models"
	"migajas/backend/utils"
)

type AdminHandler struct {
	db *sqlx.DB
}

func NewAdminHandler(db *sqlx.DB) *AdminHandler {
	return &AdminHandler{db: db}
}

// requireAdmin looks up the calling user and returns 403 if not admin.
// Returns true if the caller is allowed to proceed, false if the response was already written.
func (h *AdminHandler) requireAdmin(w http.ResponseWriter, r *http.Request) bool {
	userID := middleware.UserIDFromContext(r.Context())
	var isAdmin bool
	if err := h.db.QueryRow(`SELECT is_admin FROM users WHERE id=?`, userID).Scan(&isAdmin); err != nil {
		jsonError(w, http.StatusUnauthorized, "user not found")
		return false
	}
	if !isAdmin {
		jsonError(w, http.StatusForbidden, "admin access required")
		return false
	}
	return true
}

// ── List users ────────────────────────────────────────────────────────────────

func (h *AdminHandler) ListUsers(w http.ResponseWriter, r *http.Request) {
	if !h.requireAdmin(w, r) {
		return
	}
	var users []models.User
	if err := h.db.Select(&users, `SELECT * FROM users ORDER BY created_at ASC`); err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to fetch users")
		return
	}
	result := make([]models.UserPublic, len(users))
	for i, u := range users {
		result[i] = u.Public()
	}
	jsonResponse(w, http.StatusOK, result)
}

// ── Create user ───────────────────────────────────────────────────────────────

type adminCreateUserRequest struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Password string `json:"password"`
	IsAdmin  bool   `json:"is_admin"`
}

func (h *AdminHandler) CreateUser(w http.ResponseWriter, r *http.Request) {
	if !h.requireAdmin(w, r) {
		return
	}
	var req adminCreateUserRequest
	if err := decodeJSON(r, &req); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	req.Username = strings.TrimSpace(req.Username)
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))

	if err := validateRegister(registerRequest{
		Username: req.Username,
		Email:    req.Email,
		Password: req.Password,
	}); err != nil {
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
		`INSERT INTO users (id, username, email, password_hash, is_admin) VALUES (?,?,?,?,?)`,
		id, req.Username, req.Email, hash, req.IsAdmin,
	)
	if err != nil {
		if isUniqueConstraintError(err) {
			jsonError(w, http.StatusConflict, "username or email already taken")
			return
		}
		jsonError(w, http.StatusInternalServerError, "failed to create user")
		return
	}

	var newUser models.User
	if err := h.db.Get(&newUser, `SELECT * FROM users WHERE id=?`, id); err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to fetch created user")
		return
	}
	jsonResponse(w, http.StatusCreated, newUser.Public())
}

// ── Update user ───────────────────────────────────────────────────────────────

type adminUpdateUserRequest struct {
	Username *string `json:"username"`
	Email    *string `json:"email"`
	Password *string `json:"password"`
	IsAdmin  *bool   `json:"is_admin"`
}

func (h *AdminHandler) UpdateUser(w http.ResponseWriter, r *http.Request) {
	if !h.requireAdmin(w, r) {
		return
	}
	targetID := chi.URLParam(r, "id")

	var target models.User
	if err := h.db.Get(&target, `SELECT * FROM users WHERE id=?`, targetID); errors.Is(err, sql.ErrNoRows) {
		jsonError(w, http.StatusNotFound, "user not found")
		return
	} else if err != nil {
		jsonError(w, http.StatusInternalServerError, "database error")
		return
	}

	var req adminUpdateUserRequest
	if err := decodeJSON(r, &req); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Username != nil {
		u := strings.TrimSpace(*req.Username)
		if len(u) < 3 || len(u) > 32 {
			jsonError(w, http.StatusUnprocessableEntity, "username must be 3-32 characters")
			return
		}
		target.Username = u
	}
	if req.Email != nil {
		e := strings.ToLower(strings.TrimSpace(*req.Email))
		if !strings.Contains(e, "@") {
			jsonError(w, http.StatusUnprocessableEntity, "invalid email address")
			return
		}
		target.Email = e
	}
	if req.IsAdmin != nil {
		target.IsAdmin = *req.IsAdmin
	}

	var newHash string
	if req.Password != nil && *req.Password != "" {
		if len(*req.Password) < 8 {
			jsonError(w, http.StatusUnprocessableEntity, "password must be at least 8 characters")
			return
		}
		h, err := utils.HashPassword(*req.Password)
		if err != nil {
			jsonError(w, http.StatusInternalServerError, "failed to hash password")
			return
		}
		newHash = h
	} else {
		newHash = target.PasswordHash
	}

	_, err := h.db.Exec(
		`UPDATE users SET username=?, email=?, password_hash=?, is_admin=?, updated_at=? WHERE id=?`,
		target.Username, target.Email, newHash, target.IsAdmin, time.Now(), targetID,
	)
	if err != nil {
		if isUniqueConstraintError(err) {
			jsonError(w, http.StatusConflict, "username or email already taken")
			return
		}
		jsonError(w, http.StatusInternalServerError, "failed to update user")
		return
	}

	var updated models.User
	h.db.Get(&updated, `SELECT * FROM users WHERE id=?`, targetID)
	jsonResponse(w, http.StatusOK, updated.Public())
}

// ── Delete user ───────────────────────────────────────────────────────────────

func (h *AdminHandler) DeleteUser(w http.ResponseWriter, r *http.Request) {
	callerID := middleware.UserIDFromContext(r.Context())
	if !h.requireAdmin(w, r) {
		return
	}
	targetID := chi.URLParam(r, "id")
	if targetID == callerID {
		jsonError(w, http.StatusBadRequest, "cannot delete your own account")
		return
	}

	var exists bool
	if err := h.db.QueryRow(`SELECT COUNT(*)>0 FROM users WHERE id=?`, targetID).Scan(&exists); err != nil || !exists {
		jsonError(w, http.StatusNotFound, "user not found")
		return
	}

	if _, err := h.db.Exec(`DELETE FROM users WHERE id=?`, targetID); err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to delete user")
		return
	}
	jsonResponse(w, http.StatusOK, map[string]string{"message": "user deleted"})
}
