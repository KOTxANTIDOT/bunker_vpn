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

/**
 * Owns the Android VPN service lifecycle.
 *
 * Initializes the native libbox runtime. The TUN interface is not established
 * until a validated profile and the command-server adapter are integrated.
 * This milestone does not route or protect network traffic.
 */
class BunkerVpnService : VpnService() {
    private val tunController by lazy { AndroidTunController(this) }

    /** Called by the libbox PlatformInterface adapter when a profile requests TUN. */
    internal fun establishTun(options: TunOptions): Int = tunController.establish(options)

    /** Must be called only after libbox has stopped using the TUN descriptor. */
    internal fun closeTun() = tunController.close()

    companion object {
        const val ACTION_START = "com.bunkercat.bunker_vpn.action.START"
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
                currentState = "STOPPED"
                stopForeground(true)
                stopSelf(startId)
            }
            ACTION_START -> {
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
                    currentState = "ENGINE_INITIALIZED_NO_PROFILE"
                    updateNotification("Движок загружен · профиль ещё не подключён")
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
        currentState = "STOPPED"
        runCatching { closeTun() }
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
