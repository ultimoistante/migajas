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

type NotesHandler struct {
	db *sqlx.DB
}

func NewNotesHandler(db *sqlx.DB) *NotesHandler {
	return &NotesHandler{db: db}
}

// ── List notes ────────────────────────────────────────────────────────────────

func (h *NotesHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())

	var notes []models.Note
	if err := h.db.Select(&notes,
		`SELECT n.id, n.user_id, n.title, n.body, n.is_secret, n.body_nonce, n.is_pinned, n.color, n.created_at, n.updated_at,
		        COUNT(a.id) AS attachment_count
		 FROM notes n
		 LEFT JOIN attachments a ON a.note_id = n.id
		 WHERE n.user_id=?
		 GROUP BY n.id
		 ORDER BY n.is_pinned DESC, n.updated_at DESC`,
		userID,
	); err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to fetch notes")
		return
	}

	result := make([]models.NoteResponse, len(notes))
	for i, n := range notes {
		result[i] = n.ToResponse(nil) // secret notes: body=nil
	}
	jsonResponse(w, http.StatusOK, result)
}

// ── Get single note ───────────────────────────────────────────────────────────

func (h *NotesHandler) Get(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	noteID := chi.URLParam(r, "id")

	note, err := h.getNote(noteID, userID)
	if errors.Is(err, sql.ErrNoRows) {
		jsonError(w, http.StatusNotFound, "note not found")
		return
	}
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "database error")
		return
	}

	jsonResponse(w, http.StatusOK, note.ToResponse(nil))
}

// ── Create note ───────────────────────────────────────────────────────────────

type createNoteRequest struct {
	Title      string `json:"title"`
	Body       string `json:"body"`
	IsSecret   bool   `json:"is_secret"`
	Credential string `json:"credential"` // required when is_secret=true
	Color      string `json:"color"`
}

func (h *NotesHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	var req createNoteRequest
	if err := decodeJSON(r, &req); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	req.Title = strings.TrimSpace(req.Title)

	id, err := utils.RandomID(16)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to generate id")
		return
	}

	body := req.Body
	var bodyNonce *string

	if req.IsSecret {
		if req.Credential == "" {
			jsonError(w, http.StatusUnprocessableEntity, "credential required for secret notes")
			return
		}
		// Verify that the user has a vault credential set and that it matches
		salt, err := h.getUserVaultSaltAndVerify(userID, req.Credential)
		if err != nil {
			jsonError(w, http.StatusUnauthorized, "invalid vault credential")
			return
		}
		encrypted, nonce, err := utils.EncryptBody(req.Body, req.Credential, salt)
		if err != nil {
			jsonError(w, http.StatusInternalServerError, "failed to encrypt note")
			return
		}
		body = encrypted
		bodyNonce = &nonce
	}

	_, err = h.db.Exec(
		`INSERT INTO notes (id, user_id, title, body, is_secret, body_nonce, color)
		 VALUES (?,?,?,?,?,?,?)`,
		id, userID, req.Title, body, req.IsSecret, bodyNonce, req.Color,
	)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to create note")
		return
	}

	note, _ := h.getNote(id, userID)
	jsonResponse(w, http.StatusCreated, note.ToResponse(nil))
}

// ── Update note ───────────────────────────────────────────────────────────────

type updateNoteRequest struct {
	Title      *string `json:"title"`
	Body       *string `json:"body"`
	IsSecret   *bool   `json:"is_secret"`
	Credential string  `json:"credential"` // required when changing secret body or toggling is_secret
	IsPinned   *bool   `json:"is_pinned"`
	Color      *string `json:"color"`
}

func (h *NotesHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	noteID := chi.URLParam(r, "id")

	note, err := h.getNote(noteID, userID)
	if errors.Is(err, sql.ErrNoRows) {
		jsonError(w, http.StatusNotFound, "note not found")
		return
	}
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "database error")
		return
	}

	var req updateNoteRequest
	if err := decodeJSON(r, &req); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Title != nil {
		note.Title = strings.TrimSpace(*req.Title)
	}
	if req.IsPinned != nil {
		note.IsPinned = *req.IsPinned
	}
	if req.Color != nil {
		note.Color = *req.Color
	}

	// Handle is_secret toggling
	if req.IsSecret != nil && *req.IsSecret != note.IsSecret {
		if req.Credential == "" {
			jsonError(w, http.StatusUnprocessableEntity, "credential required to change secret status")
			return
		}
		salt, err := h.getUserVaultSaltAndVerify(userID, req.Credential)
		if err != nil {
			jsonError(w, http.StatusUnauthorized, "invalid vault credential")
			return
		}
		if *req.IsSecret {
			// Non-secret → secret: encrypt current body
			currentBody := note.Body
			if req.Body != nil {
				currentBody = *req.Body
			}
			encrypted, nonce, err := utils.EncryptBody(currentBody, req.Credential, salt)
			if err != nil {
				jsonError(w, http.StatusInternalServerError, "failed to encrypt note")
				return
			}
			note.Body = encrypted
			note.BodyNonce = &nonce
			note.IsSecret = true
		} else {
			// Secret → non-secret: decrypt body
			if note.BodyNonce == nil {
				note.Body = ""
			} else {
				plain, err := utils.DecryptBody(note.Body, *note.BodyNonce, req.Credential, salt)
				if err != nil {
					jsonError(w, http.StatusUnauthorized, "invalid vault credential")
					return
				}
				note.Body = plain
			}
			note.BodyNonce = nil
			note.IsSecret = false
		}
	} else if req.Body != nil {
		// Regular body update (no secret toggle)
		if note.IsSecret {
			if req.Credential == "" {
				jsonError(w, http.StatusUnprocessableEntity, "credential required to update secret note body")
				return
			}
			salt, err := h.getUserVaultSaltAndVerify(userID, req.Credential)
			if err != nil {
				jsonError(w, http.StatusUnauthorized, "invalid vault credential")
				return
			}
			encrypted, nonce, err := utils.EncryptBody(*req.Body, req.Credential, salt)
			if err != nil {
				jsonError(w, http.StatusInternalServerError, "failed to encrypt note")
				return
			}
			note.Body = encrypted
			note.BodyNonce = &nonce
		} else {
			note.Body = *req.Body
		}
	}

	now := time.Now().UTC().Format(time.RFC3339)
	_, err = h.db.Exec(
		`UPDATE notes SET title=?, body=?, is_secret=?, body_nonce=?, is_pinned=?, color=?, updated_at=?
		 WHERE id=? AND user_id=?`,
		note.Title, note.Body, note.IsSecret, note.BodyNonce, note.IsPinned, note.Color, now,
		noteID, userID,
	)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to update note")
		return
	}

	updated, _ := h.getNote(noteID, userID)
	jsonResponse(w, http.StatusOK, updated.ToResponse(nil))
}

// ── Delete note ───────────────────────────────────────────────────────────────

func (h *NotesHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	noteID := chi.URLParam(r, "id")

	res, err := h.db.Exec(`DELETE FROM notes WHERE id=? AND user_id=?`, noteID, userID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to delete note")
		return
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		jsonError(w, http.StatusNotFound, "note not found")
		return
	}
	jsonResponse(w, http.StatusOK, map[string]string{"message": "note deleted"})
}

// ── Unlock secret note ────────────────────────────────────────────────────────

type unlockRequest struct {
	Credential string `json:"credential"`
}

func (h *NotesHandler) Unlock(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	noteID := chi.URLParam(r, "id")

	note, err := h.getNote(noteID, userID)
	if errors.Is(err, sql.ErrNoRows) {
		jsonError(w, http.StatusNotFound, "note not found")
		return
	}
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "database error")
		return
	}
	if !note.IsSecret {
		jsonError(w, http.StatusBadRequest, "note is not secret")
		return
	}

	var req unlockRequest
	if err := decodeJSON(r, &req); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	salt, err := h.getUserVaultSaltAndVerify(userID, req.Credential)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, "invalid vault credential")
		return
	}

	if note.BodyNonce == nil {
		// Note has no content yet - return empty body
		empty := ""
		jsonResponse(w, http.StatusOK, note.ToResponse(&empty))
		return
	}

	plaintext, err := utils.DecryptBody(note.Body, *note.BodyNonce, req.Credential, salt)
	if err != nil {
		jsonError(w, http.StatusUnauthorized, "invalid vault credential")
		return
	}

	jsonResponse(w, http.StatusOK, note.ToResponse(&plaintext))
}

// ── helpers ───────────────────────────────────────────────────────────────────

func (h *NotesHandler) getNote(noteID, userID string) (*models.Note, error) {
	var note models.Note
	err := h.db.Get(&note,
		`SELECT n.id, n.user_id, n.title, n.body, n.is_secret, n.body_nonce, n.is_pinned, n.color, n.created_at, n.updated_at,
		        COUNT(a.id) AS attachment_count
		 FROM notes n
		 LEFT JOIN attachments a ON a.note_id = n.id
		 WHERE n.id=? AND n.user_id=?
		 GROUP BY n.id`, noteID, userID,
	)
	return &note, err
}

// getUserVaultSaltAndVerify checks that the provided credential matches the stored
// vault PIN or vault password for the user and returns the vault salt.
func (h *NotesHandler) getUserVaultSaltAndVerify(userID, credential string) (string, error) {
	var row struct {
		VaultPinHash  *string `db:"vault_pin_hash"`
		VaultPassHash *string `db:"vault_pass_hash"`
		VaultSalt     *string `db:"vault_salt"`
	}
	if err := h.db.Get(&row,
		`SELECT vault_pin_hash, vault_pass_hash, vault_salt FROM users WHERE id=?`, userID,
	); err != nil {
		return "", err
	}
	if row.VaultSalt == nil {
		return "", errors.New("no vault credential configured")
	}
	if row.VaultPinHash != nil && utils.CheckPassword(credential, *row.VaultPinHash) {
		return *row.VaultSalt, nil
	}
	if row.VaultPassHash != nil && utils.CheckPassword(credential, *row.VaultPassHash) {
		return *row.VaultSalt, nil
	}
	return "", errors.New("invalid credential")
}
