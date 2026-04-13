package config

import (
	"os"
	"path/filepath"
)

// Config holds runtime settings for the MDM HTTP server and enrollment URLs.
type Config struct {
	// ListenAddr is the bind address (e.g. ":8443").
	ListenAddr string
	// PublicBaseURL is the HTTPS base URL devices will use (no trailing slash), e.g. https://mdm.example.com
	PublicBaseURL string
	// TLSCertFile and TLSKeyFile enable TLS when both are non-empty. MDM requires HTTPS for production.
	TLSCertFile string
	TLSKeyFile  string
	// MDMTopic is the APNs topic from your MDM push certificate (com.apple.mgmt.External.<hex>).
	// Required for a real signed enrollment profile.
	MDMTopic string
	// Sign enrollment profiles with your identity cert (PEM paths); empty = serve template only for inspection.
	SignCertFile string
	SignKeyFile  string
	// ParentalCaCertFile is the PEM/DER public CA path served at /parental/filtering-ca.crt for the child app (HTTPS filtering trust).
	ParentalCaCertFile string
}

func LoadFromEnv() (Config, error) {
	c := Config{
		ListenAddr:    getenv("MDM_LISTEN", ":8443"),
		PublicBaseURL: os.Getenv("MDM_PUBLIC_BASE_URL"),
		TLSCertFile:   os.Getenv("MDM_TLS_CERT"),
		TLSKeyFile:    os.Getenv("MDM_TLS_KEY"),
		MDMTopic:      os.Getenv("MDM_TOPIC"),
		SignCertFile:  os.Getenv("MDM_SIGN_CERT"),
		SignKeyFile:   os.Getenv("MDM_SIGN_KEY"),
	}
	if c.PublicBaseURL == "" {
		c.PublicBaseURL = "https://127.0.0.1:8443"
	}
	c.ParentalCaCertFile = resolveParentalCaCertPath()
	return c, nil
}

func resolveParentalCaCertPath() string {
	p := os.Getenv("MDM_PARENTAL_CA_CERT")
	if p != "" {
		return p
	}
	// Default: certs/parental-filtering-ca.crt next to cwd when running from mdm-server/.
	def := filepath.Clean("certs/parental-filtering-ca.crt")
	if st, err := os.Stat(def); err == nil && !st.IsDir() {
		return def
	}
	return ""
}

func getenv(key, def string) string {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	return v
}

// DevelopmentHTTP returns true if TLS is not configured (local dev only; iOS devices expect HTTPS).
func (c Config) DevelopmentHTTP() bool {
	return c.TLSCertFile == "" || c.TLSKeyFile == ""
}
