import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logger/logger.dart';
import 'package:proxyhttp/http_interceptor.dart';
import 'package:proxyhttp/socket_to_http_request.dart';

enum ProtocolType { http, https, unknown }

class HttpProxyServer {
  late ServerSocket _server;
  HttpInterceptor? _interceptor;
  final String host; // 本地服务端地址（默认 127.0.0.1）
  final int port;    // 本地服务端端口（默认 8080）
  final Logger _logger;

  HttpProxyServer({this.host = '127.0.0.1', this.port = 8080, Level logLevel = Level.info})
      : _logger = Logger(
          printer: PrettyPrinter(
            printEmojis: true,
          ),
          level: logLevel,
        );

  // 设置 HTTP 拦截器
  HttpProxyServer withInterceptor(HttpInterceptor interceptor) {
    _interceptor = interceptor;
    return this;
  }

  // 启动代理服务端
  Future<void> start() async {
    try {
      _server = await ServerSocket.bind(host, port);
      _logger.i('Flutter 本地代理服务端已启动：$host:$port');

      // 监听客户端连接（Xray 会连接这里）
      await for (final Socket clientSocket in _server) {
        _logger.i('接收到新连接：${clientSocket.remoteAddress}:${clientSocket.remotePort}');
        _handleClient(clientSocket); // 处理单个客户端请求
      }
    } catch (e) {
      _logger.e('服务端启动失败', error: e);
    }
  }

  // 辅助函数：比较两个字节数组是否相等（用于检测结束标志）
  bool bytesAreEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // 处理单个客户端（Xray）的请求
  Future<void> _handleClient(Socket clientSocket) async {
	final clientSocketBroadcast = clientSocket.asBroadcastStream();
    try {
      // 1. 读取客户端（Xray）发送的代理请求头
      final requestBuffer = BytesBuilder();
      await for (final Uint8List chunk in clientSocketBroadcast) {
        requestBuffer.add(chunk);
        // 按 HTTP 协议规则：请求头以 "\r\n\r\n" 结束，读取到结束符则停止
        // 检测结束标志：优化为检查缓冲区末尾是否包含 \r\n\r\n
        // 避免每次转换整个缓冲区，只检查最后几个字节（更高效）
        final buffer = requestBuffer.toBytes();
        if (buffer.length >= 4) {
          // 取最后4个字节（\r\n\r\n 共4个字节）
          final last4Bytes = buffer.sublist(buffer.length - 4);
          if (bytesAreEqual(last4Bytes, utf8.encode('\r\n\r\n'))) {
            break; // 检测到完整结束标志，退出循环
          }
        }
      }
      final requestBytes = requestBuffer.toBytes();
      final requestStr = utf8.decode(requestBytes);
      _logger.i('收到代理请求：\n$requestStr');

      // 2. 解析请求头，提取代理关键信息
      final parsed = _parseProxyRequest(requestStr);
      if (parsed == null) {
        _sendErrorResponse(clientSocket, '400 Bad Request', '无效的代理请求格式');
        return;
      }

      final method = parsed['method'];
      final targetHost = parsed['host'];
      final targetPort = parsed['port'];
      final requestHeader = parsed['header'];

      // 3. 分类型处理请求（普通 HTTP 请求 / CONNECT 隧道请求）
      if (method == 'CONNECT') {
        // 处理 HTTPS 代理：建立 Xray 与目标服务器的双向隧道
        await _handleConnect(clientSocket,clientSocketBroadcast, targetHost, targetPort);
      } else {
        // 处理普通 HTTP 代理：转发请求到目标服务器，返回响应
        await _handleHttpForward(clientSocket, method, targetHost, targetPort, requestHeader, requestBytes);
      }

    } catch (e, stackTrace) {
      _logger.e('处理客户端请求失败', error: e, stackTrace: stackTrace);
    } finally {
      // 关闭客户端连接（避免资源泄漏）
      await clientSocket.done;
    }
  }

  // 解析代理请求头：提取 method、host、port、完整 header
  Map<String, dynamic>? _parseProxyRequest(String requestStr) {
    final lines = requestStr.split('\r\n');
    if (lines.isEmpty) return null;

    // 解析第一行（请求行）：如 "GET http://example.com/path HTTP/1.1" 或 "CONNECT example.com:443 HTTP/1.1"
    final requestLine = lines[0].trim();
    final parts = requestLine.split(RegExp(r'\s+'));
    if (parts.length != 3) return null;

    final method = parts[0];
    final target = parts[1];
    final protocol = parts[2];

    String targetHost;
    int targetPort;

    if (method == 'CONNECT') {
      // CONNECT 方法的目标格式："example.com:443"（无 http://）
      final hostPort = target.split(':');
      if (hostPort.length != 2) return null;
      targetHost = hostPort[0];
      targetPort = int.tryParse(hostPort[1]) ?? 443;
    } else {
      // 普通方法的目标格式："http://example.com:80/path"
      final uri = Uri.tryParse(target);
      if (uri == null || uri.host.isEmpty) return null;
      targetHost = uri.host;
      targetPort = uri.port;
    }

    // 重组完整请求头（去掉原请求行的完整 URL，替换为普通路径）
    final headerLines = <String>[
      if (method != 'CONNECT') '$method ${Uri.parse(target).path} $protocol', // 普通请求：替换请求行
      if (method == 'CONNECT') requestLine, // CONNECT 请求：保留原请求行
      ...lines.sublist(1).takeWhile((line) => line.isNotEmpty), // 保留其他头信息（Host、User-Agent 等）
      '\r\n' // 结束符
    ];
    final requestHeader = headerLines.join('\r\n');

    return {
      'method': method,
      'host': targetHost,
      'port': targetPort,
      'header': requestHeader,
      'fullRequest': requestStr
    };
  }

  // 处理 CONNECT 方法（HTTPS 代理隧道）
	Future<void> _handleConnect(Socket clientSocket, Stream<Uint8List> clientSocketBroadcast, String targetHost, int targetPort) async {
	Socket? targetSocket; // 声明为可空，以便在 catch 和 finally 中使用

	try {
		// 1. 连接目标服务器（如 example.com:443）
		targetSocket = await Socket.connect(targetHost, targetPort);
		_logger.i('已连接目标服务器：$targetHost:$targetPort');

		// 3. 建立双向数据转发：Xray ↔ 目标服务器
		// 这是正确且可靠的方式
		bool clientClosed = false;
		final BytesBuilder requestBuffer = BytesBuilder();
		clientSocketBroadcast.listen(
			(data) async{
				//targetSocket?.add(data);
				try{
					if(_interceptor == null){
						targetSocket?.add(data);
						return;
					}

					requestBuffer.add(data);
					final parseRes = HttpParser.fromUint8List(requestBuffer.toBytes());
					if(!parseRes.isChunked && !await _interceptor!.onRequest(parseRes.request!)){
						targetSocket?.add(HttpParser.serializeRequest(parseRes.request!));
            requestBuffer.clear();
					}
				}catch(e,stackTrace){
					_logger.e('Xray ↔ 目标服务器 转发错误', error: e, stackTrace: stackTrace);
				}
				
			},
			onError: (e) {
				_logger.e('Xray → 目标服务器转发错误,',error: e);
				targetSocket?.destroy(); // 出错时销毁对方 socket
				clientClosed = true;
			},
			onDone: () async {
				await targetSocket?.close();
				clientClosed = true;
			}  // 一方关闭后，关闭另一方
		);

		targetSocket.listen(
			(data) {
				try{
					if(!clientClosed){
						clientSocket.add(data);
					}
				}catch(e,stackTrace){
					_logger.e('目标服务器 → Xray 转发错误', error: e, stackTrace: stackTrace);
				}
			},
			onError: (e) {
				_logger.e('目标服务器 → Xray 转发错误',error: e);
				clientSocket.destroy(); // 出错时销毁对方 socket
			},
			onDone: () async {
				if(!clientClosed){
					await clientSocket.close(); // 一方关闭后，关闭另一方
				}
			}
		);

		// 2. 向 Xray 发送 "200 Connection Established" 响应（表示隧道建立成功）
		clientSocket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
		await clientSocket.flush();

	} catch (e) {
		_sendErrorResponse(clientSocket, '502 Bad Gateway', '无法连接目标服务器：$e');
		// 确保在发生异常时关闭所有打开的套接字
		await clientSocket.close();
		await targetSocket?.close();
	}
	}

  // 处理普通 HTTP 代理（转发 GET/POST 等请求）
	Future<void> _handleHttpForward(
	Socket clientSocket,
	String method,
	String targetHost,
	int targetPort,
	String requestHeader,
	Uint8List requestBytes // 完整原始请求
	) async {
	try {
		// 1. 连接目标服务器
		final targetSocket = await Socket.connect(targetHost, targetPort);
		_logger.i('已连接目标服务器：$targetHost:$targetPort');

		// 2. 向目标服务器发送重组后的请求头
		targetSocket.write(requestHeader);
		// (不再需要 await targetSocket.flush()，可以在后面统一 flush)

		// ------------------- FIX START -------------------
		// 3. 分离并转发请求体（Body）
		// 找到原始请求中请求头和请求体的分隔符 "\r\n\r\n"
		final separator = utf8.encode('\r\n\r\n');
		int bodyIndex = -1;
		for (int i = 0; i <= requestBytes.length - separator.length; i++) {
			// 这是一个简单的查找，对于超大请求头性能一般，但通常足够
			bool found = true;
			for (int j = 0; j < separator.length; j++) {
				if (requestBytes[i + j] != separator[j]) {
					found = false;
					break;
				}
			}
			if (found) {
				bodyIndex = i + separator.length;
				break;
			}
		}
		
		// 如果找到了请求体（即存在 "\r\n\r\n"），则转发它
		if (bodyIndex != -1 && bodyIndex < requestBytes.length) {
			final requestBody = requestBytes.sublist(bodyIndex);
			if (requestBody.isNotEmpty) {
				_logger.i('Forwarding HTTP body of length: ${requestBody.length}');
				targetSocket.add(requestBody);
			}
		}
		// -------------------- FIX END --------------------

		await targetSocket.flush(); // 确保请求头和可能的请求体都已发出

		 // 4. 接收目标服务器的响应，转发给 Xray
		await for (final chunk in targetSocket) {
			clientSocket.add(chunk);
			await clientSocket.flush();
		}

		// 5. pipe 会在完成后自动处理关闭，但显式关闭可以确保资源释放
		await targetSocket.close();
		await clientSocket.close();

	} catch (e) {
		_sendErrorResponse(clientSocket, '502 Bad Gateway', '转发请求失败：$e');
	}
	}

  // 向 Xray 发送错误响应（如 400、502）
  void _sendErrorResponse(Socket clientSocket, String status, String message) {
    final response = '''HTTP/1.1 $status
      Content-Type: text/plain
      Content-Length: ${message.length}

    $message\r\n''';
    clientSocket.write(response);
    clientSocket.flush();
    _logger.i('发送错误响应：$status - $message');
  }

  // 停止代理服务端
  Future<void> stop() async {
    await _server.close();
    _logger.i('Flutter 本地代理服务端已停止');
  }

  // 判断协议类型
  static ProtocolType detectProtocol(Uint8List data) {
    // 根据数据特征判断
    if (data.isEmpty) {
      return ProtocolType.unknown;
    }

    // 检查是否可能是HTTPS的TLS握手
    // TLS握手通常以0x16开始
    if (data[0] == 0x16) {
      return ProtocolType.https;
    }

    // 检查是否是HTTP明文（以常见HTTP方法开头）
    String startStr;
    try {
      // 尝试将前几个字节转换为字符串
      startStr = utf8.decode(data.sublist(0, data.length < 10 ? data.length : 10));
      
      // 常见的HTTP方法
      const httpMethods = ['GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'OPTIONS', 'PATCH'];
      for (var method in httpMethods) {
        if (startStr.startsWith(method)) {
          return ProtocolType.http;
        }
      }
    } catch (e) {
      // 无法转换为字符串，可能是二进制数据（HTTPS）
      return ProtocolType.https;
    }

    return ProtocolType.unknown;
  }

  // 从字节数据中提取Unicode字符（UTF-8）
	static String extractUnicodeCharacters(Uint8List data) {
	// 使用允许畸形字节的UTF-8解码器
	// 无效字节会被替换为 �（Unicode替换字符 U+FFFD）
	final decoder = Utf8Decoder(allowMalformed: true);
	return decoder.convert(data);
	}
}