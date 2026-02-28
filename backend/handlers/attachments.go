package handlers

import (
	"database/sql"
	"errors"
	"io"
	"mime"
	"net/http"
	"os"
	"path/filepath"

	"github.com/go-chi/chi/v5"
	"github.com/jmoiron/sqlx"

	"migajas/backend/middleware"
	"migajas/backend/models"
	"migajas/backend/utils"
)

const maxUploadSize = 50 << 20 // 50 MB

type AttachmentsHandler struct {
	db             *sqlx.DB
	attachmentsDir string
}

func NewAttachmentsHandler(db *sqlx.DB, attachmentsDir string) *AttachmentsHandler {
	if err := os.MkdirAll(attachmentsDir, 0o755); err != nil {
		panic("attachments: cannot create storage directory: " + err.Error())
	}
	return &AttachmentsHandler{db: db, attachmentsDir: attachmentsDir}
}

// ── Upload ────────────────────────────────────────────────────────────────────

// POST /api/notes/{id}/attachments
func (h *AttachmentsHandler) Upload(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	noteID := chi.URLParam(r, "id")

	// Verify note ownership
	var ownerID string
	if err := h.db.QueryRow(`SELECT user_id FROM notes WHERE id=?`, noteID).Scan(&ownerID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			jsonError(w, http.StatusNotFound, "note not found")
		} else {
			jsonError(w, http.StatusInternalServerError, "database error")
		}
		return
	}
	if ownerID != userID {
		jsonError(w, http.StatusForbidden, "forbidden")
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, maxUploadSize+1024)
	if err := r.ParseMultipartForm(maxUploadSize); err != nil {
		jsonError(w, http.StatusBadRequest, "file too large or invalid form")
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		jsonError(w, http.StatusBadRequest, "missing file field")
		return
	}
	defer file.Close()

	// Generate IDs
	attID, err := utils.RandomID(16)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to generate id")
		return
	}
	storedID, err := utils.RandomID(32)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to generate storage name")
		return
	}

	// Detect mime type (trust the browser header, fallback to extension sniff)
	mimeType := header.Header.Get("Content-Type")
	if mimeType == "" || mimeType == "application/octet-stream" {
		if ext := filepath.Ext(header.Filename); ext != "" {
			if t := mime.TypeByExtension(ext); t != "" {
				mimeType = t
			}
		}
	}
	if mimeType == "" {
		mimeType = "application/octet-stream"
	}

	// Write to disk
	storedName := storedID + filepath.Ext(header.Filename)
	dstPath := filepath.Join(h.attachmentsDir, storedName)
	dst, err := os.Create(dstPath)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to store file")
		return
	}
	written, err := io.Copy(dst, file)
	dst.Close()
	if err != nil {
		os.Remove(dstPath)
		jsonError(w, http.StatusInternalServerError, "failed to write file")
		return
	}

	// Insert DB row
	_, err = h.db.Exec(
		`INSERT INTO attachments (id, note_id, user_id, stored_name, original_name, mime_type, size)
		 VALUES (?,?,?,?,?,?,?)`,
		attID, noteID, userID, storedName, header.Filename, mimeType, written,
	)
	if err != nil {
		os.Remove(dstPath)
		jsonError(w, http.StatusInternalServerError, "failed to save attachment record")
		return
	}

	var att models.Attachment
	h.db.Get(&att, `SELECT * FROM attachments WHERE id=?`, attID)
	jsonResponse(w, http.StatusCreated, att.ToResponse())
}

// ── List ──────────────────────────────────────────────────────────────────────

// GET /api/notes/{id}/attachments
func (h *AttachmentsHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	noteID := chi.URLParam(r, "id")

	// Verify note ownership
	var ownerID string
	if err := h.db.QueryRow(`SELECT user_id FROM notes WHERE id=?`, noteID).Scan(&ownerID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			jsonError(w, http.StatusNotFound, "note not found")
		} else {
			jsonError(w, http.StatusInternalServerError, "database error")
		}
		return
	}
	if ownerID != userID {
		jsonError(w, http.StatusForbidden, "forbidden")
		return
	}

	var atts []models.Attachment
	if err := h.db.Select(&atts,
		`SELECT * FROM attachments WHERE note_id=? ORDER BY created_at ASC`, noteID,
	); err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to fetch attachments")
		return
	}

	result := make([]models.AttachmentResponse, len(atts))
	for i, a := range atts {
		result[i] = a.ToResponse()
	}
	jsonResponse(w, http.StatusOK, result)
}

// ── Delete ────────────────────────────────────────────────────────────────────

// DELETE /api/attachments/{id}
func (h *AttachmentsHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	attID := chi.URLParam(r, "id")

	var att models.Attachment
	if err := h.db.Get(&att, `SELECT * FROM attachments WHERE id=?`, attID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			jsonError(w, http.StatusNotFound, "attachment not found")
		} else {
			jsonError(w, http.StatusInternalServerError, "database error")
		}
		return
	}
	if att.UserID != userID {
		jsonError(w, http.StatusForbidden, "forbidden")
		return
	}

	// Delete file from disk
	_ = os.Remove(filepath.Join(h.attachmentsDir, att.StoredName))

	// Delete DB row
	if _, err := h.db.Exec(`DELETE FROM attachments WHERE id=?`, attID); err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to delete attachment record")
		return
	}

	jsonResponse(w, http.StatusOK, map[string]string{"message": "attachment deleted"})
}

// ── Serve ─────────────────────────────────────────────────────────────────────

// GET /api/attachments/{id}/content
func (h *AttachmentsHandler) Serve(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	attID := chi.URLParam(r, "id")

	var att models.Attachment
	if err := h.db.Get(&att, `SELECT * FROM attachments WHERE id=?`, attID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			jsonError(w, http.StatusNotFound, "attachment not found")
		} else {
			jsonError(w, http.StatusInternalServerError, "database error")
		}
		return
	}
	if att.UserID != userID {
		jsonError(w, http.StatusForbidden, "forbidden")
		return
	}

	filePath := filepath.Join(h.attachmentsDir, att.StoredName)
	f, err := os.Open(filePath)
	if err != nil {
		jsonError(w, http.StatusNotFound, "file not found on disk")
		return
	}
	defer f.Close()

	w.Header().Set("Content-Type", att.MimeType)
	w.Header().Set("Content-Disposition", `attachment; filename="`+att.OriginalName+`"`)
	w.Header().Set("X-Content-Type-Options", "nosniff")
	io.Copy(w, f)
}
