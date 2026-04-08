package mdm

import (
	"io"
	"log/slog"
	"net/http"
)

// ConnectHandler receives MDM "connect" PUTs (command polling / result delivery).
// When no work is queued, respond with Status Idle per Apple MDM behavior.
func ConnectHandler(log *slog.Logger) http.HandlerFunc {
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
			log.Warn("mdm connect: plist decode failed", "err", err, "len", len(body))
			http.Error(w, "invalid plist", http.StatusBadRequest)
			return
		}
		msgType, _ := dict["MessageType"].(string)
		udid, _ := dict["UDID"].(string)
		status, _ := dict["Status"].(string)
		log.Info("mdm connect",
			"messageType", msgType,
			"udid", udid,
			"status", status,
		)

		resp := map[string]interface{}{
			"Status": "Idle",
		}
		out, err := EncodePlistXML(resp)
		if err != nil {
			log.Error("encode response", "err", err)
			http.Error(w, "encode", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/xml; charset=UTF-8")
		_, _ = w.Write(out)
	}
}
