package com.fan.proxyhttp

import android.app.Activity
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

abstract class AbstractActivityAwarePlugin : ActivityAware {

    protected lateinit var activity : Activity;

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.activity = binding.activity;
    }

    override fun onDetachedFromActivityForConfigChanges() {
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
    }
}