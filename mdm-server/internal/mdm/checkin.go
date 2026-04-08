package mdm

import (
	"io"
	"log/slog"
	"net/http"
)

// CheckinHandler receives MDM device check-in PUTs (Authenticate, TokenUpdate, etc.).
// See: https://developer.apple.com/documentation/devicemanagement/implementing_device_management
func CheckinHandler(log *slog.Logger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPut {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		body, err := io.ReadAll(io.LimitReader(r.Body, 8<<20))
		if err != nil {
			http.Error(w, "read body", http.StatusBadRequest)
			return
		}
		dict, err := DecodePlistDict(body)
		if err != nil {
			log.Warn("mdm check-in: plist decode failed", "err", err, "len", len(body))
			http.Error(w, "invalid plist", http.StatusBadRequest)
			return
		}
		msgType, _ := dict["MessageType"].(string)
		udid, _ := dict["UDID"].(string)
		log.Info("mdm check-in",
			"messageType", msgType,
			"udid", udid,
			"userID", dict["UserID"],
		)

		// Minimal valid response: acknowledge. Extend with command queue, user/channel mapping, etc.
		resp := map[string]interface{}{
			"Status": "Acknowledged",
		}
		out, err := EncodePlistXML(resp)
		if err != nil {
			log.Error("encode response", "err", err)
			http.Error(w, "encode", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/x-apple-aspen-mdm-checkin")
		_, _ = w.Write(out)
	}
}
