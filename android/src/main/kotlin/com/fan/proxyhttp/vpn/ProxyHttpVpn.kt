package com.fan.proxyhttp.vpn

import android.app.Activity
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.StrictMode
import android.util.Log
import com.fan.proxyhttp.util.Utils
import java.lang.ref.SoftReference

class ProxyHttpVpn : VpnService(), ServiceControl {
    private var vpnInterface: ParcelFileDescriptor? = null
    private var isRunning = false

    private var tun2SocksService: Tun2SocksControl? = null

    companion object {

        private var proxyHost = "127.0.0.1"
        private var proxyPort = 9090
        private var socks5Port = 10808

        const val VPN_START_CODE = 1001;

        const val ACTION_DISCONNECT = "DISCONNECT"
        const val ACTION_CONNECT = "CONNECT"

        const val MAX_PACKET_LEN = 1500

        const val VIRTUAL_HOST = "10.0.0.2"

        fun getSock5Port() : Int { return socks5Port }
        fun getProxyHost() : String { return proxyHost }
        fun getProxyPort() : Int { return proxyPort }

        fun startVpn(
            context: Activity,
            host : String?,
            port : Int?,
        ): Boolean {
            val intent = prepare(context)
            proxyHost = host ?: proxyHost;
            proxyPort = port ?: proxyPort;
            if(intent != null){
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
                it.action = ACTION_CONNECT
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
            if(isRunning){
                disconnect()
            }

            seekFreeSock5Port()
            if(!V2RayManager.startCoreLoop()){
                return START_NOT_STICKY
            }

            connect(proxyHost, proxyPort)
            START_REDELIVER_INTENT
        }
    }

    private fun connect(proxyHost: String, proxyPort: Int) {
        Log.i("ProxyHttpVpn", "startVpn $proxyHost:$proxyPort ")

        val build = Builder()
            .setMtu(MAX_PACKET_LEN)
            .addAddress(VIRTUAL_HOST, 30)
            .addRoute("0.0.0.0", 0)
            .setSession(baseContext.applicationInfo.name)

        build.setConfigureIntent(
            PendingIntent.getActivity(
                this,
                0,
                packageManager.getLaunchIntentForPackage(packageName),
                PendingIntent.FLAG_IMMUTABLE
            )
        )

        build.addDisallowedApplication(this.packageName)

        vpnInterface = build.apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                setMetered(false)
                //setHttpProxy(ProxyInfo.buildDirectProxy(proxyHost, proxyPort))
            }
        }.establish()!!

        isRunning = true;
        runTun2socks()
    }

    private fun seekFreeSock5Port(){
        val portList = mutableListOf<Int>()
        for (tmpPort in 10808..10808+100) {
            portList.add(tmpPort)
        }
        socks5Port = Utils.findFreePort(portList)
    }

    /**
     * Runs the tun2socks process.
     * Starts the tun2socks process with the appropriate parameters.
     */
    private fun runTun2socks() {
        tun2SocksService = TProxyService(
            context = applicationContext,
            vpnInterface = vpnInterface!!,
            isRunningProvider = { isRunning },
            restartCallback = { runTun2socks() }
        )
        tun2SocksService?.startTun2Socks()
    }

    private fun disconnect(){
        tun2SocksService?.stopTun2Socks()
        tun2SocksService = null

        V2RayManager.stopCoreLoop();

        vpnInterface?.close();
        isRunning = false
    }

    override fun onDestroy() {
        super.onDestroy()
        disconnect()
    }

    override fun onCreate() {
        super.onCreate()
        val policy = StrictMode.ThreadPolicy.Builder().permitAll().build()
        StrictMode.setThreadPolicy(policy)
        V2RayManager.serviceControl = SoftReference(this)
    }

    override fun startService() {
        TODO("Not yet implemented")
    }

    override fun stopService() {
        disconnect()
    }

    override fun getService(): Service {
        return this;
    }

    override fun vpnProtect(socket: Int): Boolean {
        TODO("Not yet implemented")
    }
}