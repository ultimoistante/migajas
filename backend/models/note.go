package models

import "time"

type Note struct {
	ID              string    `db:"id"              json:"id"`
	UserID          string    `db:"user_id"         json:"user_id"`
	Title           string    `db:"title"           json:"title"`
	Body            string    `db:"body"            json:"-"` // never directly in JSON
	IsSecret        bool      `db:"is_secret"       json:"is_secret"`
	BodyNonce       *string   `db:"body_nonce"      json:"-"`
	IsPinned        bool      `db:"is_pinned"       json:"is_pinned"`
	Color           string    `db:"color"           json:"color"`
	CreatedAt       time.Time `db:"created_at"      json:"created_at"`
	UpdatedAt       time.Time `db:"updated_at"      json:"updated_at"`
	AttachmentCount int       `db:"attachment_count" json:"attachment_count"`
}

// NoteResponse is returned to clients. Body is a pointer: nil when secret+locked.
type NoteResponse struct {
	ID              string    `json:"id"`
	UserID          string    `json:"user_id"`
	Title           string    `json:"title"`
	Body            *string   `json:"body"` // nil when secret and not unlocked
	IsSecret        bool      `json:"is_secret"`
	IsLocked        bool      `json:"is_locked"` // true when secret and not yet unlocked in this request
	IsPinned        bool      `json:"is_pinned"`
	Color           string    `json:"color"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
	AttachmentCount int       `json:"attachment_count"`
}

func (n *Note) ToResponse(decryptedBody *string) NoteResponse {
	resp := NoteResponse{
		ID:              n.ID,
		UserID:          n.UserID,
		Title:           n.Title,
		IsSecret:        n.IsSecret,
		IsLocked:        n.IsSecret && decryptedBody == nil,
		IsPinned:        n.IsPinned,
		Color:           n.Color,
		CreatedAt:       n.CreatedAt,
		UpdatedAt:       n.UpdatedAt,
		AttachmentCount: n.AttachmentCount,
	}
	if !n.IsSecret {
		resp.Body = &n.Body
	} else {
		resp.Body = decryptedBody // nil if locked
	}
	return resp
}
