// ignore_for_file: unused_element
// ---------------------------------------------------------------------------
// iOS vs Android feature support for Parental Control (reference only).
// See child_home_screen.dart and main.dart for platform gating.
// ---------------------------------------------------------------------------
//
// FEATURES THAT WORK ON iOS:
// - Auth & pairing: Firebase Auth, pairing code, device linked as "iOS" in Firestore.
// - Location: Geolocator; foreground LocationTracker; background fetch in location_background_service_ios.dart.
// - Safe Browser: WebView with parent domain allow/block list.
// - App install requests: Child requests, parent approves/denies; Firestore only.
// - Parent dashboard & device details: View linked devices, rules, location, app usage (Screen Time).
// - Edit rules: Screen time limit, blocked domains (Safe Browser), per-app limits (stored).
// - App usage (iOS): ios_screen_time_tools getScreenTimeData() sends usage to Firestore (AppUsageTrackerIos).
//   Requires Family Controls capability and user authorization on the child device.
// - App blocking (iOS): ios_screen_time_tools selectAppsToDiscourage() / removeAllRestrictions().
//   Child uses "Blocked apps (Screen Time)" on child home to choose apps to block via Apple Screen Time.
//   Requires Family Controls capability (restricted; request in Apple Developer).
//
// FEATURES THAT DO NOT WORK ON iOS (Android-only):
// - Call log: No public iOS API for call history. Parent sees "Not available on iOS".
// - SMS: iOS does not allow reading SMS. Parent sees "Not available on iOS".
// - Blocked-app notification (in-app): flutter_local_notifications flow is Android only.
//
// HOW TO RUN ON iOS:
// 1. Add GoogleService-Info.plist from Firebase Console to ios/Runner/.
// 2. Info.plist already has location and UIBackgroundModes: fetch, location.
// 3. For Screen Time (app usage + app blocking): In Xcode, add capability "Family Controls"
//    (Signing & Capabilities). This is a restricted capability; request access in Apple Developer
//    if needed. Then authorize on the child device when prompted.

const bool _iosReference = true;
