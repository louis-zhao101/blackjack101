import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blackjack101/engine/cards.dart' as bj;
import 'package:blackjack101/ui/theme/appearance.dart';
import 'package:blackjack101/ui/widgets/playing_card.dart';

void main() {
  test('illuminated deck maps every card to an existing asset path', () {
    for (final suit in ['♥', '♦', '♠', '♣']) {
      for (final rank in [
        'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'
      ]) {
        final path = cardDeckIlluminated.faceAsset(rank, suit);
        expect(path, isNotNull);
        expect(path, startsWith('assets/card_faces/illuminated/'));
        expect(path, endsWith('.jpg'));
      }
    }
    // Classic (free) deck draws procedurally — no asset.
    expect(cardDeckClassic.faceAsset('A', '♠'), isNull);
  });

  test('ukiyo-e deck maps to its own asset directory', () {
    expect(cardDeckUkiyoe.faceAsset('K', '♥'), 'assets/card_faces/ukiyo-e/hearts_K.jpg');
    expect(cardDeckUkiyoe.faceAsset('10', '♣'), 'assets/card_faces/ukiyo-e/clubs_10.jpg');
  });

  testWidgets('face-up card renders the deck image asset', (tester) async {
    final theme = classicGreen.copyWith(deck: cardDeckIlluminated);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: PlayingCardView(
            card: const bj.Card(rank: 'K', suit: '♥'),
            theme: theme,
            width: 150,
          ),
        ),
      ),
    ));
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(provider.assetName, 'assets/card_faces/illuminated/hearts_K.jpg');
  });

  testWidgets('a PageView preview lays out inside an AlertDialog without crashing',
      (tester) async {
    // AlertDialog measures its content's intrinsic width; a PageView can't report
    // one, so the deck carousel must resolve a fixed width first. This reproduces
    // that structure and would throw "RenderBox was not laid out" without it.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: ctx,
              builder: (_) => AlertDialog(
                content: SizedBox(
                  width: 260,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 240,
                        child: PageView(
                          children: const [Center(child: Text('a')), Center(child: Text('b'))],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('classic deck falls back to procedural face (no Image)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: PlayingCardView(
            card: const bj.Card(rank: 'K', suit: '♥'),
            theme: classicGreen,
            width: 150,
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
  });
}
