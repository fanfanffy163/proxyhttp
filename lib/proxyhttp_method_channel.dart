import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'proxyhttp_platform_interface.dart';

/// An implementation of [ProxyhttpPlatform] that uses method channels.
class MethodChannelProxyhttp extends ProxyhttpPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('proxyhttp');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> startVpn() async {
    await methodChannel.invokeMethod('startVpn');
  }

  @override
  Future<void> stopVpn() async {
    await methodChannel.invokeMethod('stopVpn');
  }
}
