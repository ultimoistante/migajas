package config

import (
	"net/http"
	"os"
	"strconv"
	"strings"
)

type Config struct {
	Port                     string
	DatabasePath             string
	AttachmentsDir           string
	JWTSecret                string
	JWTRefreshSecret         string
	AccessTokenTTL           int // minutes
	RefreshTokenTTL          int // days
	FrontendURL              string
	AdditionalAllowedOrigins string // comma-separated extra CORS origins (e.g. capacitor://localhost)
}

func Load() *Config {
	return &Config{
		Port:                     getEnv("PORT", "8080"),
		DatabasePath:             getEnv("DB_PATH", "./migajas.db"),
		AttachmentsDir:           getEnv("ATTACHMENTS_DIR", "./attachments"),
		JWTSecret:                getEnv("JWT_SECRET", "change-me-in-production-access-secret"),
		JWTRefreshSecret:         getEnv("JWT_REFRESH_SECRET", "change-me-in-production-refresh-secret"),
		AccessTokenTTL:           getEnvInt("ACCESS_TOKEN_TTL_MINUTES", 15),
		RefreshTokenTTL:          getEnvInt("REFRESH_TOKEN_TTL_DAYS", 7),
		FrontendURL:              getEnv("FRONTEND_URL", "http://localhost:5173"),
		AdditionalAllowedOrigins: getEnv("ADDITIONAL_ALLOWED_ORIGINS", ""),
	}
}

// AllowedOrigins returns the full slice of CORS-allowed origins.
func (c *Config) AllowedOrigins() []string {
	// Always include Capacitor origins so Android/iOS apps work out of the box.
	origins := []string{c.FrontendURL, "http://localhost", "capacitor://localhost"}
	for _, o := range strings.Split(c.AdditionalAllowedOrigins, ",") {
		o = strings.TrimSpace(o)
		if o != "" {
			origins = append(origins, o)
		}
	}
	return origins
}

// IsOriginAllowed is the AllowOriginFunc used by the CORS middleware.
// It does a case-insensitive exact match against every configured origin,
// and also accepts any http://localhost:* origin for Capacitor's internal server.
func (c *Config) IsOriginAllowed(r *http.Request, origin string) bool {
	origin = strings.ToLower(strings.TrimSpace(origin))
	for _, o := range c.AllowedOrigins() {
		if strings.ToLower(o) == origin {
			return true
		}
	}
	// Accept any localhost origin so Capacitor (which may pick an internal port)
	// always works regardless of what port the WebView uses.
	return strings.HasPrefix(origin, "http://localhost") || strings.HasPrefix(origin, "capacitor://localhost")
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return fallback
}
