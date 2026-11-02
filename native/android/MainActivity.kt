package com.bunkercat.bunker_vpn

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "vpn.bunker/bridge"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "ping" -> result.success("pong")
                "getPlatformInfo" -> {
                    result.success(
                        mapOf(
                            "androidVersion" to Build.VERSION.RELEASE.orEmpty(),
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "manufacturer" to Build.MANUFACTURER.orEmpty(),
                            "model" to Build.MODEL.orEmpty()
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }
    }
}
