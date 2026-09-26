import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/decks_provider.dart';
import '../../providers/cards_provider.dart';

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
    "pronunciation": "/ˌser.ənˈdɪp.ə.ti/",
    "translation": "tasodifiy yaxshi narsa topish",
    "definition": "The occurrence of fortunate events by chance.",
    "synonyms": ["luck", "fortune", "coincidence"],
    "antonyms": ["misfortune"],
    "example": "Meeting her was pure serendipity."
  },
  {
    "word": "ubiquitous",
    "translation": "hamma joyda uchraydigan",
    "example": "Smartphones have become ubiquitous."
  }
]''';

  @override
  void initState() {
    super.initState();
    _selectedDeckId = widget.initialDeckId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  List<Map<String, dynamic>> _parseJson(String text) {
    if (text.trim().isEmpty) return [];
    try {
      final raw = jsonDecode(text);
      if (raw is List) {
        return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (raw is Map) {
        return [Map<String, dynamic>.from(raw)];
      }
      return [];
    } catch (_) {
      return [];
    }
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
        _jsonController.text = content;
        setState(() {});
      }
    } catch (e) {
      debugPrint('File pick error: $e');
    }
  }

  Future<void> _handleImport() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null || _selectedDeckId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('To\'plamni tanlang')),
      );
      return;
    }

    final items = _parseJson(_jsonController.text);
    final validItems = items
        .where((e) =>
            e['word']?.toString().trim().isNotEmpty == true &&
            e['translation']?.toString().trim().isNotEmpty == true)
        .toList();

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hech qanday yaroqli so\'z topilmadi')),
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
            content: Text('$count ta so\'z qo\'shildi 🎉'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xatolik: $e'),
            backgroundColor: AppColors.destructive,
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
          .select('word, pronunciation, translation, definition, synonyms, antonyms, example_sentence')
          .eq('user_id', userId);

      if (_selectedDeckId != null && _selectedDeckId!.isNotEmpty) {
        query = query.eq('deck_id', _selectedDeckId!);
      }

      final res = await query;
      final list = (res as List).map((c) => {
            'word': c['word'],
            if (c['pronunciation'] != null) 'pronunciation': c['pronunciation'],
            'translation': c['translation'],
            if (c['definition'] != null) 'definition': c['definition'],
            if (c['synonyms'] != null) 'synonyms': c['synonyms'],
            if (c['antonyms'] != null) 'antonyms': c['antonyms'],
            if (c['example_sentence'] != null) 'example': c['example_sentence'],
          }).toList();

      final jsonStr = const JsonEncoder.withIndent('  ').convert(list);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/vocabify_export_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(jsonStr);

      if (mounted) {
        setState(() => _isExporting = false);
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'Vocabify export',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eksportda xatolik: $e'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decks = context.watch<DecksProvider>().decks;
    final parsedItems = _parseJson(_jsonController.text);
    final isValid = parsedItems.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KO\'P SO\'Z',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            const Text(
              'JSON orqali import',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Deck Dropdown Picker
            const Text(
              'To\'plam *',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
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
                      child: Text('${d.icon} ${d.name}'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedDeckId = v),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // JSON Text area with Sample Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'JSON ma\'lumot',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: () {
                    _jsonController.text = _sampleJson;
                    setState(() {});
                  },
                  child: const Text('Namunani ko\'rish', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            TextFormField(
              controller: _jsonController,
              maxLines: 8,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              decoration: const InputDecoration(
                hintText: '[{"word":"serendipity","translation":"...","example":"..."}]',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            // File Upload Button
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('.json fayl yuklash'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Live validation card
            if (_jsonController.text.trim().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isValid ? AppColors.success : AppColors.destructive,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isValid ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          color: isValid ? AppColors.success : AppColors.destructive,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isValid
                              ? '${parsedItems.length} ta so\'z yaroqli'
                              : 'JSON formati noto\'g\'ri',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isValid ? AppColors.success : AppColors.destructive,
                          ),
                        ),
                      ],
                    ),
                    if (isValid) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Ko\'rib chiqish (${parsedItems.take(5).length} ta):',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...parsedItems.take(5).map((w) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• ${w['word'] ?? ''} — ${w['translation'] ?? ''}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        );
                      }),
                      if (parsedItems.length > 5)
                        Text(
                          '+ yana ${parsedItems.length - 5} ta so\'z...',
                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Import Button
            ElevatedButton.icon(
              onPressed: (_isImporting || !isValid) ? null : _handleImport,
              icon: _isImporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.file_download_done_rounded, size: 20),
              label: Text(
                _isImporting
                    ? 'Import qilinmoqda...'
                    : '${isValid ? parsedItems.length : ""} ta so\'zni import qilish',
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 24),

            // Export Section
            Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
            const SizedBox(height: 14),
            const Text(
              'Eksport',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Tanlangan to\'plamdagi so\'zlarni JSON faylga eksport qiling.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isExporting ? null : _handleExport,
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: const Text('JSON eksport'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
