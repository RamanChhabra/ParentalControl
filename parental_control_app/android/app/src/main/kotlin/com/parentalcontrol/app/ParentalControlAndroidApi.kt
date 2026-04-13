package com.parentalcontrol.app

import android.app.Activity
import android.app.AppOpsManager
import android.content.ActivityNotFoundException
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.os.PowerManager
import android.os.Process
import android.provider.Settings
import android.text.TextUtils
import androidx.core.content.FileProvider
import java.io.File

/**
 * Native helpers for parental-control onboarding: usage stats, battery, accessibility,
 * notification listener, device admin (profile owner), overlay, VPN prepare.
 * Used from Flutter via MethodChannel [com.parentalcontrol.app/android_parental_control].
 */
object ParentalControlAndroidApi {

    /** @see android.provider.Settings.ACTION_ACCESSIBILITY_DETAILS_SETTINGS (API 33+) — string literal for older compileSdk stubs. */
    private const val ACTION_ACCESSIBILITY_DETAILS_SETTINGS = "android.settings.ACCESSIBILITY_DETAILS_SETTINGS"

    private fun adminComponent(context: Context): ComponentName {
        return ComponentName(context, DeviceAdminReceiver::class.java)
    }

    fun hasUsageStatsPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return false
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            ) == AppOpsManager.MODE_ALLOWED
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            ) == AppOpsManager.MODE_ALLOWED
        } else {
            @Suppress("DEPRECATION")
            try {
                appOps.checkOp(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName,
                ) == AppOpsManager.MODE_ALLOWED
            } catch (_: Exception) {
                false
            }
        }
    }

    fun openUsageAccessSettings(activity: Activity) {
        activity.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
    }

    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun requestIgnoreBatteryOptimizations(activity: Activity) {
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:${activity.packageName}")
        }
        activity.startActivity(intent)
    }

    /**
     * Prefer opening **this app’s** Accessibility service screen (Android 13+), so **Parental Control**
     * appears directly instead of only seeing other apps (e.g. Qustodio) in the generic list.
     * Falls back to [Settings.ACTION_ACCESSIBILITY_SETTINGS] on older versions or if the detail screen fails.
     */
    fun openAccessibilitySettings(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                val cn = ComponentName(activity, ParentalControlAccessibilityService::class.java)
                val intent = Intent(ACTION_ACCESSIBILITY_DETAILS_SETTINGS).apply {
                    putExtra(Intent.EXTRA_COMPONENT_NAME, cn)
                }
                activity.startActivity(intent)
                return
            } catch (_: Exception) {
                // Older OEMs / missing activity: fall back.
            }
        }
        activity.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
    }

    /**
     * [serviceFlattened] format: package/class, e.g. com.parentalcontrol.app/com.parentalcontrol.app.MyAccessibilityService
     */
    fun isAccessibilityServiceEnabled(context: Context, serviceFlattened: String): Boolean {
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        while (splitter.hasNext()) {
            if (splitter.next().equals(serviceFlattened, ignoreCase = true)) return true
        }
        return false
    }

    fun isNotificationListenerEnabledForPackage(context: Context): Boolean {
        val flat = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        val pkg = context.packageName
        for (componentStr in flat.split(":")) {
            if (componentStr.isEmpty()) continue
            val cn = ComponentName.unflattenFromString(componentStr) ?: continue
            if (cn.packageName == pkg) return true
        }
        return false
    }

    fun openNotificationListenerSettings(activity: Activity) {
        activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }

    fun isDeviceAdminActive(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isAdminActive(adminComponent(context))
    }

    fun requestDeviceAdmin(activity: Activity, explanation: String?) {
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent(activity))
            if (!explanation.isNullOrEmpty()) {
                putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, explanation)
            }
        }
        activity.startActivity(intent)
    }

    fun canDrawOverlays(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true
        }
    }

    fun openManageOverlaySettings(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${activity.packageName}"),
            )
            activity.startActivity(intent)
        }
    }

    /** True if user must still approve the system VPN dialog. Requires [ParentalControlVpnService] in the manifest. */
    fun isVpnPrepareNeeded(activity: Activity): Boolean {
        return try {
            VpnService.prepare(activity.applicationContext) != null
        } catch (_: Exception) {
            false
        }
    }

    /** @return true if the system VPN consent screen was started; false if already allowed or on error. */
    fun launchVpnPrepare(activity: Activity): Boolean {
        return try {
            val intent = VpnService.prepare(activity.applicationContext) ?: return false
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    /** Opens Security settings so the user can install a user CA / credentials (path varies by OEM). */
    fun openSecuritySettings(activity: Activity) {
        activity.startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
    }

    /**
     * Opens the system UI to install a user CA from a file in app-private storage.
     * Requires [FileProvider] authority `${packageName}.fileprovider`.
     * @return true if an activity was started.
     */
    fun installUserCaCertificate(activity: Activity, absolutePath: String): Boolean {
        val f = File(absolutePath)
        if (!f.isFile || !f.canRead()) return false
        val uri = try {
            FileProvider.getUriForFile(
                activity,
                "${activity.packageName}.fileprovider",
                f,
            )
        } catch (_: Exception) {
            return false
        }
        val tryTypes = listOf("application/x-x509-ca-cert", "application/pkix-cert")
        for (mime in tryTypes) {
            try {
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, mime)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                activity.startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
                continue
            } catch (_: Exception) {
                continue
            }
        }
        return false
    }
}
