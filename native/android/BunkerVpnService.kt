package com.bunkercat.bunker_vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.OverrideOptions

/**
 * Owns the Android VPN service lifecycle.
 *
 * Initializes the native libbox runtime. The TUN interface is not established
 * until a user-supplied sing-box JSON profile is passed to libbox.
 * A started profile is not reported as connected until device-level TUN checks pass.
 */
class BunkerVpnService : VpnService() {
    private val tunController by lazy { AndroidTunController(this) }
    private var commandServer: CommandServer? = null
    private var platformInterface: BunkerPlatformInterface? = null

    private val commandHandler by lazy {
        BunkerCommandServerHandler(
            onStop = { stopLibbox() },
            onReload = { error("No active BUNKER profile to reload") },
        )
    }

    @Synchronized
    private fun startCommandServer() {
        if (commandServer != null) return
        val platform = BunkerPlatformInterface(::establishTun)
        val server = CommandServer(commandHandler, platform)
        try {
            server.start()
            platformInterface = platform
            commandServer = server
        } catch (error: Exception) {
            runCatching { server.close() }
            throw error
        }
    }

    /** Starts a validated sing-box JSON profile after profile import is wired to UI. */
    @Synchronized
    internal fun startProfile(configJson: String) {
        require(configJson.isNotBlank()) { "Profile configuration is empty" }
        startCommandServer()
        checkNotNull(commandServer).startOrReloadService(configJson, OverrideOptions())
        currentState = "PROFILE_STARTED"
        updateNotification("Профиль запущен")
    }

    @Synchronized
    private fun stopLibbox() {
        val server = commandServer ?: return
        runCatching { server.closeService() }
        runCatching { server.close() }
        commandServer = null
        platformInterface = null
        runCatching { closeTun() }
    }

    /** Called by the libbox PlatformInterface adapter when a profile requests TUN. */
    internal fun establishTun(options: TunOptions): Int = tunController.establish(options)

    /** Must be called only after libbox has stopped using the TUN descriptor. */
    internal fun closeTun() = tunController.close()

    companion object {
        const val ACTION_START = "com.bunkercat.bunker_vpn.action.START"
        const val ACTION_START_PROFILE = "com.bunkercat.bunker_vpn.action.START_PROFILE"
        const val EXTRA_PROFILE_JSON = "profile_json"
        const val ACTION_STOP = "com.bunkercat.bunker_vpn.action.STOP"

        private const val CHANNEL_ID = "bunker_vpn_status"
        private const val NOTIFICATION_ID = 4101

        @Volatile
        var currentState: String = "STOPPED"
            private set
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopLibbox()
                currentState = "STOPPED"
                stopForeground(true)
                stopSelf(startId)
            }
            ACTION_START, ACTION_START_PROFILE -> {
                val notification = buildNotification()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(
                        NOTIFICATION_ID,
                        notification,
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED
                    )
                } else {
                    startForeground(NOTIFICATION_ID, notification)
                }
                try {
                    LibboxRuntime.initialize(this)
                    startCommandServer()
                    if (intent.action == ACTION_START_PROFILE) {
                        val configJson = intent.getStringExtra(EXTRA_PROFILE_JSON)
                            ?: error("Profile JSON is missing")
                        startProfile(configJson)
                    } else {
                        currentState = "ENGINE_READY_NO_PROFILE"
                        updateNotification("Движок готов · профиль ещё не подключён")
                    }
                } catch (error: Exception) {
                    currentState = "ENGINE_ERROR"
                    updateNotification("Ошибка загрузки движка")
                    stopForeground(STOP_FOREGROUND_REMOVE)
                    stopSelf(startId)
                }
            }
        }
        return START_NOT_STICKY
    }

    override fun onRevoke() {
        currentState = "STOPPED"
        stopSelf()
        super.onRevoke()
    }

    override fun onDestroy() {
        stopLibbox()
        currentState = "STOPPED"
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = super.onBind(intent)

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Состояние BUNKER VPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Системное уведомление VPN-сервиса"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun updateNotification(message: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(message))
    }

    private fun buildNotification(
        message: String = "Инициализация сетевого движка…"
    ): Notification {
        val stopIntent = Intent(this, BunkerVpnService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            0,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("BUNKER VPN")
            .setContentText(message)
            .setOngoing(true)
            .addAction(
                Notification.Action.Builder(
                    android.R.drawable.ic_media_pause,
                    "Остановить",
                    stopPendingIntent
                ).build()
            )
            .build()
    }
}
