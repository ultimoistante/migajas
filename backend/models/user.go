package models

import "time"

type User struct {
	ID            string     `db:"id"              json:"id"`
	Username      string     `db:"username"        json:"username"`
	Email         string     `db:"email"           json:"email"`
	PasswordHash  string     `db:"password_hash"   json:"-"`
	IsAdmin       bool       `db:"is_admin"        json:"is_admin"`
	VaultPinHash  *string    `db:"vault_pin_hash"  json:"-"`
	VaultPassHash *string    `db:"vault_pass_hash" json:"-"`
	VaultSalt     *string    `db:"vault_salt"      json:"-"`
	CreatedAt     time.Time  `db:"created_at"      json:"created_at"`
	UpdatedAt     time.Time  `db:"updated_at"      json:"updated_at"`
}

// UserPublic is what's returned to clients (no secrets)
type UserPublic struct {
	ID        string    `json:"id"`
	Username  string    `json:"username"`
	Email     string    `json:"email"`
	IsAdmin   bool      `json:"is_admin"`
	HasVault  bool      `json:"has_vault"` // true if vault credential set
	CreatedAt time.Time `json:"created_at"`
}

func (u *User) Public() UserPublic {
	return UserPublic{
		ID:        u.ID,
		Username:  u.Username,
		Email:     u.Email,
		IsAdmin:   u.IsAdmin,
		HasVault:  u.VaultPinHash != nil || u.VaultPassHash != nil,
		CreatedAt: u.CreatedAt,
	}
}
