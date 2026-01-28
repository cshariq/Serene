import 'dart:async';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'audio_service.dart';

/// Service that generates and plays anti-noise audio for ANC
class AncAudioOutput {
  final AudioPlayer _player = AudioPlayer();
  final AudioService? _audioService;
  bool _isPlaying = false;
  double _currentAncLevel = 0.0;

  AncAudioOutput([this._audioService]);

  bool get isPlaying => _isPlaying;

  /// Start playing anti-noise (inverted mic input)
  Future<void> start(double ancLevel) async {
    if (_isPlaying) return;

    _currentAncLevel = ancLevel;
    _isPlaying = true;
    final audioService = _audioService;

    try {
      // Try to minimize latency
      await _player.setAutomaticallyWaitsToMinimizeStalling(false);

      if (audioService != null) {
        if (!audioService.isRunning) {
          await audioService.start();
        }

        final stream = audioService.audioStream;
        if (stream != null) {
          final source = InvertedMicSource(stream);
          await _player.setAudioSource(source);

          // Set volume based on ANC level
          final volume = (_currentAncLevel / 10.0).clamp(0.0, 1.0);
          await _player.setVolume(volume);

          await _player.play();
          return;
        }
      }

      // Fallback to simulated tone disabled when no audio stream is available.
      print("ANC: Audio stream not available, and simulation is disabled.");
      _isPlaying = false;
    } catch (e) {
      print("ANC Start Error: $e");
      _isPlaying = false;
    }
  }

  /// Update the ANC level (0-10 scale)
  void updateLevel(double level) {
    _currentAncLevel = level;
    // Volume scales from 0 to 0.7 (to prevent distortion)
    final volume = (level / 10.0 * 0.7).clamp(0.0, 0.7);
    _player.setVolume(volume);
  }

  /// Stop playing ANC audio
  Future<void> stop() async {
    _isPlaying = false;
    try {
      await _player.stop();
    } catch (_) {}
  }

  void dispose() {
    stop();
    _player.dispose();
  }
}

class InvertedMicSource extends StreamAudioSource {
  final Stream<Uint8List> input;
  int _chunkCount = 0;

  InvertedMicSource(this.input);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    print("ANC: Stream request start=$start end=$end");

    Stream<List<int>> outputStream = input.map((bytes) {
      return _invertAndSwap(bytes, 0);
    });

    // Prepend WAV header if starting from the beginning
    if (start == 0 || start == null) {
      // Use a generator to sequence the header before the stream
      outputStream = (() async* {
        yield _createWavHeader();
        yield* input.map((bytes) => _invertAndSwap(bytes, 0));
      })();
    }

    return StreamAudioResponse(
      sourceLength: null,
      contentLength: null,
      offset: start ?? 0,
      stream: outputStream,
      contentType: 'audio/wav',
    );
  }

  List<int> _createWavHeader() {
    final int sampleRate = 44100;
    final int channels = 1;
    final int bitsPerSample = 16;
    final int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final int blockAlign = channels * (bitsPerSample ~/ 8);
    final int dataSize = 2147483647; // Max int32 roughly

    final header = ByteData(44);

    // RIFF chunk
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, 36 + dataSize, Endian.little); // File size
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6d); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // space
    header.setUint32(16, 16, Endian.little); // Chunk size
    header.setUint16(20, 1, Endian.little); // Audio format (1 = PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    return header.buffer.asUint8List().toList();
  }

  List<int> _invertAndSwap(Uint8List bytes, int offset) {
    _chunkCount++;
    // Calculate length after offset
    final length = bytes.length - offset;
    if (length <= 0) return [];

    final out = Uint8List(length);
    final data = ByteData.sublistView(bytes);
    final outData = ByteData.sublistView(out);

    // Process 16-bit samples
    // Ensure we don't go out of bounds if length is odd (shouldn't happen for 16-bit audio)
    final loopLength = length & ~1; // Round down to even number

    // TEST EFFECT: Pulse volume to prove processing (since inverted audio sounds identical to raw)
    // Mute for 10 chunks every 20 chunks (approx 0.5s pulse)
    final bool applyEffect = (_chunkCount % 20) < 10;

    int maxAmp = 0;
    for (int i = 0; i < loopLength; i += 2) {
      // Read Little Endian (from WAV/Mic)
      final sample = data.getInt16(offset + i, Endian.little);
      if (sample.abs() > maxAmp) maxAmp = sample.abs();

      // Invert phase
      // Apply pulse effect: if applyEffect is true, use inverted sample, else silence
      // This will create a "choppy" sound if processing is working
      final inverted = applyEffect ? -sample : 0;

      // Write Little Endian (WAV expects Little Endian)
      outData.setInt16(i, inverted, Endian.little);
    }
    if (maxAmp > 100) {
      print("ANC Chunk Max Amp: $maxAmp"); // Only print if significant signal
    }
    return out.toList();
  }
}
