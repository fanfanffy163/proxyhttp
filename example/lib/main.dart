import 'dart:convert';
import 'dart:io';

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
    return false;
  }

  @override
  Future<bool> onResponse(http.Response response) async {
    final originalBody = response.bodyBytes;
    String? contentEncoding = response.headers['content-encoding']?.trim().toLowerCase();
    List<int> uncompressedBody;

    // 根据压缩类型解压响应体
    if (contentEncoding == 'gzip') {
      uncompressedBody = gzip.decode(originalBody);
    } else if (contentEncoding == 'deflate') {
      // 处理 deflate 压缩（注意：部分场景可能需要调整解压方式）
      uncompressedBody = zlib.decode(originalBody);
    } else {
      // 无压缩或不支持的压缩类型，直接使用原始数据
      uncompressedBody = originalBody;
    }

    // 构建状态行、头部和分隔符
    final statusLine = 'HTTP/1.1 ${response.statusCode} ${response.reasonPhrase ?? ''}\r\n';
    final headersString = response.headers.entries
        .map((e) => '${e.key}: ${e.value}\r\n')
        .join('');
    final endOfHeaders = '\r\n';

    // 拼接所有部分并返回
    final head = utf8.encode(statusLine + headersString + endOfHeaders);
    final r = Uint8List.fromList([...head, ...uncompressedBody]);
    print('response: ${HttpProxyServer.extractUnicodeCharacters(r)} ');
    return false;
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

    _server = HttpProxyServer(port: "9000-9003").withInterceptor(TestHttpInterceptor());
    await _server.start();

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _coreVersion = coreVersion;
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
              child: Text('Server running on port: $_serverPort\n'),
            ),
            ElevatedButton(
              onPressed: () {
                _proxyhttpPlugin.startVpn(proxyPort: _serverPort);
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
