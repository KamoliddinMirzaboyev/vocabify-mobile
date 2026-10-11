import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocabify_app/providers/decks_provider.dart';
import 'package:vocabify_app/providers/cards_provider.dart';
import 'package:vocabify_app/providers/stats_provider.dart';
import 'package:vocabify_app/core/services/cache_service.dart';
import 'package:vocabify_app/models/deck_model.dart';
import 'package:vocabify_app/widgets/skeleton/app_skeleton.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Skeleton Widgets Rendering Tests', () {
    testWidgets('AppShimmer and basic SkeletonBox render correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppShimmer(
              child: Column(
                children: [
                  SkeletonBox(width: 100, height: 20),
                  SkeletonLine(width: 80, height: 14),
                  SkeletonCircle(size: 40),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AppShimmer), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byType(SkeletonLine), findsOneWidget);
      expect(find.byType(SkeletonCircle), findsOneWidget);
    });

    testWidgets('HomeScreenSkeleton renders all sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: HomeScreenSkeleton())),
      );

      expect(find.byType(HomeScreenSkeleton), findsOneWidget);
      expect(find.byType(AppShimmer), findsOneWidget);
    });

    testWidgets('DecksScreenSkeleton renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DecksScreenSkeleton())),
      );

      expect(find.byType(DecksScreenSkeleton), findsOneWidget);
    });

    testWidgets('DeckDetailScreenSkeleton renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DeckDetailScreenSkeleton())),
      );

      expect(find.byType(DeckDetailScreenSkeleton), findsOneWidget);
    });

    testWidgets('StatsScreenSkeleton renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StatsScreenSkeleton())),
      );

      expect(find.byType(StatsScreenSkeleton), findsOneWidget);
    });
  });

  group('Provider Request & Cache Fast-Path Tests', () {
    test('DecksProvider initializes with isInitialLoading = false', () {
      final provider = DecksProvider();
      expect(provider.isInitialLoading, isFalse);
      expect(provider.isLoading, isFalse);
      expect(provider.decks, isEmpty);
    });

    test('CardsProvider tracks per-deck initial loading', () {
      final provider = CardsProvider();
      expect(provider.isDeckInitialLoading('test_deck'), isFalse);
      expect(provider.isAllCardsInitialLoading, isFalse);
      expect(provider.getCardsForDeck('test_deck'), isEmpty);
    });

    test('StatsProvider initializes with isInitialLoading = false', () {
      final provider = StatsProvider();
      expect(provider.isInitialLoading, isFalse);
      expect(provider.isLoading, isFalse);
      expect(provider.stats.totalCards, equals(0));
    });

    test('session clear removes in-memory deck data', () async {
      CacheService.instance.activateUser('user-1');
      await CacheService.instance.cacheDecks([
        DeckModel(id: 'deck-1', userId: 'user-1', name: 'Private'),
      ]);
      final provider = DecksProvider();
      await Future<void>.delayed(Duration.zero);
      expect(provider.decks, isNotEmpty);

      provider.clear();

      expect(provider.decks, isEmpty);
    });
  });
}
