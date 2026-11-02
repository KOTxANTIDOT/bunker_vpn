package com.bunkercat.bunker_vpn

import android.content.Context
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.SetupOptions
import java.io.File

/**
 * Process-wide initialization for the official sing-box libbox runtime.
 *
 * This prepares libbox paths only. It does not start a proxy service or
 * establish a VPN TUN interface.
 */
internal object LibboxRuntime {
    @Volatile
    private var initialized = false

    @Synchronized
    fun initialize(context: Context) {
        if (initialized) return

        val appContext = context.applicationContext
        val workingDirectory = File(appContext.filesDir, "sing-box")
        check(appContext.filesDir.mkdirs() || appContext.filesDir.isDirectory) {
            "Could not create libbox base directory"
        }
        check(workingDirectory.mkdirs() || workingDirectory.isDirectory) {
            "Could not create libbox working directory"
        }
        check(appContext.cacheDir.mkdirs() || appContext.cacheDir.isDirectory) {
            "Could not create libbox temporary directory"
        }

        val options = SetupOptions().apply {
            basePath = appContext.filesDir.absolutePath
            workingPath = workingDirectory.absolutePath
            tempPath = appContext.cacheDir.absolutePath
        }

        Libbox.setup(options)
        initialized = true
    }
}
