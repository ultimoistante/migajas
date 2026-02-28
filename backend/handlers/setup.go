package handlers

import (
	"net/http"
	"strings"

	"github.com/jmoiron/sqlx"
	"migajas/backend/config"
	"migajas/backend/utils"
)

type SetupHandler struct {
	db  *sqlx.DB
	cfg *config.Config
}

func NewSetupHandler(db *sqlx.DB, cfg *config.Config) *SetupHandler {
	return &SetupHandler{db: db, cfg: cfg}
}

// ── Status ────────────────────────────────────────────────────────────────────

type setupStatusResponse struct {
	Initialized          bool `json:"initialized"`
	AllowSelfRegistration bool `json:"allow_self_registration"`
}

// IsInitialized returns true if the app has been set up (admin account exists).
func IsInitialized(db *sqlx.DB) bool {
	var val string
	err := db.Get(&val, `SELECT value FROM settings WHERE key='initialized'`)
	return err == nil && val == "true"
}

// AllowSelfRegistration returns true if users can register themselves.
func AllowSelfRegistration(db *sqlx.DB) bool {
	var val string
	err := db.Get(&val, `SELECT value FROM settings WHERE key='allow_self_registration'`)
	if err != nil {
		return false
	}
	return val == "true"
}

func (h *SetupHandler) Status(w http.ResponseWriter, r *http.Request) {
	jsonResponse(w, http.StatusOK, setupStatusResponse{
		Initialized:          IsInitialized(h.db),
		AllowSelfRegistration: AllowSelfRegistration(h.db),
	})
}

// ── Initialize ────────────────────────────────────────────────────────────────

type setupRequest struct {
	Username             string `json:"username"`
	Email                string `json:"email"`
	Password             string `json:"password"`
	AllowSelfRegistration bool   `json:"allow_self_registration"`
}

func (h *SetupHandler) Initialize(w http.ResponseWriter, r *http.Request) {
	// Reject if already initialized
	if IsInitialized(h.db) {
		jsonError(w, http.StatusConflict, "application already initialized")
		return
	}

	var req setupRequest
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

	tx, err := h.db.Beginx()
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "database error")
		return
	}
	defer tx.Rollback() //nolint:errcheck

	// Create admin user
	_, err = tx.Exec(
		`INSERT INTO users (id, username, email, password_hash, is_admin) VALUES (?,?,?,?,1)`,
		id, req.Username, req.Email, hash,
	)
	if err != nil {
		if isUniqueConstraintError(err) {
			jsonError(w, http.StatusConflict, "username or email already taken")
			return
		}
		jsonError(w, http.StatusInternalServerError, "failed to create admin user")
		return
	}

	// Write settings
	allowReg := "false"
	if req.AllowSelfRegistration {
		allowReg = "true"
	}
	_, err = tx.Exec(
		`INSERT INTO settings (key, value) VALUES ('initialized','true'),('allow_self_registration',?)`,
		allowReg,
	)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to save settings")
		return
	}

	if err := tx.Commit(); err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to commit setup")
		return
	}

	jsonResponse(w, http.StatusCreated, map[string]string{"message": "application initialized"})
}
