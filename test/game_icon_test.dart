import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opack/features/catalog/domain/models.dart';
import 'package:opack/shared/widgets/game_icon.dart';

void main() {
  testWidgets('every game has an emblem that paints at any size', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            for (final game in Game.values) ...[
              GameIcon(game, key: ValueKey('icon-${game.name}')),
              GameIcon(game, size: 64, color: Colors.red),
            ],
          ],
        ),
      ),
    ));
    await tester.pump();
    for (final game in Game.values) {
      expect(find.byKey(ValueKey('icon-${game.name}')), findsOneWidget);
      expect(tester.getSize(find.byKey(ValueKey('icon-${game.name}'))), const Size(24, 24));
    }
    expect(tester.takeException(), isNull, reason: 'no painting error');
  });
}
