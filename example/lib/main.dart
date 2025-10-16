import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:proxyhttp/http_interceptor.dart';
import 'package:proxyhttp/proxyhttp_server.dart';
import 'package:proxyhttp/proxyhttp.dart';
import 'package:http/http.dart' as http;

class TestHttpInterceptor implements HttpInterceptor {
  @override
  Future<bool> onRequest(http.Request request) async {
    //print('请求拦截: ${HttpProxyServer.extractUnicodeCharacters(HttpParser.serializeRequest(request))} ');
    return false; // 返回 true 继续处理请求，返回 false 则阻止请求
  }

  @override
  Future<bool> onResponse(http.Response response) async {
    //print('响应拦截: ${response.statusCode} ${response.request?.url}');
    return false; // 返回 true 继续处理响应，返回 false 则阻止响应
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _coreVersion = 'Unknown';
  int _serverPort = -1;
  final _proxyhttpPlugin = Proxyhttp();
  late HttpProxyServer _server;

  @override
  void initState(){
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String coreVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      coreVersion =
          await _proxyhttpPlugin.getCoreVersion() ?? 'Unknown core version';
    } on PlatformException {
      coreVersion = 'Failed to get core version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _coreVersion = coreVersion;
    });

    _server = HttpProxyServer(port: "9000-9003").withInterceptor(TestHttpInterceptor());
    await _server.start();
    setState(() {
      _serverPort = _server.getRunningPort();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          children: [
            Center(
              child: Text('Running on: $_coreVersion\n'),
            ),
            Center(
              child: Text('Server running on port: ${_server.getRunningPort()}\n'),
            ),
            ElevatedButton(
              onPressed: () {
                _proxyhttpPlugin.startVpn(proxyPort: _server.getRunningPort());
              },
              child: const Text('Start VPN'),
            ),
            ElevatedButton(
              onPressed: () {
                _proxyhttpPlugin.stopVpn();
              },
              child: const Text('Stop VPN'),
            ),
          ],
        ),
      ),
    );
  }
}
