package com.example.quiz_application

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object AppSwitchEventBridge : EventChannel.StreamHandler, MethodChannel.MethodCallHandler {
    private const val EVENT_CHANNEL = "anti_cheat/accessibility_events"
    private const val METHOD_CHANNEL = "anti_cheat/accessibility_control"

    private var appContext: Context? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun setup(context: Context, messenger: BinaryMessenger) {
        appContext = context.applicationContext
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isServiceEnabled" -> {
                val enabled = isServiceEnabled()
                result.success(enabled)
            }
            "openAccessibilitySettings" -> {
                openAccessibilitySettings()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun sendEvent(payload: Map<String, Any?>) {
        val sink = eventSink ?: return
        mainHandler.post { sink.success(payload) }
    }

    private fun isServiceEnabled(): Boolean {
        val context = appContext ?: return false
        val expectedId = "${context.packageName}/${AppSwitchAccessibilityService::class.java.name}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.split(':').any { it.equals(expectedId, ignoreCase = true) }
    }

    private fun openAccessibilitySettings() {
        val context = appContext ?: return
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}
