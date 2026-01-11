package com.example.quiz_application

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		AppSwitchEventBridge.setup(applicationContext, flutterEngine.dartExecutor.binaryMessenger)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quiz_application/screen_protector").setMethodCallHandler { call, result ->
			when (call.method) {
				"setSecure" -> {
					val enable = call.argument<Boolean>("enable") ?: false
					if (enable) {
						window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
					} else {
						window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
					}
					result.success(null)
				}
				else -> result.notImplemented()
			}
		}
	}
}
