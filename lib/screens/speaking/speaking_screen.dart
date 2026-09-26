import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/audio_recorder_service.dart';
import '../../core/services/groq_service.dart';
import '../../core/services/tts_service.dart';

class ChatMessage {
  final String id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

enum SpeakingPipeline { idle, recording, transcribing, thinking }

class SpeakingScreen extends StatefulWidget {
  const SpeakingScreen({super.key});

  @override
  State<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends State<SpeakingScreen> with SingleTickerProviderStateMixin {
  final List<ChatMessage> _messages = [
    ChatMessage(
      id: '1',
      role: 'assistant',
      content: 'Hi! Let\'s practice speaking. Tell me about your typical day.',
      timestamp: DateTime.now(),
    ),
  ];

  final ScrollController _scrollController = ScrollController();
  SpeakingPipeline _pipeline = SpeakingPipeline.idle;
  int _recordingTime = 0;
  Timer? _recordTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggleRecording() async {
    if (_pipeline == SpeakingPipeline.recording) {
      await _stopAndProcessRecording();
    } else if (_pipeline == SpeakingPipeline.idle) {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      final path = await AudioRecorderService.instance.startRecording();
      if (path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mikrofonga ruxsat berilmadi')),
          );
        }
        return;
      }

      setState(() {
        _pipeline = SpeakingPipeline.recording;
        _recordingTime = 0;
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) {
          setState(() => _recordingTime += 1);
        }
      });
    } catch (e) {
      debugPrint('Start recording error: $e');
    }
  }

  Future<void> _stopAndProcessRecording() async {
    _recordTimer?.cancel();
    final filePath = await AudioRecorderService.instance.stopRecording();

    if (filePath == null) {
      setState(() => _pipeline = SpeakingPipeline.idle);
      return;
    }

    if (_recordingTime < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ovoz juda qisqa. Qayta urinib ko\'ring.')),
        );
      }
      setState(() => _pipeline = SpeakingPipeline.idle);
      return;
    }

    // 1. Transcribe with Whisper on Groq
    setState(() => _pipeline = SpeakingPipeline.transcribing);
    String userText = '';

    try {
      userText = await GroqService.instance.transcribeAudio(filePath);
    } catch (e) {
      debugPrint('Transcription error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ovoz aniqlanmadi. Aniqroq gapiring.')),
        );
      }
      setState(() => _pipeline = SpeakingPipeline.idle);
      return;
    }

    if (userText.isEmpty) {
      setState(() => _pipeline = SpeakingPipeline.idle);
      return;
    }

    // Add user message
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: userText,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _pipeline = SpeakingPipeline.thinking;
    });
    _scrollToBottom();

    // 2. Chat with Llama on Groq
    try {
      final history = _messages
          .take(_messages.length - 1)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final reply = await GroqService.instance.chatWithExaminer(
        history: history,
        userText: userText,
      );

      final assistantMsg = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        role: 'assistant',
        content: reply,
        timestamp: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _messages.add(assistantMsg);
          _pipeline = SpeakingPipeline.idle;
        });
        _scrollToBottom();

        // Speak response with TTS
        Future.delayed(const Duration(milliseconds: 200), () {
          TtsService.instance.speak(reply);
        });
      }
    } catch (e) {
      debugPrint('Chat error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Javob olishda xatolik yuz berdi')),
        );
        setState(() => _pipeline = SpeakingPipeline.idle);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRecording = _pipeline == SpeakingPipeline.recording;
    final isBusy = _pipeline == SpeakingPipeline.transcribing ||
        _pipeline == SpeakingPipeline.thinking;

    String statusLabel = 'Gapirish uchun bosing';
    if (isRecording) statusLabel = 'To\'xtatish uchun bosing';
    if (_pipeline == SpeakingPipeline.transcribing) {
      statusLabel = 'Ovoz matnga o\'girilmoqda...';
    }
    if (_pipeline == SpeakingPipeline.thinking) {
      statusLabel = 'Javob tayyorlanmoqda...';
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.forum_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Speaking Practice',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              'IELTS B1-B2 Level',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length + (isBusy ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && isBusy) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _pipeline == SpeakingPipeline.transcribing
                                ? 'Ovoz matnga o\'girilmoqda...'
                                : 'Javob yozilmoqda...',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final msg = _messages[index];
                final isUser = msg.role == 'user';

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser
                          ? (isDark ? AppColors.brandDark : AppColors.brand)
                          : (isDark ? AppColors.darkCard : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
                        bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
                      ),
                      border: isUser
                          ? null
                          : Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            msg.content,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: isUser
                                  ? Colors.white
                                  : (isDark ? AppColors.darkText : AppColors.lightText),
                            ),
                          ),
                        ),
                        if (!isUser) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => TtsService.instance.speak(msg.content),
                            child: const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.volume_up_rounded, size: 16, color: Colors.grey),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Recording Controller
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // Status Row
                  SizedBox(
                    height: 24,
                    child: isRecording
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.destructive,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(_recordingTime),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.destructive,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Mic Button with Animated Pulse
                  GestureDetector(
                    onTap: isBusy ? null : _toggleRecording,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: isRecording
                                ? AppColors.destructive
                                : (isDark ? AppColors.brandDark : AppColors.brand),
                            shape: BoxShape.circle,
                            boxShadow: isRecording
                                ? [
                                    BoxShadow(
                                      color: AppColors.destructive.withValues(alpha: 
                                        0.3 + (_pulseController.value * 0.3),
                                      ),
                                      blurRadius: 18 + (_pulseController.value * 8),
                                      spreadRadius: 2 + (_pulseController.value * 4),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: AppColors.brand.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: isBusy
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Icon(
                                  isRecording
                                      ? Icons.stop_rounded
                                      : Icons.mic_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
