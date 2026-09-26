import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/tts_service.dart';
import '../../models/card_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cards_provider.dart';
import '../../providers/decks_provider.dart';

class CardFormScreen extends StatefulWidget {
  final String deckId;
  final CardModel? card;

  const CardFormScreen({
    super.key,
    required this.deckId,
    this.card,
  });

  @override
  State<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends State<CardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _translationController = TextEditingController();
  final _exampleController = TextEditingController();

  bool _isEditing = false;
  bool _isSubmitting = false;
  bool _isGeneratingAI = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.card != null;
    if (_isEditing) {
      _wordController.text = widget.card!.word;
      _translationController.text = widget.card!.translation;
      _exampleController.text = widget.card!.exampleSentence ?? '';
    }
  }

  @override
  void dispose() {
    _wordController.dispose();
    _translationController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  Future<void> _generateWithAI() async {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avval inglizcha so\'z kiriting')),
      );
      return;
    }

    setState(() => _isGeneratingAI = true);
    final cardsProv = context.read<CardsProvider>();
    final info = await cardsProv.generateWordInfoWithAI(word);

    if (mounted) {
      setState(() => _isGeneratingAI = false);
      if (info != null) {
        if (info['translation'] != null) {
          _translationController.text = info['translation'].toString();
        }
        if (info['example_sentence'] != null) {
          _exampleController.text = info['example_sentence'].toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI yordamida to\'ldirildi! ✨'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI javob bermadi')),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final cardsProv = context.read<CardsProvider>();
    final decksProv = context.read<DecksProvider>();

    final word = _wordController.text.trim();
    final translation = _translationController.text.trim();
    final example = _exampleController.text.trim();

    if (_isEditing) {
      await cardsProv.updateCard(
        cardId: widget.card!.id,
        deckId: widget.deckId,
        word: word,
        translation: translation,
        exampleSentence: example,
      );
    } else {
      final userId = auth.user?.id;
      if (userId != null) {
        await cardsProv.addCard(
          userId: userId,
          deckId: widget.deckId,
          word: word,
          translation: translation,
          exampleSentence: example,
        );
        decksProv.updateCardCount(widget.deckId, 1);
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Yangilandi' : 'Qo\'shildi 🎉'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'So\'zni tahrirlash' : 'Yangi so\'z'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Word input + speech button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _wordController,
                      autofocus: !_isEditing,
                      decoration: const InputDecoration(
                        labelText: 'So\'z (English) *',
                        hintText: 'serendipity',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'So\'z kiriting';
                        return null;
                      },
                      onChanged: (v) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton.filledTonal(
                      icon: const Icon(Icons.volume_up_rounded),
                      onPressed: _wordController.text.trim().isNotEmpty
                          ? () => TtsService.instance.speak(_wordController.text.trim())
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // AI Helper Button
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isGeneratingAI ? null : _generateWithAI,
                  icon: _isGeneratingAI
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text('AI bilan to\'ldirish'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandDark,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Translation input
              TextFormField(
                controller: _translationController,
                decoration: const InputDecoration(
                  labelText: 'O\'zbekcha tarjima *',
                  hintText: 'tasodifiy yaxshi narsa topish',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Tarjimani kiriting';
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Example sentence input
              TextFormField(
                controller: _exampleController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Misol gap',
                  hintText: 'Meeting her was pure serendipity.',
                ),
              ),
              const SizedBox(height: 32),

              // Save button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEditing ? 'Saqlash' : 'Qo\'shish'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
