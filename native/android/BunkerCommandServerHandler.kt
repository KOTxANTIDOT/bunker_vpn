package com.bunkercat.bunker_vpn

import android.util.Log
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.SystemProxyStatus

/** Command callbacks owned by BunkerVpnService. */
internal class BunkerCommandServerHandler(
    private val onStop: () -> Unit,
    private val onReload: () -> Unit,
) : CommandServerHandler {
    override fun serviceStop() = onStop.invoke()

    override fun serviceReload() = onReload.invoke()

    override fun getSystemProxyStatus(): SystemProxyStatus {
        return SystemProxyStatus().apply {
            available = false
            enabled = false
        }
    }

    override fun setSystemProxyEnabled(isEnabled: Boolean) {
        error("Android system proxy integration is not available")
    }

    override fun triggerNativeCrash() {
        error("Native crash trigger is disabled in production")
    }

    override fun writeDebugMessage(message: String?) {
        Log.d("BUNKER-libbox", message.orEmpty())
    }

    override fun connectSSHAgent(): Int = -1
}
