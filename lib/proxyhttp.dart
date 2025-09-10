
import 'proxyhttp_platform_interface.dart';

class Proxyhttp {
  Future<String?> getPlatformVersion() {
    return ProxyhttpPlatform.instance.getPlatformVersion();
  }

  Future<void> startVpn(){
    return ProxyhttpPlatform.instance.startVpn();
  }

  Future<void> stopVpn(){
    return ProxyhttpPlatform.instance.stopVpn();
  }
}
