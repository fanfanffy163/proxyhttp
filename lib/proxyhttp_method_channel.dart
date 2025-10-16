import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'proxyhttp_platform_interface.dart';

/// An implementation of [ProxyhttpPlatform] that uses method channels.
class MethodChannelProxyhttp extends ProxyhttpPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('proxyhttp');

  @override
  Future<String?> getCoreVersion() async {
    final version = await methodChannel.invokeMethod<String>('getCoreVersion');
    return version;
  }

  @override
  Future<void> startVpn({String proxyHost = "127.0.0.1",int proxyPort = 9090}) async {
    await methodChannel.invokeMethod('startVpn',<String, dynamic>{
      "proxyHost":proxyHost,
      "proxyPort":proxyPort
      });
  }

  @override
  Future<void> stopVpn() async {
    await methodChannel.invokeMethod('stopVpn');
  }
}
