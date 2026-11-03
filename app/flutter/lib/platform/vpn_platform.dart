import 'package:flutter/services.dart';

class AndroidPlatformInfo {
  const AndroidPlatformInfo({
    required this.androidVersion,
    required this.sdkInt,
    required this.manufacturer,
    required this.model,
  });

  final String androidVersion;
  final int sdkInt;
  final String manufacturer;
  final String model;

  factory AndroidPlatformInfo.fromMap(Map<Object?, Object?> map) {
    return AndroidPlatformInfo(
      androidVersion: map['androidVersion'] as String? ?? 'Unknown',
      sdkInt: map['sdkInt'] as int? ?? 0,
      manufacturer: map['manufacturer'] as String? ?? 'Unknown',
      model: map['model'] as String? ?? 'Unknown',
    );
  }
}

class VpnPlatform {
  VpnPlatform({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('vpn.bunker/bridge');

  final MethodChannel _channel;

  Future<AndroidPlatformInfo> getPlatformInfo() async {
    final result =
        await _channel.invokeMapMethod<Object?, Object?>('getPlatformInfo');
    if (result == null) {
      throw PlatformException(
        code: 'EMPTY_PLATFORM_INFO',
        message: 'Android bridge returned no platform information.',
      );
    }
    return AndroidPlatformInfo.fromMap(result);
  }

  Future<void> validateProfile(String configJson) async {
    if (configJson.trim().isEmpty) {
      throw ArgumentError.value(configJson, 'configJson', 'Profile JSON is empty');
    }
    await _channel.invokeMethod<String>(
      'validateProfile',
      <String, Object>{'configJson': configJson},
    );
  }

  Future<bool> requestVpnPermission() async {
    return await _channel.invokeMethod<bool>('requestVpnPermission') ??
        false;
  }

  Future<void> startVpnService() async {
    await _channel.invokeMethod<String>('startVpnService');
  }

  Future<void> startProfile(String configJson) async {
    if (configJson.trim().isEmpty) {
      throw ArgumentError.value(configJson, 'configJson', 'Profile JSON is empty');
    }
    await _channel.invokeMethod<String>(
      'startProfile',
      <String, Object>{'configJson': configJson},
    );
  }

  Future<void> stopVpnService() async {
    await _channel.invokeMethod<String>('stopVpnService');
  }

  Future<String> getVpnServiceState() async {
    return await _channel.invokeMethod<String>('getVpnServiceState') ??
        'UNKNOWN';
  }

  Future<String> ping() async {
    final result = await _channel.invokeMethod<String>('ping');
    if (result == null || result.isEmpty) {
      throw PlatformException(
        code: 'EMPTY_PING',
        message: 'Android bridge returned an empty response.',
      );
    }
    return result;
  }
}
