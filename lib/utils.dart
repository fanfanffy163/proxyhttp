import 'dart:io';

import 'package:flutter/foundation.dart';

class Utils {
  static List<String> splitUntil(String text, String separator, {int maxParts = -1}) {
    List<String> result = [];
    if(maxParts == -1){
      return text.split(separator);
    }else{
      int startIndex = 0;
      int count = 0;
      while (count < maxParts) {
        int index = text.indexOf(separator, startIndex);
        if (index == -1) break;

        result.add(text.substring(startIndex, index));
        startIndex = index + separator.length;
        count++;
      }

      // 添加剩余部分
      result.add(text.substring(startIndex));
      return result;
    }
  }


  static Future<bool> isPortInUse(int port, {String address = '127.0.0.1'}) async {
    ServerSocket? serverSocket;
    try {
      // 尝试绑定到指定地址和端口
      serverSocket = await ServerSocket.bind(address, port);
      // 如果绑定成功，说明端口未被占用，立即关闭并返回 false
      await serverSocket.close();
      return false;
    } on SocketException catch (e) {
      // 捕获到 SocketException，通常意味着端口已被占用或无权访问
      debugPrint('SocketException on port $port: ${e.message}');
      return true;
    } catch (e) {
      // 捕获其他可能的异常
      debugPrint('An unexpected error occurred on port $port: $e');
      return true; // 将其他异常也视为端口不可用
    }
  }
}

