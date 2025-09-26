package com.fan.proxyhttp.util

import android.content.Context
import android.provider.Settings
import android.util.Base64
import android.util.Log

object Utils {
    private val TAG = "app utils";

    /**
     * Get the path to the user asset directory.
     *
     * @param context The context to use.
     * @return The path to the user asset directory.
     */
    fun userAssetPath(context: Context?): String {
        if (context == null) return ""

        return try {
            context.getExternalFilesDir("assets")?.absolutePath
                ?: context.getDir("assets", 0).absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get user asset path", e)
            ""
        }
    }

    /**
     * Get the device ID for XUDP base key.
     *
     * @return The device ID for XUDP base key.
     */
    fun getDeviceIdForXUDPBaseKey(): String {
        return try {
            val androidId = Settings.Secure.ANDROID_ID.toByteArray(Charsets.UTF_8)
            Base64.encodeToString(androidId.copyOf(32), Base64.NO_PADDING.or(Base64.URL_SAFE))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to generate device ID", e)
            ""
        }
    }


    /**
     * Read text from an asset file.
     *
     * @param context The context to use.
     * @param fileName The name of the asset file.
     * @return The content of the asset file as a string.
     */
    fun readTextFromAssets(context: Context?, fileName: String): String {
        if (context == null) return ""

        return try {
            context.assets.open(fileName).use { inputStream ->
                inputStream.bufferedReader().use { reader ->
                    reader.readText()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read asset file: $fileName", e)
            ""
        }
    }

}