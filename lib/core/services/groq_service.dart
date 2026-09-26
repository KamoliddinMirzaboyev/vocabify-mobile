import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'cache_service.dart';

class GroqService {
  static final GroqService instance = GroqService._internal();
  GroqService._internal();

  /// Transcribe audio file to text using Whisper Large v3 Turbo on Groq
  Future<String> transcribeAudio(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync() || file.lengthSync() < 500) {
      throw Exception("Ovoz fayli juda qisqa yoki topilmadi");
    }

    final apiKey = await CacheService.instance.getEffectiveGroqApiKey();
    final uri = Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..fields['model'] = 'whisper-large-v3-turbo'
      ..fields['language'] = 'en'
      ..fields['response_format'] = 'json'
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      debugPrint('Whisper error: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 401) {
        throw Exception('Groq API kaliti yaroqsiz. Profil sozlamalarida yangilang.');
      }
      throw Exception('Ovozni taniy olmadi (${response.statusCode})');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['text'] as String?)?.trim() ?? '';
  }

  /// Chat with IELTS Speaking Examiner partner using Llama 3.3 70B on Groq
  Future<String> chatWithExaminer({
    required List<Map<String, String>> history,
    required String userText,
  }) async {
    final apiKey = await CacheService.instance.getEffectiveGroqApiKey();
    final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final messages = [
      {
        'role': 'system',
        'content':
            'You are an IELTS Speaking examiner and English conversation partner for B1-B2 level learners. Keep responses concise (1-3 sentences). Ask IELTS-style speaking questions: hobbies, daily life, opinions, future plans, experiences. Use simple B1-B2 grammar and vocabulary. After user speaks, respond briefly and ask a follow-up question.',
      },
      ...history,
      {'role': 'user', 'content': userText.trim()},
    ];

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 120,
      }),
    );

    if (response.statusCode != 200) {
      debugPrint('Chat error: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 401) {
        throw Exception('Groq API kaliti yaroqsiz. Profil sozlamalarida yangilang.');
      }
      throw Exception('Javob olishda xatolik yuz berdi (${response.statusCode})');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List;
    if (choices.isEmpty) throw Exception('Javob topilmadi');
    return choices[0]['message']['content'] as String;
  }

  /// Generate Word Card info (translation, pronunciation, example) with AI
  Future<Map<String, dynamic>?> generateWordCardInfo(String word) async {
    try {
      final apiKey = await CacheService.instance.getEffectiveGroqApiKey();
      final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      final prompt = '''
For the English word or phrase: "$word", provide the following in valid JSON format:
{
  "word": "$word",
  "pronunciation": "IPA phonetic transcription (e.g. /həˈloʊ/)",
  "translation": "Uzbek translation (e.g. salom)",
  "definition": "Simple English definition",
  "example_sentence": "A natural, clear English example sentence using this word."
}
Return ONLY pure JSON without markdown code fences or other text.
''';

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'system', 'content': 'You are a dictionary and translation expert. Always reply with raw JSON.'},
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.3,
          'max_tokens': 250,
        }),
      );

      if (response.statusCode == 200) {
        var body = utf8.decode(response.bodyBytes);
        final data = jsonDecode(body) as Map<String, dynamic>;
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          String text = choices[0]['message']['content'] as String;
          // Strip potential backticks
          text = text.replaceAll('```json', '').replaceAll('```', '').trim();
          return jsonDecode(text) as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error generating word card info with Groq: $e');
      return null;
    }
  }
}
