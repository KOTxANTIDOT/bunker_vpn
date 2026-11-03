package com.bunkercat.bunker_vpn

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.system.OsConstants
import io.nekohasekai.libbox.BridgeOptions
import io.nekohasekai.libbox.BridgeSession
import io.nekohasekai.libbox.ConnectionOwner
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.Libbox
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
import java.net.Inet6Address
import java.net.InterfaceAddress
import java.net.NetworkInterface as JavaNetworkInterface
import io.nekohasekai.libbox.NetworkInterface as LibboxNetworkInterface

/**
 * Android adapter for the pinned libbox API.
 *
 * Optional OS integrations remain explicitly unsupported. Network-interface
 * data is collected from Android ConnectivityManager and Java network APIs.
 */
internal class BunkerPlatformInterface(
    context: Context,
    private val openTun: (TunOptions) -> Int,
) : PlatformInterface {
    private val connectivity =
        context.applicationContext.getSystemService(ConnectivityManager::class.java)

    @Volatile
    private var interfaceListener: InterfaceUpdateListener? = null

    @Volatile
    private var defaultNetworkCallback: ConnectivityManager.NetworkCallback? = null

    private val monitorLock = Any()

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

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        synchronized(monitorLock) {
            if (interfaceListener === listener && defaultNetworkCallback != null) {
                publishDefaultInterface(connectivity.activeNetwork, listener)
                return
            }
            stopDefaultInterfaceMonitor()
            interfaceListener = listener

            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    publishDefaultInterface(network, listener)
                }

                override fun onCapabilitiesChanged(
                    network: Network,
                    networkCapabilities: NetworkCapabilities,
                ) {
                    publishDefaultInterface(network, listener, networkCapabilities)
                }

                override fun onLinkPropertiesChanged(
                    network: Network,
                    linkProperties: android.net.LinkProperties,
                ) {
                    publishDefaultInterface(network, listener)
                }

                override fun onLost(network: Network) {
                    val active = connectivity.activeNetwork
                    if (active == null || active == network) {
                        listener.updateDefaultInterface("", -1, false, false)
                    } else {
                        publishDefaultInterface(active, listener)
                    }
                }
            }
            defaultNetworkCallback = callback
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    connectivity.registerDefaultNetworkCallback(callback)
                } else {
                    val request = NetworkRequest.Builder()
                        .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                        .build()
                    connectivity.registerNetworkCallback(request, callback)
                    publishDefaultInterface(connectivity.activeNetwork, listener)
                }
            } catch (error: Exception) {
                defaultNetworkCallback = null
                interfaceListener = null
                throw IllegalStateException("Could not monitor Android default network", error)
            }
        }
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        synchronized(monitorLock) {
            if (interfaceListener !== listener) return
            stopDefaultInterfaceMonitor()
        }
    }

    private fun stopDefaultInterfaceMonitor() {
        val callback = defaultNetworkCallback
        defaultNetworkCallback = null
        interfaceListener = null
        if (callback != null) {
            runCatching { connectivity.unregisterNetworkCallback(callback) }
        }
    }

    private fun publishDefaultInterface(
        network: Network?,
        listener: InterfaceUpdateListener,
        knownCapabilities: NetworkCapabilities? = null,
    ) {
        if (network == null) {
            listener.updateDefaultInterface("", -1, false, false)
            return
        }
        val properties = connectivity.getLinkProperties(network)
        val name = properties?.interfaceName
        if (name.isNullOrBlank()) {
            listener.updateDefaultInterface("", -1, false, false)
            return
        }
        val index = runCatching { JavaNetworkInterface.getByName(name)?.index ?: -1 }
            .getOrDefault(-1)
        val capabilities = knownCapabilities ?: connectivity.getNetworkCapabilities(network)
        val expensive = capabilities?.hasCapability(
            NetworkCapabilities.NET_CAPABILITY_NOT_METERED
        ) != true
        listener.updateDefaultInterface(name, index, expensive, false)
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val javaInterfaces = runCatching {
            JavaNetworkInterface.getNetworkInterfaces()?.toList().orEmpty()
        }.getOrElse { throw IllegalStateException("Could not enumerate Android network interfaces", it) }

        val result = mutableListOf<LibboxNetworkInterface>()
        for (network in connectivity.allNetworks) {
            val properties = connectivity.getLinkProperties(network) ?: continue
            val capabilities = connectivity.getNetworkCapabilities(network) ?: continue
            val name = properties.interfaceName ?: continue
            val systemInterface = javaInterfaces.firstOrNull { it.name == name } ?: continue

            val item = LibboxNetworkInterface().apply {
                this.name = name
                index = systemInterface.index
                mtu = runCatching { systemInterface.mtu }.getOrDefault(0)
                type = when {
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ->
                        Libbox.InterfaceTypeWIFI
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ->
                        Libbox.InterfaceTypeCellular
                    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) ->
                        Libbox.InterfaceTypeEthernet
                    else -> Libbox.InterfaceTypeOther
                }
                addresses = StringArray(
                    systemInterface.interfaceAddresses.map { it.toPrefix() }.iterator()
                )
                dnsServer = StringArray(
                    properties.dnsServers.mapNotNull { it.hostAddress }.iterator()
                )
                gateway = StringArray(
                    properties.routes
                        .filter { it.destination.prefixLength == 0 }
                        .mapNotNull { it.gateway }
                        .filterNot { it.isAnyLocalAddress }
                        .mapNotNull { it.hostAddress }
                        .iterator()
                )
                var interfaceFlags = 0
                if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                    interfaceFlags = interfaceFlags or OsConstants.IFF_UP or OsConstants.IFF_RUNNING
                }
                if (systemInterface.isLoopback) interfaceFlags = interfaceFlags or OsConstants.IFF_LOOPBACK
                if (systemInterface.isPointToPoint) interfaceFlags = interfaceFlags or OsConstants.IFF_POINTOPOINT
                if (systemInterface.supportsMulticast()) interfaceFlags = interfaceFlags or OsConstants.IFF_MULTICAST
                flags = interfaceFlags
                metered = !capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
            }
            result.add(item)
        }
        return InterfaceArray(result.distinctBy { it.name }.iterator())
    }

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

    private class InterfaceArray(
        private val iterator: Iterator<LibboxNetworkInterface>,
    ) : NetworkInterfaceIterator {
        override fun hasNext(): Boolean = iterator.hasNext()
        override fun next(): LibboxNetworkInterface = iterator.next()
    }

    private class StringArray(
        private val iterator: Iterator<String>,
    ) : StringIterator {
        override fun len(): Int = 0
        override fun hasNext(): Boolean = iterator.hasNext()
        override fun next(): String = iterator.next()
    }

    private fun InterfaceAddress.toPrefix(): String {
        val address = if (address is Inet6Address) {
            Inet6Address.getByAddress(address.address).hostAddress
        } else {
            address.hostAddress
        }
        return "$address/$networkPrefixLength"
    }
}
