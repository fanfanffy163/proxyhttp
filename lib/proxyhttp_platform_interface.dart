import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'proxyhttp_method_channel.dart';

abstract class ProxyhttpPlatform extends PlatformInterface {
  /// Constructs a ProxyhttpPlatform.
  ProxyhttpPlatform() : super(token: _token);

  static final Object _token = Object();

  static ProxyhttpPlatform _instance = MethodChannelProxyhttp();

  /// The default instance of [ProxyhttpPlatform] to use.
  ///
  /// Defaults to [MethodChannelProxyhttp].
  static ProxyhttpPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ProxyhttpPlatform] when
  /// they register themselves.
  static set instance(ProxyhttpPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getCoreVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<void> startVpn({String proxyHost = "127.0.0.1",int proxyPort = 9090}) async {}

  Future<void> stopVpn() async {}
}
