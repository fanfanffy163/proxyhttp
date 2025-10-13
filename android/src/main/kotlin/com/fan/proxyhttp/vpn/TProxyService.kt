package com.fan.proxyhttp.vpn

import android.content.Context
import android.os.ParcelFileDescriptor
import android.util.Log
import go.error
import java.io.File

/**
 * Manages the tun2socks process that handles VPN traffic
 */
class TProxyService(
    private val context: Context,
    private val vpnInterface: ParcelFileDescriptor,
    private val isRunningProvider: () -> Boolean,
    private val restartCallback: () -> Unit
) : Tun2SocksControl {
    companion object {
        @JvmStatic
        @Suppress("FunctionName")
        private external fun TProxyStartService(configPath: String, fd: Int)
        @JvmStatic
        @Suppress("FunctionName")
        private external fun TProxyStopService()
        @JvmStatic
        @Suppress("FunctionName")
        private external fun TProxyGetStats(): LongArray?

        init {
            System.loadLibrary("hev-socks5-tunnel")
        }
    }

    private val TAG = "proxy http jni";
    /**
     * Starts the tun2socks process with the appropriate parameters.
     */
    override fun startTun2Socks() {
        Log.i(TAG, "Starting HevSocks5Tunnel via JNI")

        val configContent = buildConfig()
        val configFile = File(context.filesDir, "hev-socks5-tunnel.yaml").apply {
            writeText(configContent)
        }
        Log.i(TAG, "Config file created: ${configFile.absolutePath}")
        Log.d(TAG, "Config content:\n$configContent")

        try {
            Log.i(TAG, "TProxyStartService...")
            TProxyStartService(configFile.absolutePath, vpnInterface.fd)
        } catch (e: Exception) {
            Log.e(TAG, "HevSocks5Tunnel exception: ${e.message}")
        }
    }

    private fun buildConfig(): String {
        return buildString {
            appendLine("tunnel:")
            appendLine("  mtu: ${ProxyHttpVpn.MAX_PACKET_LEN}")
            appendLine("  ipv4: ${ProxyHttpVpn.VIRTUAL_HOST}")

            appendLine("socks5:")
            appendLine("  port: 10808")
            appendLine("  address: 127.0.0.1")
            appendLine("  udp: 'udp'")

            appendLine("misc:")
            appendLine("  read-write-timeout: 300000")
            appendLine("  log-level: none")
        }
    }

    /**
     * Stops the tun2socks process
     */
    override fun stopTun2Socks() {
        try {
            Log.i(TAG, "TProxyStopService...")
            TProxyStopService()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop hev-socks5-tunnel", e)
        }
    }
}