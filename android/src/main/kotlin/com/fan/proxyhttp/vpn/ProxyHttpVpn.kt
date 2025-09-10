package com.fan.proxyhttp.vpn

import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap

class ProxyHttpVpn : VpnService() {
    private var vpnInterface: ParcelFileDescriptor? = null
    // 存储非HTTP流量的Socket连接（避免重复创建）
    private val directSockets = ConcurrentHashMap<String, Socket>()

    companion object {

        var proxyHost = "127.0.0.1";
        var proxyPort = 9090;

        val VPN_START_CODE = 100;

        val PROXY_HOST_KEY = "proxy_host";

        val PROXY_PORT_KEY = "proxy_port";

        val ACTION_DISCONNECT = "DISCONNECT"

        const val MAX_PACKET_LEN = 1500

        const val VIRTUAL_HOST = "10.0.0.2"


        fun startVpn(
            context: Activity,
            host : String?,
            port : Int?,
        ): Boolean {
            val intent = prepare(context)
            if(intent != null){
                proxyHost = host ?: proxyHost;
                proxyPort = port ?: proxyPort;
                context.startActivityForResult(intent, VPN_START_CODE);
            }else{
                context.startService(startVpnIntent(context));
            }
            return intent == null;
        }

        fun stopVpn(context: Context) {
            context.startService(stopVpnIntent(context));
        }

        fun stopVpnIntent(context: Context): Intent {
            return Intent(context, ProxyHttpVpn::class.java).also {
                it.action = ACTION_DISCONNECT
            }
        }

        fun startVpnIntent(
            context: Context,
        ): Intent {
            return Intent(context, ProxyHttpVpn::class.java).also {
                it.putExtra(PROXY_HOST_KEY, proxyHost)
                it.putExtra(PROXY_PORT_KEY, proxyPort)
            }
        }
    }

    override fun onStartCommand(
        intent: Intent,
        flags: Int,
        startId: Int
    ): Int {
        return if (intent.action == ACTION_DISCONNECT) {
            disconnect()
            START_NOT_STICKY
        } else {
            val proxyHost = intent.getStringExtra(PROXY_HOST_KEY) ?: "127.0.0.1";
            val proxyPort = intent.getIntExtra(PROXY_PORT_KEY, 9099)
            connect(proxyHost, proxyPort)
            START_STICKY
        }
    }

    private fun connect(proxyHost: String, proxyPort: Int) {
        Log.i("ProxyHttpVpn", "startVpn $proxyHost:$proxyPort ")

        val build = Builder()
            .setMtu(MAX_PACKET_LEN)
            .addAddress(VIRTUAL_HOST, 32)
            .addRoute("0.0.0.0", 0)
            .setSession(baseContext.applicationInfo.name)
            .setBlocking(true)

        build.setConfigureIntent(
            PendingIntent.getActivity(
                this,
                0,
                packageManager.getLaunchIntentForPackage(packageName),
                PendingIntent.FLAG_IMMUTABLE
            )
        )

        vpnInterface = build.apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                setMetered(false)
                setHttpProxy(ProxyInfo.buildDirectProxy(proxyHost, proxyPort))
            }
        }.establish()

        if(vpnInterface != null){

        }
    }

    private fun disconnect(){
        vpnInterface?.close();
        // 关闭所有直接连接的Socket
        directSockets.values.forEach { it.close() }
        directSockets.clear()
    }

    override fun onDestroy() {
        super.onDestroy()
        disconnect()
    }
}