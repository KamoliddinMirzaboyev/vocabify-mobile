import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorderService {
  static final AudioRecorderService instance = AudioRecorderService._internal();
  AudioRecorderService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  String? _currentFilePath;

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  Future<String?> startRecording() async {
    try {
      final hasPerm = await hasPermission();
      if (!hasPerm) return null;

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/vocabify_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentFilePath = path;

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 16000,
        ),
        path: path,
      );

      return path;
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      return path ?? _currentFilePath;
    } catch (e) {
      debugPrint('Error stopping audio recording: $e');
      return null;
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}
