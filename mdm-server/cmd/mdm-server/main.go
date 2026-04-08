// MDM server scaffold: HTTP endpoints for Apple MDM check-in/connect and an unsigned enrollment profile template.
// Next steps: obtain MDM push certificate and Topic from Apple, sign profiles, implement command queue + APNs push.
// Run (dev, TLS via reverse proxy recommended): MDM_PUBLIC_BASE_URL=https://localhost:8443 go run ./cmd/mdm-server
package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/parentalcontrol/mdm-server/internal/config"
	"github.com/parentalcontrol/mdm-server/internal/httpserver"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))

	cfg, err := config.LoadFromEnv()
	if err != nil {
		log.Error("config", "err", err)
		os.Exit(1)
	}
	if cfg.DevelopmentHTTP() {
		log.Warn("TLS disabled: set MDM_TLS_CERT and MDM_TLS_KEY for HTTPS. iOS devices require HTTPS for MDM in production.")
	}

	mux := httpserver.NewMux(log, cfg)
	handler := httpserver.LogRequests(log, mux)

	srv := &http.Server{
		Addr:              cfg.ListenAddr,
		Handler:           handler,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       60 * time.Second,
		WriteTimeout:      120 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	go func() {
		var err error
		if cfg.DevelopmentHTTP() {
			err = srv.ListenAndServe()
		} else {
			err = srv.ListenAndServeTLS(cfg.TLSCertFile, cfg.TLSKeyFile)
		}
		if err != nil && err != http.ErrServerClosed {
			log.Error("server", "err", err)
			os.Exit(1)
		}
	}()

	log.Info("mdm-server listening", "addr", cfg.ListenAddr, "public", cfg.PublicBaseURL)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	<-ctx.Done()
	stop()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdownCtx)
}
