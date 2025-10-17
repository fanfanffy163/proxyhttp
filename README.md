# proxyhttp
A Flutter plugin project aim to proxy http(currently no https) traffic

## Dependencies
Using :
* xray core android lib wrapped by [v2rayNG](https://github.com/2dust/v2rayNG)
* [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) transporting tun traffic to socks5

## How to Use
### implements  HttpInterceptor
```dart
class TestHttpInterceptor implements HttpInterceptor{
	@override
	Future<bool> onRequest(http.Request request) async {
		return  false;
	}

	@override
	Future<bool> onResponse(http.Response response) async {
		final originalBody = response.bodyBytes;
		String? contentEncoding = response.headers['content-encoding']?.trim().toLowerCase();
		List<int> uncompressedBody;
		
		if (contentEncoding == 'gzip') {
			uncompressedBody = gzip.decode(originalBody);
		} else  if (contentEncoding == 'deflate') {
			uncompressedBody = zlib.decode(originalBody);
		} else {
			uncompressedBody = originalBody;
		}

		final statusLine = 'HTTP/1.1 ${response.statusCode}  ${response.reasonPhrase ?? ''}\r\n';
		final headersString = response.headers.entries
			.map((e) =>  '${e.key}: ${e.value}\r\n')
			.join('');
		final endOfHeaders = '\r\n';
		final head = utf8.encode(statusLine  +  headersString  +  endOfHeaders);
		final r = Uint8List.fromList([...head, ...uncompressedBody]);
		print('response: ${HttpProxyServer.extractUnicodeCharacters(r)} ');
		return false;
	}
}
```
### start local server
```dart
_server = HttpProxyServer(port:"9000-9003").withInterceptor(TestHttpInterceptor());
await _server.start();
```
### start vpn
```dart
_proxyhttpPlugin.startVpn(proxyPort: _serverPort);
```
you can look [example](example) for detail
