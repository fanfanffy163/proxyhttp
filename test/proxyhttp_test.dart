import 'package:flutter_test/flutter_test.dart';
import 'package:proxyhttp/proxyhttp.dart';
import 'package:proxyhttp/proxyhttp_platform_interface.dart';
import 'package:proxyhttp/proxyhttp_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockProxyhttpPlatform
    with MockPlatformInterfaceMixin
    implements ProxyhttpPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
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

    expect(await proxyhttpPlugin.getPlatformVersion(), '42');
  });
}
