import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

typedef DeviceFoundHandler = void Function(ScanResult result);

class BleClient {
  StreamSubscription<List<ScanResult>>? _scanSub;
  final Map<String, ScanResult> _seen = {};
  String? _connectedDeviceId;
  DeviceFoundHandler? onDeviceFound;

  bool get isConnected => _connectedDeviceId != null;
  String? get connectedDeviceId => _connectedDeviceId;

  Future<void> startScan({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    await stopScan();
    // await FlutterBluePlus.startScan(timeout: timeout);
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.device.platformName;
        if (name.startsWith('Serene') || name.contains('Serene')) {
          _seen[r.device.remoteId.str] = r;
          onDeviceFound?.call(r);
        }
      }
    });
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;
  }

  Future<bool> connect(String deviceId) async {
    final r = _seen[deviceId];
    if (r == null) return false;
    final d = r.device;
    try {
      await d.connect(autoConnect: false);
      _connectedDeviceId = deviceId;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_connectedDeviceId != null) {
      final r = _seen[_connectedDeviceId];
      if (r != null) {
        try {
          await r.device.disconnect();
        } catch (_) {}
      }
      _connectedDeviceId = null;
    }
  }

  Future<List<fbp.BluetoothService>> discover(String deviceId) async {
    final r = _seen[deviceId];
    if (r == null) return [];
    try {
      return await r.device.discoverServices();
    } catch (_) {
      return [];
    }
  }

  Future<bool> writeCharacteristic(
    String deviceId,
    Guid serviceUuid,
    Guid charUuid,
    List<int> value,
  ) async {
    final r = _seen[deviceId];
    if (r == null) return false;
    try {
      final services = await r.device.discoverServices();
      for (final s in services) {
        if (s.uuid == serviceUuid) {
          for (final c in s.characteristics) {
            if (c.uuid == charUuid) {
              await c.write(value, withoutResponse: true);
              return true;
            }
          }
        }
      }
    } catch (_) {}
    return false;
  }
}
