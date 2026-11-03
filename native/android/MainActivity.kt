package com.bunkercat.bunker_vpn

import android.content.Intent
import android.net.VpnService
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "vpn.bunker/bridge"
        const val REQUEST_VPN_PERMISSION = 7401
    }

    private var pendingVpnPermissionResult: MethodChannel.Result? = null

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
                "validateProfile" -> {
                    val configJson = call.argument<String>("configJson")
                    if (configJson.isNullOrBlank()) {
                        result.error("INVALID_PROFILE", "Profile JSON is empty.", null)
                    } else {
                        try {
                            Libbox.checkConfig(configJson)
                            result.success("CONFIG_VALID")
                        } catch (error: Exception) {
                            result.error("INVALID_PROFILE", error.message ?: "sing-box rejected the configuration.", null)
                        }
                    }
                }
                "requestVpnPermission" -> requestVpnPermission(result)
                "startVpnService" -> startVpnService(result)
                "startProfile" -> {
                    val configJson = call.argument<String>("configJson")
                    if (configJson.isNullOrBlank()) {
                        result.error("INVALID_PROFILE", "Profile JSON is empty.", null)
                    } else {
                        startProfile(configJson, result)
                    }
                }
                "stopVpnService" -> stopVpnService(result)
                "getVpnServiceState" -> result.success(BunkerVpnService.currentState)
                else -> result.notImplemented()
            }
        }
    }

    private fun requestVpnPermission(result: MethodChannel.Result) {
        if (pendingVpnPermissionResult != null) {
            result.error("PERMISSION_IN_PROGRESS", "VPN permission request is already active.", null)
            return
        }

        val permissionIntent = VpnService.prepare(this)
        if (permissionIntent == null) {
            result.success(true)
            return
        }

        pendingVpnPermissionResult = result
        try {
            startActivityForResult(permissionIntent, REQUEST_VPN_PERMISSION)
        } catch (error: Exception) {
            pendingVpnPermissionResult = null
            result.error("PERMISSION_REQUEST_FAILED", error.message, null)
        }
    }

    private fun startVpnService(result: MethodChannel.Result) {
        if (VpnService.prepare(this) != null) {
            result.error("VPN_PERMISSION_REQUIRED", "Grant Android VPN permission first.", null)
            return
        }

        val intent = Intent(this, BunkerVpnService::class.java).apply {
            action = BunkerVpnService.ACTION_START
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            result.success("START_REQUESTED")
        } catch (error: Exception) {
            result.error("VPN_SERVICE_START_FAILED", error.message, null)
        }
    }

    private fun startProfile(configJson: String, result: MethodChannel.Result) {
        if (VpnService.prepare(this) != null) {
            result.error("VPN_PERMISSION_REQUIRED", "Grant Android VPN permission first.", null)
            return
        }

        val intent = Intent(this, BunkerVpnService::class.java).apply {
            action = BunkerVpnService.ACTION_START_PROFILE
            putExtra(BunkerVpnService.EXTRA_PROFILE_JSON, configJson)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            result.success("PROFILE_START_REQUESTED")
        } catch (error: Exception) {
            result.error("PROFILE_START_FAILED", error.message, null)
        }
    }

    private fun stopVpnService(result: MethodChannel.Result) {
        val intent = Intent(this, BunkerVpnService::class.java).apply {
            action = BunkerVpnService.ACTION_STOP
        }
        try {
            startService(intent)
            result.success("STOP_REQUESTED")
        } catch (error: Exception) {
            result.error("VPN_SERVICE_STOP_FAILED", error.message, null)
        }
    }

    @Deprecated("Deprecated in Android SDK")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_VPN_PERMISSION) return

        val callback = pendingVpnPermissionResult ?: return
        pendingVpnPermissionResult = null
        callback.success(resultCode == RESULT_OK)
    }
}
