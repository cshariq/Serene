import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class SensorService {
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  double _accelMagnitude = 0.0;
  double _gyroMagnitude = 0.0;
  bool _isRunning = false;

  double get accelMagnitude => _accelMagnitude;
  double get gyroMagnitude => _gyroMagnitude;
  bool get isRunning => _isRunning;

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    stop();
    _accelSub = accelerometerEventStream().listen((event) {
      final sqSum = event.x * event.x + event.y * event.y + event.z * event.z;
      _accelMagnitude = sqrt(sqSum);
      // Normalize to 0..1 (max ~20 m/s²)
      _accelMagnitude = (_accelMagnitude / 20.0).clamp(0.0, 1.0);
    });
    _gyroSub = gyroscopeEventStream().listen((event) {
      final sqSum = event.x * event.x + event.y * event.y + event.z * event.z;
      _gyroMagnitude = sqrt(sqSum);
      // Normalize to 0..1 (max ~5 rad/s)
      _gyroMagnitude = (_gyroMagnitude / 5.0).clamp(0.0, 1.0);
    });
  }

  void stop() {
    _isRunning = false;
    _accelSub?.cancel();
    _gyroSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
    _accelMagnitude = 0.0;
    _gyroMagnitude = 0.0;
  }
}
