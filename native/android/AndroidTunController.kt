package com.bunkercat.bunker_vpn

import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.net.ProxyInfo
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.RoutePrefix
import io.nekohasekai.libbox.RoutePrefixIterator

/**
 * Owns the Android TUN descriptor returned by VpnService.Builder.establish().
 *
 * The owner must keep this ParcelFileDescriptor open until libbox has stopped
 * the service. close() is idempotent and must be called after closeService().
 */
internal class AndroidTunController(
    private val vpnService: VpnService,
) {
    private var descriptor: ParcelFileDescriptor? = null

    @Synchronized
    fun establish(options: TunOptions): Int {
        check(descriptor == null) { "A TUN interface is already established" }

        check(VpnService.prepare(vpnService) == null) {
            "Android VPN permission is not granted"
        }

        val builder = vpnService.Builder()
            .setSession("BUNKER VPN")
            .setMtu(options.mtu)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        val ipv4 = options.inet4Address.toList()
        val ipv6 = options.inet6Address.toList()

        ipv4.forEach { builder.addAddress(it.address(), it.prefix()) }
        ipv6.forEach { builder.addAddress(it.address(), it.prefix()) }

        if (options.autoRoute) {
            if (options.dnsMode.value != Libbox.DNSModeDisabled) {
                options.dnsServerAddress.toList().forEach(builder::addDnsServer)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val ipv4Routes = options.inet4RouteAddress.toList()
                val ipv6Routes = options.inet6RouteAddress.toList()

                if (ipv4Routes.isNotEmpty()) {
                    ipv4Routes.forEach { builder.addRoute(it.toIpPrefix()) }
                } else if (ipv4.isNotEmpty()) {
                    builder.addRoute("0.0.0.0", 0)
                }

                if (ipv6Routes.isNotEmpty()) {
                    ipv6Routes.forEach { builder.addRoute(it.toIpPrefix()) }
                } else if (ipv6.isNotEmpty()) {
                    builder.addRoute("::", 0)
                }

                options.inet4RouteExcludeAddress.toList()
                    .forEach { builder.excludeRoute(it.toIpPrefix()) }
                options.inet6RouteExcludeAddress.toList()
                    .forEach { builder.excludeRoute(it.toIpPrefix()) }
            } else {
                options.inet4RouteRange.toList().forEach {
                    builder.addRoute(it.address(), it.prefix())
                }
                options.inet6RouteRange.toList().forEach {
                    builder.addRoute(it.address(), it.prefix())
                }
            }

            options.includePackage.toList().forEach { packageName ->
                runCatching { builder.addAllowedApplication(packageName) }
                    .getOrElse { throw IllegalArgumentException("Unknown allowed app: $packageName", it) }
            }
            options.excludePackage.toList().forEach { packageName ->
                runCatching { builder.addDisallowedApplication(packageName) }
                    .getOrElse { throw IllegalArgumentException("Unknown excluded app: $packageName", it) }
            }
        }

        if (options.isHTTPProxyEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setHttpProxy(
                ProxyInfo.buildDirectProxy(
                    options.httpProxyServer,
                    options.httpProxyServerPort,
                    options.httpProxyBypassDomain.toList(),
                )
            )
        }

        val established = builder.establish()
            ?: error("Android could not establish the VPN TUN interface")

        descriptor = established
        return established.fd
    }

    @Synchronized
    fun close() {
        val current = descriptor ?: return
        descriptor = null
        current.close()
    }

    @Synchronized
    fun isEstablished(): Boolean = descriptor != null

    private fun <T> io.nekohasekai.libbox.StringIterator.toList(): List<String> {
        val result = mutableListOf<String>()
        while (hasNext()) result += next()
        return result
    }

    private fun RoutePrefixIterator.toList(): List<RoutePrefix> {
        val result = mutableListOf<RoutePrefix>()
        while (hasNext()) result += next()
        return result
    }

    private fun RoutePrefix.toIpPrefix(): android.net.IpPrefix {
        return android.net.IpPrefix(address(), prefix())
    }
}
