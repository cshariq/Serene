import 'dart:async';

class AncProcessor {
  Timer? _timer;
  double _noiseLevel = 0.0; // 0..1
  double _ancLevel = 0.5; // 0..1
  double _externalNoiseInput = 0.0; // from audio/sensors

  double get noiseLevel => _noiseLevel;
  double get ancLevel => _ancLevel;

  void setExternalNoiseLevel(double level) {
    _externalNoiseInput = level.clamp(0.0, 1.0);
  }

  void start() {
    stop();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      // Use external noise or fall back to simulation
      _noiseLevel = _externalNoiseInput > 0
          ? _externalNoiseInput
          : (DateTime.now().millisecond % 100) / 100.0;

      // Adaptive ANC: increase when noise is high, reduce when low
      if (_noiseLevel > 0.6) {
        _ancLevel = (_ancLevel + 0.05).clamp(0.0, 1.0);
      } else if (_noiseLevel < 0.3) {
        _ancLevel = (_ancLevel - 0.05).clamp(0.0, 1.0);
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
