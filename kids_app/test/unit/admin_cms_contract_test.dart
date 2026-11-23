import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/features/learning/domain/catalog.dart';
import 'package:kids_app/features/play/domain/item_spec.dart';
import 'package:kids_app/features/play/domain/registry.dart';
import 'package:kids_app/features/play/domain/session_report.dart';

/// Phase 14 contract: a game built in the admin CMS (admin_panel game builder, every engine kind,
/// written by admin_panel/test/unit/game.test.ts) is read and played by this app's engine.
void main() {
  final file = File('test/fixtures/admin_cms/every_kind.json');

  test('the admin-built game has levels, an intro and every kind', () {
    final config = (jsonDecode(file.readAsStringSync()) as Map)
        .cast<String, dynamic>();
    final source = ActivitySource.fromConfig(
      activity: const ActivitySummary(
        id: 'admin-every-kind',
        slug: 'admin-every-kind',
        type: ActivityType.game,
        title: LocalizedText({'en': 'Every kind'}),
      ),
      config: config,
    );
    expect(source.levels.map((l) => l.id), ['easy', 'hard']);
    expect(source.intro.text, isNotNull);
    final registry = KindRegistry.standard();
    final kinds = <String>{};
    var n = 0;
    for (final level in source.levels) {
      for (final raw in level.rawItems) {
        final spec = registry.parseItem(
          raw,
          ParseContext(
            itemId: 'i${n++}',
            seed: 3,
            policy: const DifficultyPolicy(maxOptions: 6),
          ),
        );
        kinds.add(spec.kind);
        // every item has an answer the engine can show, except the two kinds that are
        // played rather than answered (tracing strokes, turning memory cards)
        if (!{'trace', 'memory'}.contains(spec.kind)) {
          expect(registry.solution(spec), isNotNull, reason: spec.kind);
        }
      }
    }
    expect(kinds, registry.keys.toSet());
  });
}
