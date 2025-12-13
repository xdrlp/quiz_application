package com.example.quiz_application

import android.view.accessibility.AccessibilityEvent
import android.accessibilityservice.AccessibilityService

class AppSwitchAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        AppSwitchEventBridge.sendEvent(
            mapOf(
                "type" to "service_state",
                "state" to "connected",
                "timestamp" to System.currentTimeMillis()
            )
        )
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOWS_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {}
            else -> return
        }

        val packageName = event.packageName?.toString() ?: return
        val className = event.className?.toString()

        AppSwitchEventBridge.sendEvent(
            mapOf(
                "type" to "accessibility_event",
                "eventType" to eventTypeToString(event.eventType),
                "packageName" to packageName,
                "className" to className,
                "timestamp" to event.eventTime
            )
        )
    }

    override fun onInterrupt() {
        AppSwitchEventBridge.sendEvent(
            mapOf(
                "type" to "service_state",
                "state" to "interrupted",
                "timestamp" to System.currentTimeMillis()
            )
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        AppSwitchEventBridge.sendEvent(
            mapOf(
                "type" to "service_state",
                "state" to "disconnected",
                "timestamp" to System.currentTimeMillis()
            )
        )
    }

    private fun eventTypeToString(type: Int): String {
        return when (type) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> "TYPE_WINDOW_STATE_CHANGED"
            AccessibilityEvent.TYPE_WINDOWS_CHANGED -> "TYPE_WINDOWS_CHANGED"
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> "TYPE_WINDOW_CONTENT_CHANGED"
            else -> type.toString()
        }
    }
}
