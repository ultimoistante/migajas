package main

import (
	"log"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	chiMiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/go-chi/httprate"

	"migajas/backend/config"
	"migajas/backend/database"
	"migajas/backend/handlers"
	"migajas/backend/middleware"
)

func main() {
	cfg := config.Load()

	db, err := database.New(cfg.DatabasePath)
	if err != nil {
		log.Fatalf("failed to open database: %v", err)
	}
	defer db.Close()
	log.Println("database ready:", cfg.DatabasePath)

	authHandler := handlers.NewAuthHandler(db, cfg)
	notesHandler := handlers.NewNotesHandler(db)
	setupHandler := handlers.NewSetupHandler(db, cfg)
	attachmentsHandler := handlers.NewAttachmentsHandler(db, cfg.AttachmentsDir)
	adminHandler := handlers.NewAdminHandler(db)

	r := chi.NewRouter()

	// ── Global middleware ──────────────────────────────────────────────────────
	r.Use(chiMiddleware.RequestID)
	r.Use(chiMiddleware.RealIP)
	r.Use(chiMiddleware.Logger)
	r.Use(chiMiddleware.Recoverer)
	r.Use(chiMiddleware.Timeout(30 * time.Second))

	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{cfg.FrontendURL},
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "Content-Disposition"},
		ExposedHeaders:   []string{"Content-Disposition"},
		// multipart/form-data content-type is included in Content-Type
		AllowCredentials: true, // needed for httpOnly refresh-token cookie
		MaxAge:           300,
	}))

	// Security headers
	r.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("X-Content-Type-Options", "nosniff")
			w.Header().Set("X-Frame-Options", "DENY")
			w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
			next.ServeHTTP(w, r)
		})
	})

	// ── Public routes ──────────────────────────────────────────────────────────
	r.Group(func(r chi.Router) {
		// Stricter rate limit on auth endpoints
		r.Use(httprate.LimitByIP(20, time.Minute))

		// Setup (first-run)
		r.Get("/api/setup/status", setupHandler.Status)
		r.Post("/api/setup", setupHandler.Initialize)

		r.Post("/api/auth/register", authHandler.Register)
		r.Post("/api/auth/login", authHandler.Login)
		r.Post("/api/auth/refresh", authHandler.Refresh)
	})

	// ── Protected routes ───────────────────────────────────────────────────────
	r.Group(func(r chi.Router) {
		r.Use(middleware.Auth(cfg.JWTSecret))
		r.Use(httprate.LimitByIP(200, time.Minute))

		r.Post("/api/auth/logout", authHandler.Logout)
		r.Get("/api/auth/me", authHandler.Me)
		r.Post("/api/auth/vault", authHandler.SetupVault)

		// Notes
		r.Get("/api/notes", notesHandler.List)
		r.Post("/api/notes", notesHandler.Create)
		r.Get("/api/notes/{id}", notesHandler.Get)
		r.Put("/api/notes/{id}", notesHandler.Update)
		r.Delete("/api/notes/{id}", notesHandler.Delete)
		r.Post("/api/notes/{id}/unlock", notesHandler.Unlock)

		// Attachments
		r.Post("/api/notes/{id}/attachments", attachmentsHandler.Upload)
		r.Get("/api/notes/{id}/attachments", attachmentsHandler.List)
		r.Delete("/api/attachments/{id}", attachmentsHandler.Delete)
		r.Get("/api/attachments/{id}/content", attachmentsHandler.Serve)

		// Admin — user management (handler enforces is_admin check internally)
		r.Get("/api/admin/users", adminHandler.ListUsers)
		r.Post("/api/admin/users", adminHandler.CreateUser)
		r.Put("/api/admin/users/{id}", adminHandler.UpdateUser)
		r.Delete("/api/admin/users/{id}", adminHandler.DeleteUser)

		// Admin — settings
		r.Get("/api/admin/settings", adminHandler.GetSettings)
		r.Put("/api/admin/settings/self-registration", adminHandler.UpdateSelfRegistration)
	})

	// Healthcheck
	r.Get("/api/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok"}`))
	})

	addr := ":" + cfg.Port
	log.Printf("migajas API listening on %s", addr)
	if err := http.ListenAndServe(addr, r); err != nil {
		log.Fatalf("server error: %v", err)
	}
}
