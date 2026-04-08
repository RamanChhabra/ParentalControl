package enroll

import (
	"fmt"
	"strings"

	"github.com/parentalcontrol/mdm-server/internal/config"
)

// UnsignedProfileXML returns a minimal MDM enrollment profile as XML plist text.
// Real devices require this payload to be cryptographically signed; use MDM_SIGN_CERT / MDM_SIGN_KEY when you add signing.
// Placeholders: replace ServerURL and Topic with values from Apple MDM push certificate workflow.
func UnsignedProfileXML(cfg config.Config) string {
	base := strings.TrimRight(cfg.PublicBaseURL, "/")
	checkIn := base + "/mdm/checkin"
	serverURL := base + "/mdm/connect"
	topic := cfg.MDMTopic
	if topic == "" {
		topic = "com.apple.mgmt.External.REPLACE_WITH_TOPIC_FROM_PUSH_CERT"
	}
	// Plist XML for Configuration profile with MDM payload (structure per Apple Device Management).
	return fmt.Sprintf(`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>PayloadContent</key>
	<array>
		<dict>
			<key>PayloadType</key>
			<string>com.apple.mdm</string>
			<key>PayloadVersion</key>
			<integer>1</integer>
			<key>PayloadIdentifier</key>
			<string>com.parentalcontrol.mdm.mdm</string>
			<key>PayloadUUID</key>
			<string>11111111-1111-1111-1111-111111111111</string>
			<key>PayloadDisplayName</key>
			<string>MDM</string>
			<key>PayloadDescription</key>
			<string>MDM enrollment (dev template — must be signed for production)</string>
			<key>AccessRights</key>
			<integer>8191</integer>
			<key>CheckInURL</key>
			<string>%s</string>
			<key>CheckOutWhenRemoved</key>
			<true/>
			<key>IdentityCertificateUUID</key>
			<string>22222222-2222-2222-2222-222222222222</string>
			<key>ServerURL</key>
			<string>%s</string>
			<key>Topic</key>
			<string>%s</string>
			<key>SignMessage</key>
			<true/>
			<key>ServerCapabilities</key>
			<array>
				<string>com.apple.mdm.per-user-connections</string>
				<string>com.apple.mdm.bootstraptoken</string>
			</array>
		</dict>
	</array>
	<key>PayloadDisplayName</key>
	<string>Parental Control MDM (unsigned template)</string>
	<key>PayloadIdentifier</key>
	<string>com.parentalcontrol.mdm.profile</string>
	<key>PayloadRemovalDisallowed</key>
	<false/>
	<key>PayloadType</key>
	<string>Configuration</string>
	<key>PayloadUUID</key>
	<string>33333333-3333-3333-3333-333333333333</string>
	<key>PayloadVersion</key>
	<integer>1</integer>
</dict>
</plist>
`, checkIn, serverURL, topic)
}
