package com.parentalcontrol.app

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

/**
 * Required for Device Owner mode. When this app is set as device owner (via adb),
 * we can use DevicePolicyManager.setApplicationHidden() to hide blocked apps from the launcher.
 *
 * To set as device owner (device must have no user accounts, typically after factory reset):
 *   adb shell dpm set-device-owner com.parentalcontrol.app/.DeviceAdminReceiver
 */
class DeviceAdminReceiver : DeviceAdminReceiver() {

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
    }
}
