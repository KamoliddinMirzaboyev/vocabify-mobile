import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../models/deck_model.dart';
import '../../models/duel_model.dart';
import '../../providers/decks_provider.dart';
import '../../providers/duel_provider.dart';
import '../../repositories/duel_repository.dart';
import 'word_battle_screen.dart';

class BattleHubScreen extends StatefulWidget {
  const BattleHubScreen({super.key});

  @override
  State<BattleHubScreen> createState() => _BattleHubScreenState();
}

class _BattleHubScreenState extends State<BattleHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DuelProvider>().loadDuels();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openBattle(DuelModel duel) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WordBattleScreen(duelId: duel.id)),
    );
    if (mounted) context.read<DuelProvider>().refreshAfterBattle();
  }

  Future<void> _newBattle() async {
    final selection = await showModalBottomSheet<_NewBattleSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _NewBattleSheet(),
    );
    if (selection == null || !mounted) return;

    try {
      final duelId = await context.read<DuelProvider>().createDuel(
        deckId: selection.deckId,
        opponentId: selection.opponentId,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => WordBattleScreen(duelId: duelId)),
      );
      if (mounted) context.read<DuelProvider>().refreshAfterBattle();
    } on DuelRepositoryException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = SupabaseService.currentUser?.id ?? '';
    final provider = context.watch<DuelProvider>();
    final tabs = [
      provider.yourTurn(userId),
      provider.pending(userId),
      provider.finished(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Battle'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: provider.isLoading ? null : provider.loadDuels,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Your Turn (${tabs[0].length})'),
            Tab(text: 'Pending (${tabs[1].length})'),
            Tab(text: 'Finished (${tabs[2].length})'),
          ],
        ),
      ),
      body: provider.isLoading && provider.duels.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (provider.errorMessage != null)
                  MaterialBanner(
                    content: Text(provider.errorMessage!),
                    actions: [
                      TextButton(
                        onPressed: provider.loadDuels,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _DuelList(
                        duels: tabs[0],
                        emptyIcon: Icons.sports_esports_rounded,
                        emptyText: 'No battles need your answer.',
                        currentUserId: userId,
                        onTap: _openBattle,
                      ),
                      _DuelList(
                        duels: tabs[1],
                        emptyIcon: Icons.hourglass_empty_rounded,
                        emptyText: 'No battles are waiting for an opponent.',
                        currentUserId: userId,
                      ),
                      _DuelList(
                        duels: tabs[2],
                        emptyIcon: Icons.emoji_events_outlined,
                        emptyText: 'Completed battles will appear here.',
                        currentUserId: userId,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newBattle,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Battle'),
      ),
    );
  }
}

class _DuelList extends StatelessWidget {
  const _DuelList({
    required this.duels,
    required this.emptyIcon,
    required this.emptyText,
    required this.currentUserId,
    this.onTap,
  });

  final List<DuelModel> duels;
  final IconData emptyIcon;
  final String emptyText;
  final String currentUserId;
  final ValueChanged<DuelModel>? onTap;

  @override
  Widget build(BuildContext context) {
    if (duels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(emptyIcon, size: 52, color: AppColors.lightTextMuted),
              const SizedBox(height: 14),
              Text(emptyText, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: context.read<DuelProvider>().loadDuels,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
        itemCount: duels.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final duel = duels[index];
          return _DuelCard(
            duel: duel,
            currentUserId: currentUserId,
            onTap: onTap == null ? null : () => onTap!(duel),
          );
        },
      ),
    );
  }
}

class _DuelCard extends StatelessWidget {
  const _DuelCard({
    required this.duel,
    required this.currentUserId,
    this.onTap,
  });

  final DuelModel duel;
  final String currentUserId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final completed = duel.status == DuelStatus.completed;
    final expired = duel.isExpired;
    final won = completed && duel.winnerId == currentUserId;
    final myScore = currentUserId == duel.playerAId
        ? duel.playerAScore
        : duel.playerBScore;
    final opponentScore = currentUserId == duel.playerAId
        ? duel.playerBScore
        : duel.playerAScore;
    final opponentId = currentUserId == duel.playerAId
        ? duel.playerBId
        : duel.playerAId;
    final hoursLeft = duel.expiresAt
        .difference(DateTime.now())
        .inHours
        .clamp(0, 24);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    (completed
                            ? (won ? AppColors.success : AppColors.destructive)
                            : AppColors.accent)
                        .withValues(alpha: .12),
                child: Icon(
                  completed
                      ? (won
                            ? Icons.emoji_events_rounded
                            : Icons.sports_esports_rounded)
                      : Icons.bolt_rounded,
                  color: completed
                      ? (won ? AppColors.success : AppColors.destructive)
                      : AppColors.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Battle ${duel.id.substring(0, 8)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      completed
                          ? '$myScore – $opponentScore points'
                          : expired
                          ? 'Battle expired'
                          : duel.playerBId == null
                          ? 'Open challenge · ${hoursLeft}h left'
                          : '${hoursLeft}h left',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (opponentId != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Raqib ID: $opponentId',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontFamily: 'monospace'),
                      ),
                    ],
                  ],
                ),
              ),
              if (expired)
                const _Badge(text: 'EXPIRED', color: AppColors.lightTextMuted)
              else if (completed)
                _Badge(
                  text: won ? 'WIN' : 'LOSS',
                  color: won ? AppColors.success : AppColors.destructive,
                )
              else if (onTap != null)
                const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11),
    ),
  );
}

class _NewBattleSelection {
  const _NewBattleSelection(this.deckId, this.opponentId);
  final String deckId;
  final String? opponentId;
}

class _NewBattleSheet extends StatefulWidget {
  const _NewBattleSheet();

  @override
  State<_NewBattleSheet> createState() => _NewBattleSheetState();
}

class _NewBattleSheetState extends State<_NewBattleSheet> {
  final _opponentController = TextEditingController();
  final _repository = DuelRepository();
  String? _deckId;
  bool _openChallenge = false;
  bool _isSearching = false;
  BattleOpponent? _selectedOpponent;
  String? _searchError;

  Future<void> _searchOpponent() async {
    final query = _opponentController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchError = 'Email yoki foydalanuvchi ID kiriting.');
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
      _selectedOpponent = null;
    });
    try {
      final opponent = await _repository.searchOpponent(query);
      if (!mounted) return;
      setState(() {
        _selectedOpponent = opponent;
        _searchError = opponent == null
            ? 'Bu email yoki ID bilan foydalanuvchi topilmadi.'
            : null;
      });
    } on DuelRepositoryException catch (error) {
      if (!mounted) return;
      setState(() => _searchError = error.message);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _opponentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decks = context.watch<DecksProvider>().decks;
    final eligible = decks.where((deck) => deck.cardCount >= 10).toList();
    _deckId ??= eligible.firstOrNull?.id;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Start a new battle',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _deckId,
                decoration: const InputDecoration(
                  labelText: 'Deck',
                  prefixIcon: Icon(Icons.style_rounded),
                ),
                items: eligible
                    .map(
                      (DeckModel deck) => DropdownMenuItem(
                        value: deck.id,
                        child: Text(
                          '${deck.icon} ${deck.name} (${deck.cardCount})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _deckId = value),
              ),
              if (eligible.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Add at least 10 translated cards to a deck first.',
                    style: TextStyle(color: AppColors.destructive),
                  ),
                ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Open challenge'),
                subtitle: const Text('Let the first available player join.'),
                value: _openChallenge,
                onChanged: (value) => setState(() {
                  _openChallenge = value;
                  _searchError = null;
                  if (value) _selectedOpponent = null;
                }),
              ),
              if (!_openChallenge) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _opponentController,
                  autocorrect: false,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchOpponent(),
                  onChanged: (_) {
                    if (_selectedOpponent != null || _searchError != null) {
                      setState(() {
                        _selectedOpponent = null;
                        _searchError = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Email yoki foydalanuvchi ID',
                    hintText: 'friend@example.com yoki UUID',
                    prefixIcon: const Icon(Icons.person_search_rounded),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(13),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            tooltip: 'Qidirish',
                            onPressed: _searchOpponent,
                            icon: const Icon(Icons.search_rounded),
                          ),
                  ),
                ),
                if (_searchError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _searchError!,
                      style: const TextStyle(color: AppColors.destructive),
                    ),
                  ),
                if (_selectedOpponent case final opponent?) ...[
                  const SizedBox(height: 12),
                  _OpponentCard(opponent: opponent),
                ],
              ],
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _deckId == null
                    ? null
                    : () {
                        final opponentId = _openChallenge
                            ? null
                            : _selectedOpponent?.id;
                        if (!_openChallenge && opponentId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Avval raqibni email yoki ID orqali toping.',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(
                          context,
                          _NewBattleSelection(_deckId!, opponentId),
                        );
                      },
                icon: const Icon(Icons.sports_esports_rounded),
                label: const Text('Create and play'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpponentCard extends StatelessWidget {
  const _OpponentCard({required this.opponent});

  final BattleOpponent opponent;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.success,
            child: Icon(Icons.check_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opponent.label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (opponent.email != null && opponent.email != opponent.label)
                  Text(opponent.email!, style: TextStyle(color: muted)),
                const SizedBox(height: 3),
                SelectableText(
                  'ID: ${opponent.id}',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
