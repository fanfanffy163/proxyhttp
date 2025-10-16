
import 'proxyhttp_platform_interface.dart';

class Proxyhttp {
  Future<String?> getCoreVersion() {
    return ProxyhttpPlatform.instance.getCoreVersion();
  }

  Future<void> startVpn({String proxyHost = "127.0.0.1",int proxyPort = 9090}){
    return ProxyhttpPlatform.instance.startVpn(proxyHost: proxyHost,proxyPort: proxyPort);
  }

  Future<void> stopVpn(){
    return ProxyhttpPlatform.instance.stopVpn();
  }
}
