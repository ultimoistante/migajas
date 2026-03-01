package handlers

import (
	"database/sql"
	"errors"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/jmoiron/sqlx"
	"migajas/backend/middleware"
	"migajas/backend/models"
	"migajas/backend/utils"
)

type TagsHandler struct {
	db *sqlx.DB
}

func NewTagsHandler(db *sqlx.DB) *TagsHandler {
	return &TagsHandler{db: db}
}

// ── List tags ─────────────────────────────────────────────────────────────────

func (h *TagsHandler) List(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())

	var tags []models.Tag
	if err := h.db.Select(&tags,
		`SELECT id, user_id, name, emoji, created_at FROM tags WHERE user_id=? ORDER BY name`,
		userID,
	); err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to fetch tags")
		return
	}

	result := make([]models.TagPublic, len(tags))
	for i, t := range tags {
		result[i] = t.ToPublic()
	}
	jsonResponse(w, http.StatusOK, result)
}

// ── Create tag ────────────────────────────────────────────────────────────────

type createTagRequest struct {
	Name  string `json:"name"`
	Emoji string `json:"emoji"`
}

func (h *TagsHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())

	var req createTagRequest
	if err := decodeJSON(r, &req); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		jsonError(w, http.StatusUnprocessableEntity, "tag name is required")
		return
	}

	id, err := utils.RandomID(16)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to generate id")
		return
	}

	_, err = h.db.Exec(
		`INSERT INTO tags (id, user_id, name, emoji) VALUES (?,?,?,?)`,
		id, userID, req.Name, req.Emoji,
	)
	if err != nil {
		// Unique constraint violation
		if strings.Contains(err.Error(), "UNIQUE") {
			jsonError(w, http.StatusConflict, "tag name already exists")
			return
		}
		jsonError(w, http.StatusInternalServerError, "failed to create tag")
		return
	}

	var tag models.Tag
	_ = h.db.Get(&tag, `SELECT id, user_id, name, emoji, created_at FROM tags WHERE id=?`, id)
	jsonResponse(w, http.StatusCreated, tag.ToPublic())
}

// ── Update tag ────────────────────────────────────────────────────────────────

type updateTagRequest struct {
	Name  *string `json:"name"`
	Emoji *string `json:"emoji"`
}

func (h *TagsHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	tagID := chi.URLParam(r, "id")

	var tag models.Tag
	err := h.db.Get(&tag, `SELECT id, user_id, name, emoji, created_at FROM tags WHERE id=? AND user_id=?`, tagID, userID)
	if errors.Is(err, sql.ErrNoRows) {
		jsonError(w, http.StatusNotFound, "tag not found")
		return
	}
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "database error")
		return
	}

	var req updateTagRequest
	if err := decodeJSON(r, &req); err != nil {
		jsonError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.Name != nil {
		tag.Name = strings.TrimSpace(*req.Name)
		if tag.Name == "" {
			jsonError(w, http.StatusUnprocessableEntity, "tag name cannot be empty")
			return
		}
	}
	if req.Emoji != nil {
		tag.Emoji = *req.Emoji
	}

	_, err = h.db.Exec(`UPDATE tags SET name=?, emoji=? WHERE id=? AND user_id=?`,
		tag.Name, tag.Emoji, tagID, userID,
	)
	if err != nil {
		if strings.Contains(err.Error(), "UNIQUE") {
			jsonError(w, http.StatusConflict, "tag name already exists")
			return
		}
		jsonError(w, http.StatusInternalServerError, "failed to update tag")
		return
	}

	jsonResponse(w, http.StatusOK, tag.ToPublic())
}

// ── Delete tag ────────────────────────────────────────────────────────────────

func (h *TagsHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID := middleware.UserIDFromContext(r.Context())
	tagID := chi.URLParam(r, "id")

	res, err := h.db.Exec(`DELETE FROM tags WHERE id=? AND user_id=?`, tagID, userID)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "failed to delete tag")
		return
	}
	n, _ := res.RowsAffected()
	if n == 0 {
		jsonError(w, http.StatusNotFound, "tag not found")
		return
	}
	jsonResponse(w, http.StatusOK, map[string]string{"message": "tag deleted"})
}
