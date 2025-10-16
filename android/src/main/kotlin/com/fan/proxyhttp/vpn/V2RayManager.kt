package com.fan.proxyhttp.vpn

import android.app.Service
import android.util.Log
import com.fan.proxyhttp.util.JsonUtil
import com.fan.proxyhttp.util.Utils
import com.fan.proxyhttp.vpn.V2rayConfig.OutboundBean.OutSettingsBean.ServersBean
import go.Seq
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import libv2ray.CoreCallbackHandler
import libv2ray.CoreController
import libv2ray.Libv2ray
import java.lang.ref.SoftReference

object V2RayManager {

    private val TAG = "app V2RayManager"
    private val coreController: CoreController = Libv2ray.newCoreController(CoreCallback())

    var serviceControl: SoftReference<ServiceControl>? = null
        set(value) {
            field = value
            Seq.setContext(value?.get()?.getService()?.applicationContext)
            Libv2ray.initCoreEnv(Utils.userAssetPath(value?.get()?.getService()), Utils.getDeviceIdForXUDPBaseKey())
        }

    fun getCoreVersion(): String{
        return Libv2ray.checkVersionX()
    }

    /**
     * Starts the V2Ray core service.
     */
    fun startCoreLoop(): Boolean {
        if (coreController.isRunning) {
            return true
        }

        val context = getService() ?: return false
        try {
            val config = Utils.readTextFromAssets(context, "v2ray_config.json")
            val v2rayConfig = JsonUtil.fromJson(config, V2rayConfig::class.java)

            //proxy port
            val outboundBean = v2rayConfig.getProxyOutboundByProtocol("http")
            val serversBean = ServersBean(address = ProxyHttpVpn.getProxyHost(), port = ProxyHttpVpn.getProxyPort())
            val serversBeanList = mutableListOf<ServersBean>()
            serversBeanList.add(serversBean)
            outboundBean?.settings?.servers = ArrayList(serversBeanList)

            //tun2sock5 port
            val inboundBean = v2rayConfig.inbounds[0]
            inboundBean.port = ProxyHttpVpn.getSock5Port()

            var cfg = JsonUtil.toJsonPretty(v2rayConfig)
            coreController.startLoop(cfg)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start Core loop", e)
            return false
        }

        return coreController.isRunning
    }

    /**
     * Stops the V2Ray core service.
     * Unregisters broadcast receivers, stops notifications, and shuts down plugins.
     * @return True if the core was stopped successfully, false otherwise.
     */
    fun stopCoreLoop(): Boolean {
        if (coreController.isRunning) {
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    coreController.stopLoop()
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to stop V2Ray loop", e)
                }
            }
        }
        return true
    }

    /**
     * Gets the current service instance.
     * @return The current service instance, or null if not available.
     */
    private fun getService(): Service? {
        return serviceControl?.get()?.getService()
    }
    
    private class CoreCallback : CoreCallbackHandler {
        /**
         * Called when V2Ray core starts up.
         * @return 0 for success, any other value for failure.
         */
        override fun startup(): Long {
            return 0
        }

        /**
         * Called when V2Ray core shuts down.
         * @return 0 for success, any other value for failure.
         */
        override fun shutdown(): Long {
            val serviceControl = serviceControl?.get() ?: return -1
            return try {
                serviceControl.stopService()
                0
            } catch (e: Exception) {
                Log.e(TAG, "Failed to stop service in callback", e)
                -1
            }
        }

        /**
         * Called when V2Ray core emits status information.
         * @param l Status code.
         * @param s Status message.
         * @return Always returns 0.
         */
        override fun onEmitStatus(l: Long, s: String?): Long {
            return 0
        }
    }
}