import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class HttpParseRes{
  http.Request? request;
  bool isChunked = false; // 是否需要继续等待更多数据
  HttpParseRes({this.request, this.isChunked = false});
}

class HttpParser {
  /// 将原始Socket字节数据解析为http.Request对象
  static http.Request parse(Uint8List data) {
    // 解析请求头（必须是文本）和请求体（可能是二进制）
    final headerEndIndex = _findHeaderEnd(data);
    
    if (headerEndIndex == -1) {
      throw FormatException('Could not find end of HTTP headers');
    }
    
    // 提取并解析请求头（只处理这部分的编码）
    final headerData = data.sublist(0, headerEndIndex);
    String headerString;
    
    // 更健壮的编码检测和处理
    try {
      // 尝试UTF-8
      headerString = utf8.decode(headerData, allowMalformed: false);
    } on FormatException {
      try {
        // 尝试Latin-1 (ISO-8859-1)
        headerString = latin1.decode(headerData);
      } on FormatException {
        // 最后尝试允许畸形的UTF-8
        headerString = utf8.decode(headerData, allowMalformed: true);
      }
    }

    // 解析请求行和头字段
    final headerLines = headerString.split('\r\n');
    if (headerLines.isEmpty) {
      throw FormatException('Missing request line in HTTP request');
    }

    // 解析请求行
    final requestLine = headerLines[0];
    final requestLineParts = requestLine.split(' ');
    if (requestLineParts.length != 3) {
      throw FormatException('Invalid request line format: $requestLine');
    }
    
    final method = requestLineParts[0];
    final path = requestLineParts[1];
    final httpVersion = requestLineParts[2];
    
    if (!httpVersion.startsWith('HTTP/')) {
      throw FormatException('Invalid HTTP version: $httpVersion');
    }

    // 解析请求头
    final headers = <String, String>{};
    for (int i = 1; i < headerLines.length; i++) {
      final line = headerLines[i];
      if (line.isEmpty) continue;
      
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) {
        throw FormatException('Invalid header format: $line');
      }
      
      final name = line.substring(0, colonIndex).trim();
      final value = line.substring(colonIndex + 1).trim();
      
      // 处理重复的头字段
      if (headers.containsKey(name)) {
        headers[name] = '${headers[name]}, $value';
      } else {
        headers[name] = value;
      }
    }

    // 处理请求体（直接使用原始字节，避免编码转换问题）
    Uint8List body = Uint8List(0);
    final bodyStartIndex = headerEndIndex + 4; // 跳过\r\n\r\n
    if (bodyStartIndex < data.length) {
      // 根据Content-Length验证体长度
      final contentLengthStr = headers['content-length'];
      if (contentLengthStr != null) {
        final contentLength = int.tryParse(contentLengthStr) ?? 0;
        final actualLength = data.length - bodyStartIndex;
        
        // 处理实际长度与声明长度不匹配的情况
        if (actualLength < contentLength) {
          body = data.sublist(bodyStartIndex);
        } else if (actualLength > contentLength) {
          body = data.sublist(bodyStartIndex, bodyStartIndex + contentLength);
        } else {
          body = data.sublist(bodyStartIndex);
        }
      } else {
        // 没有Content-Length时，使用所有剩余数据
        body = data.sublist(bodyStartIndex);
      }
    }

    // 处理内容编码
    // final contentEncoding = headers['content-encoding'];
    // if (contentEncoding != null) {
    //   body = _decodeBody(body, contentEncoding);
    // }

    // 创建请求对象
    final request = http.Request(method, Uri.parse(path));
    
    // 设置请求头
    headers.forEach((key, value) {
      if (key.toLowerCase() != 'content-length') {
        request.headers[key] = value;
      }
    });
    
    // 设置请求体
    request.bodyBytes = body;
    
    // 存储HTTP版本信息
    //request.headers['http-version'] = httpVersion;
    
    return request;
  }

  static HttpParseRes fromUint8List(Uint8List data) {
    final headerEndIndex = _findHeaderEnd(data);
    bool isChunked = false;
    http.Request? request;
    
    if (headerEndIndex != -1) {    
      // 解析Content-Length确定是否接收完整
      final headersData = data.sublist(0, headerEndIndex);
      String headersString;
      try {
        headersString = utf8.decode(headersData, allowMalformed: true);
      } catch (e) {
        headersString = latin1.decode(headersData);
      }
      
      final contentLengthMatch = RegExp(r'content-length:\s*(\d+)', caseSensitive: false)
          .firstMatch(headersString);
      
      if (contentLengthMatch != null) {
        final contentLength = int.tryParse(contentLengthMatch.group(1) ?? '0') ?? 0;
        final totalLength = headerEndIndex + 4 + contentLength;
        
        if (data.length >= totalLength) {
          request = parse(Uint8List.fromList(data.sublist(0, totalLength)));
        } else {
          // 继续等待更多数据
          isChunked = true;
        }
      } else if (headersString.contains(RegExp(r'transfer-encoding:\s*chunked', caseSensitive: false))) {
        // 处理分块传输编码
        if (_isChunkedDataComplete(data, headerEndIndex)) {
          request = parse(Uint8List.fromList(data));
        } else {
          isChunked = true;
        }
      } else {
        // 没有Content-Length且不是分块传输，假设已完成
        request = parse(Uint8List.fromList(data));
      }
    }
    return HttpParseRes(request: request, isChunked: isChunked);
  }
  
  /// 查找HTTP请求头的结束位置（\r\n\r\n）
  static int _findHeaderEnd(List<int> data) {
    for (int i = 3; i < data.length; i++) {
      if (data[i-3] == 13 && // \r
          data[i-2] == 10 && // \n
          data[i-1] == 13 && // \r
          data[i] == 10) {   // \n
        return i - 3;
      }
    }
    return -1;
  }
  
  /// 检查分块传输的数据是否完整
  static bool _isChunkedDataComplete(List<int> data, int headerEndIndex) {
    // 简化实现：检查是否包含0长度块的结束标记
    final bodyData = data.sublist(headerEndIndex + 4);
    try {
      final bodyString = utf8.decode(bodyData, allowMalformed: true);
      return bodyString.contains('\r\n0\r\n\r\n');
    } catch (e) {
      return false;
    }
  }
  
  /// 根据Content-Encoding解码请求体
  static Uint8List _decodeBody(Uint8List body, String encoding) {
    encoding = encoding.toLowerCase();
    
    if (encoding.contains('gzip')) {
      try {
        return gzip.decode(body) as Uint8List;
      } catch (e) {
        return body; // 解码失败时返回原始数据
      }
    } else if (encoding.contains('deflate')) {
      try {
        return zlib.decode(body) as Uint8List;
      } catch (e) {
        return body; // 解码失败时返回原始数据
      }
    }
    
    // 不支持的编码类型，返回原始数据
    return body;
  }

  // 将请求对象序列化回字节流以便发送
  static Uint8List serializeRequest(http.Request request) {
    // 自动更新 Content-Length
    //request.headers['content-length'] = request.bodyBytes.length.toString();
    // 移除 chunked 编码，因为我们现在是完整发送
    request.headers.remove('transfer-encoding');

    final requestLine = '${request.method} ${request.url} HTTP/1.1\r\n';
    final headersString = request.headers.entries
        .map((e) => '${e.key}: ${e.value}\r\n')
        .join('');
    final endOfHeaders = '\r\n';

    final head = utf8.encode(requestLine + headersString + endOfHeaders);
    return Uint8List.fromList([...head, ...request.bodyBytes]);
  }
}
    