import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class MetaInfo {
  late final String appVersion;
  late final String platformName;
  late final String deviceName;

  // Singleton
  static final MetaInfo _instance = MetaInfo._internal();
  static MetaInfo get instance => _instance;

  MetaInfo._internal();

  /// Initialize application meta information.
  /// This should be called once during app startup before other services are initialized.
  Future<void> initialize() async {
    appVersion = (await PackageInfo.fromPlatform()).version;
    platformName = Platform.operatingSystem;
    deviceName = _extractDeviceName(await DeviceInfoPlugin().deviceInfo);

    if (kDebugMode) {
      print(
        'AppInfo initialized - version: $appVersion, platform: $platformName, device: $deviceName',
      );
    }
  }

  /// The default User-Agent header used by network services.
  String get userAgent => 'TheBeike-GUI/$appVersion';

  String _extractDeviceName(BaseDeviceInfo deviceInfo) {
    if (deviceInfo is AndroidDeviceInfo) {
      return deviceInfo.name;
    } else if (deviceInfo is IosDeviceInfo) {
      return deviceInfo.name;
    } else if (deviceInfo is LinuxDeviceInfo) {
      return deviceInfo.prettyName;
    } else if (deviceInfo is MacOsDeviceInfo) {
      return deviceInfo.computerName;
    } else if (deviceInfo is WindowsDeviceInfo) {
      return deviceInfo.computerName;
    } else if (deviceInfo is WebBrowserInfo) {
      return deviceInfo.userAgent ?? 'Unknown(Web)';
    } else {
      return 'Unknown';
    }
  }
}
