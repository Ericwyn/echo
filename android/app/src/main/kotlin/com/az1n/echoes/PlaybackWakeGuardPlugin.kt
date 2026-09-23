package com.az1n.echoes

import android.annotation.SuppressLint
import android.app.ActivityManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Keeps the CPU awake across decoder completion and Dart-driven next-track work.
 * Dart sends a heartbeat while playback is requested. Explicit pause/stop releases
 * the lock; a missing heartbeat eventually releases it if Dart stops responding.
 */
class PlaybackWakeGuardPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private companion object {
        const val TAG = "EchoWakeGuard"
        const val HEARTBEAT_TIMEOUT_MS = 5 * 60_000L
    }

    private lateinit var context: Context
    private lateinit var channel: MethodChannel
    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())
    private var active = false
    private val heartbeatTimeout = Runnable {
        if (active) {
            Log.w(TAG, "heartbeat_timeout releasing playback lock")
            setPlaybackLock(false, "heartbeat_timeout")
        }
    }

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
            if (call.method == "setActive") {
                setPlaybackLock(
                    call.argument<Boolean>("active") == true,
                    call.argument<String>("reason") ?: "unknown"
                )
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

    @SuppressLint("WakelockTimeout") // Native heartbeat watchdog releases stale playback intent.
    private fun setPlaybackLock(requested: Boolean, reason: String) {
        active = requested
        handler.removeCallbacks(heartbeatTimeout)
        if (requested) {
            // A non-reference-counted acquire also reasserts the lock if an OEM
            // power manager dropped it while the Java object still reports held.
            val wasHeld = wakeLock?.isHeld == true
            wakeLock?.acquire()
            if (!wasHeld) {
                Log.i(TAG, "acquired reason=$reason")
            }
            handler.postDelayed(heartbeatTimeout, HEARTBEAT_TIMEOUT_MS)
        } else if (wakeLock?.isHeld == true) {
            wakeLock?.release()
            Log.i(TAG, "released reason=$reason")
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        setPlaybackLock(false, "engine_detached")
        wakeLock = null
    }
}
