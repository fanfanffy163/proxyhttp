import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

// 根目录路由处理器
Response _rootHandler(Request request) {
  debugPrint('Received request: $request');
  return Response.ok('Hello, World!\n'
      'This is a local HTTP server running in your Flutter app.');
}

void startLocalServer() async {
  // 定义管道来处理所有请求。
  // 它先记录请求，然后通过路由器处理请求。
  final handler = Pipeline().addMiddleware(logRequests()).addHandler(_rootHandler);

  // 启动服务器
  final server = await shelf_io.serve(
    handler,
    InternetAddress.loopbackIPv4, // 监听本地回环地址，只能本地访问
    8081, // 监听端口
  );

  debugPrint('Serving at http://${server.address.host}:${server.port}');
}