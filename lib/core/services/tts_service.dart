import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService instance = TtsService._internal();
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isPlayingSequence = false;

  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(-1);

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _initialized = true;
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  Future<void> speak(String text, {String lang = 'en-US', double rate = 0.5}) async {
    if (!_initialized) await initialize();
    try {
      await _tts.stop();
      await _tts.setLanguage(lang);
      await _tts.setSpeechRate(rate);
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  Future<void> stop() async {
    _isPlayingSequence = false;
    isPlayingNotifier.value = false;
    currentIndexNotifier.value = -1;
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }

  /// Sequential "Eshitib yodlash" mode
  Future<void> playWordSequence({
    required List<Map<String, String>> words,
    required void Function(int index) onIndexChanged,
    required VoidCallback onCompleted,
  }) async {
    if (!_initialized) await initialize();
    await stop();

    _isPlayingSequence = true;
    isPlayingNotifier.value = true;

    for (int i = 0; i < words.length; i++) {
      if (!_isPlayingSequence) break;

      currentIndexNotifier.value = i;
      onIndexChanged(i);

      final item = words[i];
      final en = item['word'] ?? '';
      final uz = item['translation'] ?? '';

      // 1. Speak English
      if (en.isNotEmpty && _isPlayingSequence) {
        await _tts.setLanguage('en-US');
        await _tts.setSpeechRate(0.48);
        await _tts.speak(en);
      }

      if (!_isPlayingSequence) break;
      await Future.delayed(const Duration(milliseconds: 700));

      // 2. Speak Translation
      if (uz.isNotEmpty && _isPlayingSequence) {
        try {
          await _tts.setLanguage('tr-TR'); // Closest speech engine for Uzbek
          await _tts.setSpeechRate(0.52);
          await _tts.speak(uz);
        } catch (_) {
          // If Turkish not supported, fallback to default
          await _tts.speak(uz);
        }
      }

      if (!_isPlayingSequence) break;
      await Future.delayed(const Duration(milliseconds: 1400));
    }

    if (_isPlayingSequence) {
      _isPlayingSequence = false;
      isPlayingNotifier.value = false;
      currentIndexNotifier.value = -1;
      onCompleted();
    }
  }
}
