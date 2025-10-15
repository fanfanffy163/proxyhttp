import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:proxyhttp/http_interceptor.dart';
import 'package:proxyhttp/proxyhttp_server.dart';
import 'package:proxyhttp/proxyhttp.dart';
import 'package:http/http.dart' as http;
import 'package:proxyhttp/socket_to_http_request.dart';

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
  HttpProxyServer().withInterceptor(TestHttpInterceptor()).start();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _proxyhttpPlugin = Proxyhttp();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _proxyhttpPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
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
              child: Text('Running on: $_platformVersion\n'),
            ),
            ElevatedButton(
              onPressed: () {
                _proxyhttpPlugin.startVpn();
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
