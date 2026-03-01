package models

import "time"

type Tag struct {
	ID        string    `db:"id"         json:"id"`
	UserID    string    `db:"user_id"    json:"user_id"`
	Name      string    `db:"name"       json:"name"`
	Emoji     string    `db:"emoji"      json:"emoji"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
}

type TagPublic struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Emoji string `json:"emoji"`
}

func (t *Tag) ToPublic() TagPublic {
	return TagPublic{ID: t.ID, Name: t.Name, Emoji: t.Emoji}
}
