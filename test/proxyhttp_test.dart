import 'package:flutter_test/flutter_test.dart';
import 'package:proxyhttp/proxyhttp.dart';
import 'package:proxyhttp/proxyhttp_platform_interface.dart';
import 'package:proxyhttp/proxyhttp_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockProxyhttpPlatform
    with MockPlatformInterfaceMixin
    implements ProxyhttpPlatform {

  @override
  Future<String?> getCoreVersion() => Future.value('42');

  @override
  Future<void> startVpn({String proxyHost = "127.0.0.1",int proxyPort = 9090}) async {}

  @override
  Future<void> stopVpn() async {}
}

void main() {
  final ProxyhttpPlatform initialPlatform = ProxyhttpPlatform.instance;

  test('$MethodChannelProxyhttp is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelProxyhttp>());
  });

  test('getPlatformVersion', () async {
    Proxyhttp proxyhttpPlugin = Proxyhttp();
    MockProxyhttpPlatform fakePlatform = MockProxyhttpPlatform();
    ProxyhttpPlatform.instance = fakePlatform;

    expect(await proxyhttpPlugin.getCoreVersion(), '42');
  });
}
