import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/decks_provider.dart';
import '../../providers/cards_provider.dart';
import '../decks/card_form_screen.dart';

class BulkImportScreen extends StatefulWidget {
  final String? initialDeckId;
  const BulkImportScreen({super.key, this.initialDeckId});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  final TextEditingController _jsonController = TextEditingController();

  String? _selectedDeckId;
  bool _isImporting = false;
  bool _isExporting = false;

  static const String _sampleJson = '''[
  {
    "word": "serendipity",
    "translation": "tasodifiy yaxshi narsa topish",
    "example": "Meeting her was pure serendipity."
  }
]''';

  static const String _aiPromptTemplate = '''Quyidagi so'zlarni berilgan JSON formatiga o'tkazib ber. Har bir so'z uchun inglizcha so'z (word), o'zbekcha tarjimasi (translation) va inglizcha misol gap (example) bo'lsin. Faqat toza JSON formatida javob qaytar (boshqa hech qanday izoh yoki belgilarsiz):

[
  {
    "word": "serendipity",
    "translation": "tasodifiy yaxshi narsa topish",
    "example": "Meeting her was pure serendipity."
  }
]

So'zlar ro'yxati:
''';

  void _showPromptDialog(BuildContext context, bool isDark) {
    Clipboard.setData(const ClipboardData(text: _aiPromptTemplate));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF2563EB),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'AI uchun prompt',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prompt nusxalandi! 📋\nUni ChatGPT, Claude yoki Gemini\'ga yuborib, so\'zlaringizni tayyor JSON holida olishingiz mumkin:',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: SelectableText(
                _aiPromptTemplate,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.35,
                  color: isDark
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Yopish',
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: _aiPromptTemplate));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Prompt buferga nusxalandi! 📋'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Color(0xFF1E293B),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Qayta nusxalash'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedDeckId = widget.initialDeckId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final decks = context.read<DecksProvider>().decks;
      if (_selectedDeckId == null && decks.isNotEmpty) {
        setState(() => _selectedDeckId = decks.first.id);
      }
    });
  }

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _cleanAndParseJson(String rawText) {
    var text = rawText.trim();
    if (text.isEmpty) return [];

    // Strip markdown fences
    text = text.replaceAll(RegExp(r'```json\s*', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'```\s*'), '');

    final startBracket = text.indexOf('[');
    final endBracket = text.lastIndexOf(']');

    if (startBracket != -1 && endBracket != -1 && endBracket > startBracket) {
      text = text.substring(startBracket, endBracket + 1);
    } else {
      final startBrace = text.indexOf('{');
      final endBrace = text.lastIndexOf('}');
      if (startBrace != -1 && endBrace != -1 && endBrace > startBrace) {
        text = text.substring(startBrace, endBrace + 1);
      }
    }

    try {
      final parsed = jsonDecode(text);
      if (parsed is List) {
        return parsed
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (parsed is Map) {
        return [Map<String, dynamic>.from(parsed)];
      }
    } catch (e) {
      debugPrint('JSON parse error: $e');
    }
    return [];
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        final content = await file.readAsString();
        if (!mounted) return;
        setState(() {
          _jsonController.text = content;
        });
      }
    } catch (e) {
      debugPrint('File pick error: $e');
    }
  }

  Future<void> _handleImport() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null || _selectedDeckId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Iltimos, avval to\'plamni tanlang'),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final items = _cleanAndParseJson(_jsonController.text);
    final validItems = items
        .where(
          (e) =>
              e['word']?.toString().trim().isNotEmpty == true &&
              e['translation']?.toString().trim().isNotEmpty == true,
        )
        .toList();

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hech qanday yaroqli so\'z topilmadi. JSON ni tekshiring.',
          ),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isImporting = true);
    final cardsProv = context.read<CardsProvider>();
    final decksProv = context.read<DecksProvider>();

    try {
      final count = await cardsProv.bulkImportCards(
        userId: userId,
        deckId: _selectedDeckId!,
        items: validItems,
      );

      decksProv.updateCardCount(_selectedDeckId!, count);

      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$count ta so\'z to\'plamga muvaffaqiyatli qo\'shildi! 🎉',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import qilishda xatolik: $e'),
            backgroundColor: AppColors.destructive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleExport() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    setState(() => _isExporting = true);
    try {
      var query = SupabaseService.client
          .from('cards')
          .select('word, translation, example_sentence')
          .eq('user_id', userId);

      if (_selectedDeckId != null && _selectedDeckId!.isNotEmpty) {
        query = query.eq('deck_id', _selectedDeckId!);
      }

      final res = await query;
      final list = (res as List)
          .map(
            (c) => {
              'word': c['word'],
              'translation': c['translation'],
              if (c['example_sentence'] != null)
                'example': c['example_sentence'],
            },
          )
          .toList();

      final jsonStr = const JsonEncoder.withIndent('  ').convert(list);
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/vocabify_export_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await file.writeAsString(jsonStr);

      if (mounted) {
        setState(() => _isExporting = false);
        final box = context.findRenderObject() as RenderBox?;
        final origin =
            box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Vocabify export',
          sharePositionOrigin: origin,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eksportda xatolik: $e'),
            backgroundColor: AppColors.destructive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decks = context.watch<DecksProvider>().decks;
    final parsedItems = _cleanAndParseJson(_jsonController.text);
    final validItems = parsedItems
        .where(
          (e) =>
              e['word']?.toString().trim().isNotEmpty == true &&
              e['translation']?.toString().trim().isNotEmpty == true,
        )
        .toList();
    final validCount = validItems.length;
    final totalCount = parsedItems.length;

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        width: 1.2,
      ),
    );
    final focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: isDark ? AppColors.brandDark : const Color(0xFF1E293B),
        width: 1.5,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('JSON orqali import')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Destination Deck Picker
            Text(
              'Qaysi to\'plamga qo\'shilsin? *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDeckId,
                  isExpanded: true,
                  hint: const Text('To\'plam tanlang'),
                  items: decks.map((d) {
                    return DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        '${d.icon} ${d.name} (${d.cardCount} ta so\'z)',
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedDeckId = v),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Row: "JSON ma'lumot" + "Promptni olish"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'JSON ma\'lumot',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showPromptDialog(context, isDark),
                  child: const Text(
                    'Promptni olish',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2563EB),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // JSON Editor
            TextFormField(
              controller: _jsonController,
              minLines: 5,
              maxLines: 8,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.45,
              ),
              decoration: InputDecoration(
                hintText: _sampleJson,
                hintStyle: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: isDark
                      ? const Color(0xFF64748B)
                      : const Color(0xFF94A3B8),
                ),
                contentPadding: const EdgeInsets.all(14),
                border: inputBorder,
                enabledBorder: inputBorder,
                focusedBorder: focusedInputBorder,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Dashed Border Button: .json fayl yuklash
            CustomPaint(
              painter: DashedBorderPainter(
                color: isDark
                    ? const Color(0xFF475569)
                    : const Color(0xFFCBD5E1),
                strokeWidth: 1.2,
                radius: 14,
              ),
              child: InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.upload_rounded,
                        size: 18,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '.json fayl yuklash',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Validation & Preview Box
            if (_jsonController.text.trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1B2433)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row: Checkmark + count
                    Row(
                      children: [
                        Icon(
                          validCount > 0
                              ? Icons.check_circle_outline_rounded
                              : Icons.error_outline_rounded,
                          color: validCount > 0
                              ? const Color(0xFF10B981)
                              : AppColors.destructive,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$validCount / $totalCount ta so\'z yaroqli',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: validCount > 0
                                ? (isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A))
                                : AppColors.destructive,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Row: Eye icon + "Ko'rib chiqish"
                    Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 15,
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Ko\'rib chiqish',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Card Preview Items
                    if (validItems.isNotEmpty)
                      ...validItems.take(4).map((item) {
                        final w = item['word']?.toString() ?? '';
                        final t = item['translation']?.toString() ?? '';
                        final ex = (item['example'] ?? item['example_sentence'])
                            ?.toString();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF151C28)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFEDF2F7),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                w,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              if (ex != null && ex.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  ex,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontStyle: FontStyle.italic,
                                    color: isDark
                                        ? Colors.white38
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      })
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Yaroqli so\'zlar topilmadi. JSON ni tekshiring.',
                          style: TextStyle(
                            color: AppColors.destructive,
                            fontSize: 12.5,
                          ),
                        ),
                      ),

                    if (validItems.length > 4)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '+ yana ${validItems.length - 4} ta so\'z import qilinadi',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Submit Button: [📄] X ta so'zni import qilish
            ElevatedButton.icon(
              onPressed: (validCount == 0 || _isImporting)
                  ? null
                  : _handleImport,
              icon: _isImporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.description_outlined, size: 18),
              label: Text(
                _isImporting
                    ? 'Import qilinmoqda...'
                    : '$validCount ta so\'zni import qilish',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.4)
                    : const Color(0xFFE2E8F0),
                disabledForegroundColor: isDark
                    ? Colors.white38
                    : const Color(0xFF94A3B8),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 24),

            // Export Section
            Divider(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'To\'plamni JSON ga eksport qilish',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'So\'zlarni boshqalar bilan ulashing',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _isExporting ? null : _handleExport,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Eksport'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
