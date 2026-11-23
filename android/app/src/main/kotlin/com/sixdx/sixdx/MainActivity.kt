package com.sixdx.sixdx

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // SecureScreen (lib/core/security/secure_screen.dart): FLAG_SECURE keeps
        // sensitive screens out of screenshots, recordings and recent apps.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sixdx/secure_window")
            .setMethodCallHandler { call, result ->
                if (call.method == "setSecure") {
                    if (call.arguments as? Boolean == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
