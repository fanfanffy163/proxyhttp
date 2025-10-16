package com.fan.proxyhttp

import android.R
import com.fan.proxyhttp.vpn.ProxyHttpVpn
import com.fan.proxyhttp.vpn.V2RayManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** ProxyhttpPlugin */
class ProxyhttpPlugin :
    FlutterPlugin,
    MethodCallHandler,
    AbstractActivityAwarePlugin() {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "proxyhttp")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when(call.method){
            "getCoreVersion" ->{
                result.success(V2RayManager.getCoreVersion())
            }
            "startVpn" -> {
                val host = call.argument<String>("proxyHost")
                val port = call.argument<Int>("proxyPort")
                val res = ProxyHttpVpn.startVpn(activity, host, port);
                result.success(res)
            }
            "stopVpn" -> {
                ProxyHttpVpn.stopVpn(activity);
                result.success(null)
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
