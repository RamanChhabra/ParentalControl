package com.parentalcontrol.app

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channel = "com.parentalcontrol.app/device_owner"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
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
