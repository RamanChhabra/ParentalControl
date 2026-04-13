package com.parentalcontrol.app

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelDeviceOwner = "com.parentalcontrol.app/device_owner"
    private val channelAndroidParental = "com.parentalcontrol.app/android_parental_control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelDeviceOwner).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDeviceOwner" -> {
                    result.success(isDeviceOwner())
                }
                "setAppBlocked" -> {
                    val packageName = call.argument<String>("packageName")
                    val blocked = call.argument<Boolean>("blocked") ?: true
                    if (packageName.isNullOrEmpty()) {
                        result.error("INVALID", "packageName required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        setAppBlocked(packageName, blocked)
                        result.success(true)
                    } catch (e: SecurityException) {
                        result.error("NOT_DEVICE_OWNER", "App is not device owner: ${e.message}", null)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelAndroidParental).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageStatsPermission" -> result.success(ParentalControlAndroidApi.hasUsageStatsPermission(this))
                "openUsageAccessSettings" -> {
                    ParentalControlAndroidApi.openUsageAccessSettings(this)
                    result.success(null)
                }
                "isIgnoringBatteryOptimizations" -> result.success(ParentalControlAndroidApi.isIgnoringBatteryOptimizations(this))
                "requestIgnoreBatteryOptimizations" -> {
                    ParentalControlAndroidApi.requestIgnoreBatteryOptimizations(this)
                    result.success(null)
                }
                "openAccessibilitySettings" -> {
                    ParentalControlAndroidApi.openAccessibilitySettings(this)
                    result.success(null)
                }
                "isAccessibilityServiceEnabled" -> {
                    val serviceFlattened = call.argument<String>("serviceFlattened")
                    if (serviceFlattened.isNullOrEmpty()) {
                        result.error("INVALID", "serviceFlattened required (package/class)", null)
                    } else {
                        result.success(ParentalControlAndroidApi.isAccessibilityServiceEnabled(this, serviceFlattened))
                    }
                }
                "isNotificationListenerEnabledForPackage" -> result.success(
                    ParentalControlAndroidApi.isNotificationListenerEnabledForPackage(this),
                )
                "openNotificationListenerSettings" -> {
                    ParentalControlAndroidApi.openNotificationListenerSettings(this)
                    result.success(null)
                }
                "isDeviceAdminActive" -> result.success(ParentalControlAndroidApi.isDeviceAdminActive(this))
                "requestDeviceAdmin" -> {
                    val explanation = call.argument<String>("explanation")
                    ParentalControlAndroidApi.requestDeviceAdmin(this, explanation)
                    result.success(null)
                }
                "canDrawOverlays" -> result.success(ParentalControlAndroidApi.canDrawOverlays(this))
                "openManageOverlaySettings" -> {
                    ParentalControlAndroidApi.openManageOverlaySettings(this)
                    result.success(null)
                }
                "isVpnPrepareNeeded" -> result.success(ParentalControlAndroidApi.isVpnPrepareNeeded(this))
                "launchVpnPrepare" -> {
                    result.success(ParentalControlAndroidApi.launchVpnPrepare(this))
                }
                "openSecuritySettings" -> {
                    ParentalControlAndroidApi.openSecuritySettings(this)
                    result.success(null)
                }
                "installUserCaCertificate" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.error("INVALID", "path required", null)
                    } else {
                        result.success(ParentalControlAndroidApi.installUserCaCertificate(this, path))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun adminComponent(): ComponentName {
        return ComponentName(this, DeviceAdminReceiver::class.java)
    }

    private fun isDeviceOwner(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            dpm.isDeviceOwnerApp(packageName)
        } else {
            false
        }
    }

    private fun setAppBlocked(packageName: String, hidden: Boolean) {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            dpm.setApplicationHidden(adminComponent(), packageName, hidden)
        }
    }
}
