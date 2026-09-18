package com.az1n.echoes

import android.app.ActivityManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** A bounded CPU lease across decoder completion and Dart-driven next-track work.
 * It never keeps the display on. A stopped/unresponsive Dart engine cannot keep
 * this lease indefinitely; normal pause/stop explicitly releases it earlier.
 */
class PlaybackWakeGuardPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.az1n.echoes/playback_wake_guard")
        channel.setMethodCallHandler(this)
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "echoes:playback")
            .apply { setReferenceCounted(false) }
    }

    @Suppress("DEPRECATION")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method !in setOf(
                "setActive", "getStatus", "openBatterySettings",
                "openAppSettings", "openPowerSettings", "openSamsungSettings"
            )) {
            result.notImplemented()
            return
        }
        try {
            if (call.method.startsWith("open")) {
                val intent = when (call.method) {
                    "openBatterySettings" -> Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    "openPowerSettings" -> Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
                    "openSamsungSettings" -> Intent("com.samsung.android.sm.ACTION_OPEN_CHECKABLE_LISTACTIVITY")
                        .setPackage("com.samsung.android.lool").putExtra("activity_type", 2)
                    else -> appSettingsIntent()
                }
                // Some OEMs omit these settings screens; app details is a safe fallback.
                try {
                    context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                } catch (_: ActivityNotFoundException) {
                    context.startActivity(appSettingsIntent())
                } catch (_: SecurityException) {
                    context.startActivity(appSettingsIntent())
                }
                result.success(true)
                return
            }
            val active = call.argument<Boolean>("active") == true
            if (call.method == "setActive" && active) {
                // Reacquiring a non-reference-counted lock refreshes its timeout.
                wakeLock?.acquire(120_000L)
            } else if (call.method == "setActive" && wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
            val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val activity = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val service = activity.getRunningServices(Int.MAX_VALUE).firstOrNull {
                it.service.className == "com.ryanheise.audioservice.AudioService"
            }
            result.success(mapOf(
                "held" to (wakeLock?.isHeld == true),
                "interactive" to power.isInteractive,
                "deviceIdle" to power.isDeviceIdleMode,
                "powerSaveMode" to power.isPowerSaveMode,
                "manufacturer" to Build.MANUFACTURER,
                "batteryExempt" to power.isIgnoringBatteryOptimizations(context.packageName),
                "serviceForeground" to (service?.foreground == true),
                "elapsedMs" to SystemClock.elapsedRealtime(),
                "uptimeMs" to SystemClock.uptimeMillis()
            ))
        } catch (error: Exception) {
            result.error("PLAYBACK_WAKE_GUARD", error.javaClass.simpleName, null)
        }
    }

    private fun appSettingsIntent() = Intent(
        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
        Uri.parse("package:${context.packageName}")
    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        if (wakeLock?.isHeld == true) wakeLock?.release()
        wakeLock = null
    }
}
