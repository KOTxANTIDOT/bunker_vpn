package com.bunkercat.bunker_vpn

import io.nekohasekai.libbox.BridgeOptions
import io.nekohasekai.libbox.BridgeSession
import io.nekohasekai.libbox.ConnectionOwner
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NeighborUpdateListener
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.Notification
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.PlatformUser
import io.nekohasekai.libbox.ShellSession
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState

/**
 * Minimal Android adapter for the pinned libbox API.
 *
 * Optional OS integrations are deliberately unavailable until implemented.
 * Required network operations fail explicitly instead of returning fake data.
 */
internal class BunkerPlatformInterface(
    private val openTun: (TunOptions) -> Int,
) : PlatformInterface {
    override fun localDNSTransport(): LocalDNSTransport? = null

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun autoDetectInterfaceControl(fd: Int) = Unit

    override fun openTun(options: TunOptions): Int = openTun.invoke(options)

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int,
    ): ConnectionOwner = error("Connection-owner lookup is not implemented yet")

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) = Unit

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) = Unit

    override fun getInterfaces(): NetworkInterfaceIterator =
        error("Android network-interface enumeration is not implemented yet")

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun readWIFIState(): WIFIState? = null

    override fun clearDNSCache() = Unit

    override fun startNeighborMonitor(listener: NeighborUpdateListener?) = Unit

    override fun closeNeighborMonitor(listener: NeighborUpdateListener?) = Unit

    override fun cancelNotification(identifier: String, typeID: Int) = Unit

    override fun sendNotification(notification: Notification) = Unit

    override fun useProcFS(): Boolean = false

    override fun usePlatformShell(): Boolean = false

    override fun checkPlatformShell() {
        error("Platform shell access is not supported")
    }

    override fun openShellSession(
        user: PlatformUser?,
        command: String?,
        environ: StringIterator?,
        term: String?,
        rows: Int,
        cols: Int,
    ): ShellSession = error("Platform shell access is not supported")

    override fun lookupUser(username: String?): PlatformUser =
        error("Platform user lookup is not implemented yet")

    override fun lookupSFTPServer(): String = error("SFTP is not supported")

    override fun readSystemSSHHostKey(): String = error("System SSH host key is not available")

    override fun tailscaleHostname(): String = ""

    override fun usePlatformBridge(): Boolean = false

    override fun createBridge(options: BridgeOptions?): BridgeSession =
        error("Platform bridge is not supported")

    override fun registerMyInterface(name: String?) = Unit
}
