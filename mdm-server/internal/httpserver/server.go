package httpserver

import (
	"log/slog"
	"net/http"
	"os"
	"strings"

	"github.com/parentalcontrol/mdm-server/internal/config"
	"github.com/parentalcontrol/mdm-server/internal/enroll"
	"github.com/parentalcontrol/mdm-server/internal/mdm"
)

// NewMux registers HTTP routes for health, enrollment template, and MDM endpoints.
func NewMux(log *slog.Logger, cfg config.Config) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("/enroll/profile.mobileconfig", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		xml := enroll.UnsignedProfileXML(cfg)
		w.Header().Set("Content-Type", "application/x-apple-aspen-config")
		_, _ = w.Write([]byte(xml))
	})
	// Public CA certificate for parental HTTPS filtering (child app downloads and installs as user CA).
	mux.HandleFunc("/parental/filtering-ca.crt", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		if cfg.ParentalCaCertFile == "" {
			http.Error(w, "parental CA not configured on server", http.StatusNotFound)
			return
		}
		body, err := os.ReadFile(cfg.ParentalCaCertFile)
		if err != nil {
			log.Error("parental ca read", "path", cfg.ParentalCaCertFile, "err", err)
			http.Error(w, "certificate unavailable", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/x-x509-ca-cert")
		w.Header().Set("Content-Disposition", `attachment; filename="parental-filtering-ca.crt"`)
		_, _ = w.Write(body)
	})
	mux.Handle("/mdm/checkin", mdm.CheckinHandler(log))
	mux.Handle("/mdm/connect", mdm.ConnectHandler(log))
	return mux
}

// LogRequests wraps the handler with minimal request logging.
func LogRequests(log *slog.Logger, h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasPrefix(r.URL.Path, "/mdm/") {
			h.ServeHTTP(w, r)
			return
		}
		log.Info("request", "method", r.Method, "path", r.URL.Path, "remote", r.RemoteAddr, "ct", r.Header.Get("Content-Type"))
		h.ServeHTTP(w, r)
	})
}
