package com.bunkercat.bunker_vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.IBinder

/**
 * Owns the Android VPN service lifecycle.
 *
 * The TUN interface is intentionally NOT established until the sing-box
 * engine adapter is integrated. Starting this shell service does not route
 * or protect network traffic.
 */
class BunkerVpnService : VpnService() {
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
                stopForeground(STOP_FOREGROUND_REMOVE)
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
                currentState = "SERVICE_READY_NO_ENGINE"
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

    private fun buildNotification(): Notification {
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
            .setContentText("Сервис готов · сетевой движок ещё не подключён")
            .setOngoing(true)
            .addAction(
                Notification.Action.Builder(
                    null,
                    "Остановить",
                    stopPendingIntent
                ).build()
            )
            .build()
    }
}
