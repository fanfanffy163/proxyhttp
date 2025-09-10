package com.fan.proxyhttp_example

import android.content.Intent
import com.fan.proxyhttp.ProxyhttpPlugin
import com.fan.proxyhttp.vpn.ProxyHttpVpn
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity(){
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if(resultCode == ProxyHttpVpn.Companion.VPN_START_CODE){
            if (resultCode == RESULT_OK) {
                activity.startService(ProxyHttpVpn.startVpnIntent(activity))
                return
            }
        }
    }

    /**
     * 注册插件
     */
    private fun pluginRegister(flutterEngine: FlutterEngine) {
        flutterEngine.plugins.add(ProxyhttpPlugin())
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pluginRegister(flutterEngine)
    }
}