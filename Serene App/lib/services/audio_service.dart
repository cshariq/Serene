import 'dart:async';
import 'dart:typed_data';
import 'package:audio_session/audio_session.dart';
import 'package:record/record.dart';
import 'dart:math' as math;
import 'dart:io';

import 'package:just_audio/just_audio.dart';

class AudioService {
  bool _isListening = false;
  double _noiseLevel = 0.0;
  Timer? _captureTimer;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _debugPlayer = AudioPlayer();

  StreamController<Uint8List>? _audioStreamController;
  Stream<Uint8List>? get audioStream => _audioStreamController?.stream;

  double get noiseLevel => _noiseLevel;
  bool get isRunning => _isListening;

  /// Record for a short duration and play back for debugging
  Future<void> recordAndPlayDebug(Duration duration) async {
    // Stop current monitoring if active
    final wasRunning = _isListening;
    if (wasRunning) {
      await stop();
    }

    try {
      final tempDir = Directory.systemTemp;
      final debugPath = '${tempDir.path}/serene_debug_mic.m4a';

      // Start recording
      if (await _recorder.hasPermission()) {
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: debugPath,
        );

        // Wait for duration
        await Future.delayed(duration);

        // Stop recording
        await _recorder.stop();

        // Play back
        await _debugPlayer.setFilePath(debugPath);
        await _debugPlayer.play();

        // Wait for playback to finish
        await _debugPlayer.playerStateStream.firstWhere(
          (state) => state.processingState == ProcessingState.completed,
        );
      }
    } catch (e) {
      print("Debug recording failed: $e");
    } finally {
      // Resume monitoring if it was running
      if (wasRunning) {
        await start();
      }
    }
  }

  bool _isSimulating = false;
  bool get isSimulating => _isSimulating;

  Future<void> start() async {
    // If we are simulating, we might want to try real mic again
    if (_isListening && !_isSimulating) return;

    // If we were simulating, stop first
    if (_isListening && _isSimulating) {
      await stop();
    }

    try {
      print("AudioService: Starting...");
      final session = await AudioSession.instance;
      // Configure audio session for voice communication with microphone access
      await session.configure(AudioSessionConfiguration.speech());

      // Check if microphone permission is granted
      if (await _recorder.hasPermission()) {
        print(
          "AudioService: Permission granted, starting stream with pcm16bits...",
        );
        // Start streaming PCM data

        final stream = await _recorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 44100,
            numChannels: 1,
          ),
        );

        _audioStreamController = StreamController<Uint8List>.broadcast();
        stream.listen(
          (data) {
            if (_audioStreamController?.hasListener ?? false) {
              _audioStreamController?.add(data);
            }
            _calculateAmplitude(data);
          },
          onError: (e) {
            print("Audio stream error: $e");
          },
        );

        _isListening = true;
        _isSimulating = false;
        print("AudioService: Started successfully.");
      } else {
        print("AudioService: Permission denied.");
        // Fallback to simulation if permission not granted
        // _isListening = true;
        // _isSimulating = true;
        // _simulateAudio();
      }
    } catch (e) {
      // Fallback to simulation on error
      print("Audio start error: $e");
      // _isListening = true;
      // _isSimulating = true;
      // _simulateAudio();
    }
  }

  void _calculateAmplitude(Uint8List data) {
    if (data.isEmpty) return;

    int sum = 0;
    int count = 0;

    // Process 16-bit samples
    for (int i = 0; i < data.length; i += 2) {
      if (i + 1 < data.length) {
        // Little endian 16-bit integer
        int sample = data[i] | (data[i + 1] << 8);
        // Handle signed 16-bit
        if (sample > 32767) sample -= 65536;

        sum += sample * sample;
        count++;
      }
    }

    if (count > 0) {
      final rms = math.sqrt(sum / count);
      // Normalize to 0-1 range (approximate max RMS is 32768)
      // Using a log scale for better visualization
      final db = 20 * math.log(rms + 1) / math.ln10;
      // Map 0-90dB to 0-1
      _noiseLevel = (db / 90.0).clamp(0.0, 1.0);
    }
  }

  Future<void> stop() async {
    _isListening = false;
    _isSimulating = false;
    _captureTimer?.cancel();
    _captureTimer = null;
    try {
      await _recorder.stop();
      await _audioStreamController?.close();
      _audioStreamController = null;
    } catch (_) {
      // Ignore errors on stop
    }
    _noiseLevel = 0.0;
  }
}
