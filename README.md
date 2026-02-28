# migajas

A privacy-focused, multi-user note-taking app with a **Go** backend and **SvelteKit + Tailwind / DaisyUI** frontend.

---

## Features

- **Rich text editor** — TipTap-powered editor with a top toolbar (headings, bold/italic/strikethrough, links, bullet/ordered/task lists, tables, code blocks, blockquotes, emoji picker, undo/redo) and a table context toolbar
- **Secret notes** — body encrypted at rest with **AES-256-GCM**, key derived via **Argon2id** from a vault PIN/password; secret note bodies are *never* transmitted unless explicitly unlocked
- **File attachments** — attach any file to a note; images are shown as clickable thumbnails with a full-size lightbox and download button; audio files are played back inline with an HTML5 player
- **Voice memos** — record audio directly from the note editor; saved as an attachment
- **Note references** — insert links to other notes via the bottom bar picker
- **Multi-user** — single SQLite database with per-user data isolation
- **Admin user management** — admin users can create, edit and delete accounts from the `/admin` page (useful when self-registration is disabled)
- **Auth** — JWT access tokens (15 min) + httpOnly refresh tokens (7 days), auto-rotated
- **Pinning, search, color labels**
- **Note cards** — show last-modified timestamp (ISO format), attachment count badge, secret/pinned badges
- **Light / dark theme** with system preference detection

---

## Project structure

```
migajas/
├── backend/                 Go API (chi router, SQLite/sqlx, bcrypt, Argon2id, AES-GCM)
│   ├── config/              Environment config
│   ├── database/            SQLite connection & schema migrations
│   ├── models/              User, Note & Attachment structs
│   ├── handlers/            HTTP handlers (auth, notes, attachments, admin)
│   ├── middleware/          JWT auth middleware
│   ├── utils/               Crypto helpers (AES-GCM, Argon2id, bcrypt, JWT)
│   └── main.go              Entry point + router
└── frontend/                SvelteKit app
    └── src/
        ├── routes/          Pages: / (home), /login, /register, /settings, /admin, /setup
        └── lib/
            ├── api/         Typed API client with auto-refresh
            ├── stores/      Auth, notes, theme Svelte stores
            └── components/  RichEditor, NoteCard, NoteModal, UnlockModal
```

---

## Running in development

### Prerequisites

- Go ≥ 1.21, GCC (for `go-sqlite3`)
- Node.js ≥ 18, npm

### Quick start

```bash
chmod +x run.sh
./run.sh
```

Builds the backend binary (`migajas-backend`) and starts it on `:8080`, then starts the SvelteKit dev server on `:5173`.  
Open **http://localhost:5173** in your browser.

### Other scripts

| Script | Description |
|--------|-------------|
| `./stop.sh` | Stop both servers |
| `./restart.sh` | Stop and restart both servers |
| `./reset.sh` | Delete the database, rebuild and restart the backend (fresh state) |

### Separate terminals

```bash
# Terminal 1 – backend
cd backend && CGO_CFLAGS="-Wno-discarded-qualifiers" go build -o migajas-backend . && ./migajas-backend

# Terminal 2 – frontend
cd frontend && npm run dev
```

---

## Environment variables (backend)

| Variable                   | Default                        | Description                               |
|----------------------------|--------------------------------|-------------------------------------------|
| `PORT`                     | `8080`                         | HTTP listen port                          |
| `DB_PATH`                  | `./migajas.db`                 | SQLite file path                          |
| `ATTACHMENTS_DIR`          | `./attachments`                | Directory where uploaded files are stored |
| `JWT_SECRET`               | *(dev default — change this!)* | Access token signing secret               |
| `JWT_REFRESH_SECRET`       | *(dev default — change this!)* | Refresh token signing secret              |
| `ACCESS_TOKEN_TTL_MINUTES` | `15`                           | Access token lifetime                     |
| `REFRESH_TOKEN_TTL_DAYS`   | `7`                            | Refresh token lifetime                    |
| `FRONTEND_URL`             | `http://localhost:5173`        | CORS allowed origin                       |
| `ALLOW_SELF_REGISTRATION`  | `true`                         | Allow public account creation             |

---

## API overview

### Auth
| Method | Path                   | Auth | Description                                    |
|--------|------------------------|------|------------------------------------------------|
| POST   | `/api/auth/register`   | —    | Register a new user (if self-registration on)  |
| POST   | `/api/auth/login`      | —    | Login, returns access token + sets cookie      |
| POST   | `/api/auth/refresh`    | —    | Refresh access token via httpOnly cookie       |
| POST   | `/api/auth/logout`     | JWT  | Revoke refresh token                           |
| GET    | `/api/auth/me`         | JWT  | Get current user info                          |
| POST   | `/api/auth/vault`      | JWT  | Set/update vault PIN or vault password         |

### Notes
| Method | Path                       | Auth | Description                                                         |
|--------|----------------------------|------|---------------------------------------------------------------------|
| GET    | `/api/notes`               | JWT  | List all notes (includes `attachment_count`; secret bodies omitted) |
| POST   | `/api/notes`               | JWT  | Create a note                                                       |
| GET    | `/api/notes/{id}`          | JWT  | Get a single note                                                   |
| PUT    | `/api/notes/{id}`          | JWT  | Update a note                                                       |
| DELETE | `/api/notes/{id}`          | JWT  | Delete a note                                                       |
| POST   | `/api/notes/{id}/unlock`   | JWT  | Decrypt and return the body of a secret note                        |

### Attachments
| Method | Path                            | Auth | Description                                       |
|--------|---------------------------------|------|---------------------------------------------------|
| POST   | `/api/notes/{id}/attachments`   | JWT  | Upload a file (multipart/form-data, max 50 MB)    |
| GET    | `/api/notes/{id}/attachments`   | JWT  | List attachments for a note                       |
| DELETE | `/api/attachments/{id}`         | JWT  | Delete an attachment (removes file from disk too) |
| GET    | `/api/attachments/{id}/content` | JWT  | Stream the file content (requires Bearer token)   |

### Admin (admin users only)
| Method | Path                    | Auth      | Description              |
|--------|-------------------------|-----------|--------------------------|
| GET    | `/api/admin/users`      | JWT+admin | List all users           |
| POST   | `/api/admin/users`      | JWT+admin | Create a user            |
| PUT    | `/api/admin/users/{id}` | JWT+admin | Update a user            |
| DELETE | `/api/admin/users/{id}` | JWT+admin | Delete a user (cascades) |

---

## Secret notes — how it works

1. User sets a **vault PIN** (4–8 digits) or **vault password** via `/api/auth/vault`
2. A random 32-byte **vault salt** is generated and stored alongside a **bcrypt hash** of the credential
3. When creating a secret note: the frontend sends the note body + the user's credential
4. The backend derives a 32-byte AES key using **Argon2id(credential, salt)**
5. The body is encrypted with **AES-256-GCM** and stored; the nonce is stored separately
6. When listing/fetching notes, **secret note bodies are never sent** (`body: null`, `is_locked: true`)
7. To unlock: the frontend calls `/api/notes/{id}/unlock` with the credential; the backend verifies it against the bcrypt hash, derives the key, decrypts, and returns the plaintext **only in that response**

---

## Attachments — how it works

- Files are stored on disk inside `ATTACHMENTS_DIR` using a UUID-based filename (the original name is preserved in the DB only)
- The serve endpoint (`GET /api/attachments/{id}/content`) requires a valid `Authorization: Bearer` header — direct `<img src>` or `<audio src>` tags cannot be used; the frontend fetches the file with the auth header and creates a temporary `blob:` URL via `URL.createObjectURL()`
- Deleting a note cascades to all its attachments (both DB rows and files on disk)
- Deleting a user cascades to all their notes and attachments
