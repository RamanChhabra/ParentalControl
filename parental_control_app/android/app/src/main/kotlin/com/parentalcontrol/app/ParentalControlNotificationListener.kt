package com.parentalcontrol.app

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Declared so the app can be enabled under Settings → Device & app notifications.
 * Implement forwarding when notification-based reporting is required.
 */
class ParentalControlNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {}

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {}
}
