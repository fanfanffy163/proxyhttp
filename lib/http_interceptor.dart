import 'package:http/http.dart' as http;

abstract interface class HttpInterceptor {
  // 返回 false 继续处理，返回 true 则阻止
  Future<bool> onRequest(http.Request request){
    return Future.value(false);
  }

  Future<bool> onResponse(http.Response response){
    return Future.value(false);
  }
}