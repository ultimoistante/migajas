package models

import "time"

// Attachment is the DB representation of a file attached to a note.
type Attachment struct {
	ID           string    `db:"id"`
	NoteID       string    `db:"note_id"`
	UserID       string    `db:"user_id"`
	StoredName   string    `db:"stored_name"`   // UUID-based filename on disk
	OriginalName string    `db:"original_name"` // original filename from upload
	MimeType     string    `db:"mime_type"`
	Size         int64     `db:"size"`
	CreatedAt    time.Time `db:"created_at"`
}

// AttachmentResponse is the JSON-safe view (stored_name omitted).
type AttachmentResponse struct {
	ID           string    `json:"id"`
	NoteID       string    `json:"note_id"`
	OriginalName string    `json:"original_name"`
	MimeType     string    `json:"mime_type"`
	Size         int64     `json:"size"`
	CreatedAt    time.Time `json:"created_at"`
}

func (a *Attachment) ToResponse() AttachmentResponse {
	return AttachmentResponse{
		ID:           a.ID,
		NoteID:       a.NoteID,
		OriginalName: a.OriginalName,
		MimeType:     a.MimeType,
		Size:         a.Size,
		CreatedAt:    a.CreatedAt,
	}
}
