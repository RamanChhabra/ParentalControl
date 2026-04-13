package com.parentalcontrol.app

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent

/**
 * Declared so the app appears under Settings → Accessibility → Downloaded apps with
 * [R.string.accessibility_service_description]. Enable supervision UI in Flutter before relying on events.
 */
class ParentalControlAccessibilityService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Wire events to Flutter / logic when needed.
    }

    override fun onInterrupt() {}
}
