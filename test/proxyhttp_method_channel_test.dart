import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxyhttp/proxyhttp_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelProxyhttp platform = MethodChannelProxyhttp();
  const MethodChannel channel = MethodChannel('proxyhttp');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getCoreVersion', () async {
    expect(await platform.getCoreVersion(), '42');
  });
}
