import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/features/play/domain/engine.dart';
import 'package:kids_app/features/play/domain/item_spec.dart';
import 'package:kids_app/features/play/domain/kinds/arrange_kinds.dart';
import 'package:kids_app/features/play/domain/kinds/memory_trace_kinds.dart';
import 'package:kids_app/features/play/domain/session_report.dart';
import 'package:kids_app/features/play/presentation/play_providers.dart';

import 'test_app.dart';

/// Answers every item of the "Try everything!" activity (one of each type) the right way,
/// like a child would: taps, tap-to-place, swaps and a finger trace. [beforeAnswer] runs on
/// each item before it is answered (e.g. accessibility checks).
Future<void> playSampler(
  WidgetTester tester, {
  Future<void> Function(String kind)? beforeAnswer,
}) async {
  RunState run() =>
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(
            playerProvider((
              activityId: 'engine-sampler',
              courseId: null,
              stepId: null,
              source: PlaySource.feed,
            )),
          )
          .run!;

  Future<void> next() async {
    final f = find.bySemanticsLabel(RegExp(r'^(Next|Finish)$'));
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  Future<void> tapRe(String pattern, {bool last = false}) async {
    final f = find.bySemanticsLabel(RegExp(pattern));
    final target = last ? f.last : f.first;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  final total = run().items.length;
  for (var i = 0; i < total; i++) {
    final item = run().item;
    await beforeAnswer?.call(item.kind);
    switch (item.kind) {
      case 'multiple_choice':
        await tapLabel(tester, 'banana');
      case 'image_choice':
        await tapLabel(tester, 'bird');
      case 'audio_choice':
        await tapLabel(tester, 'cat');
      case 'letter_recognition':
        await tapLabel(tester, 'm');
      case 'number_recognition':
        await tapLabel(tester, '7');
      case 'drag_to_target':
        for (final (a, b) in [('fish', 'water'), ('bird', 'tree')]) {
          await tapLabel(tester, a);
          await tapRe('^$b(,|\$)');
        }
      case 'sort':
        for (final (a, b) in [
          ('cow', 'Animals'),
          ('apple', 'Food'),
          ('duck', 'Animals'),
        ]) {
          await tapLabel(tester, a);
          await tapRe('^$b(,|\$)');
        }
      case 'match_pairs':
        for (final w in ['cat', 'sun', 'car']) {
          await tapRe('^$w\$');
          await tapRe('^$w\$', last: true);
        }
      case 'fill_blank':
        await tapLabel(tester, 'moo');
      case 'word_build':
        for (final l in ['c', 'a', 't']) {
          await tapLabel(tester, l);
        }
      case 'memory':
        final m = item as MemorySpec;
        final pairs = <String, List<int>>{};
        for (final (j, c) in m.cards.indexed) {
          pairs.putIfAbsent(MemorySpec.pairOf(c.id), () => []).add(j);
        }
        for (final idx in pairs.values) {
          for (final j in idx) {
            await tapLabel(tester, 'Card ${j + 1}, face down');
          }
        }
      case 'puzzle':
        final p = item as OrderSpec;
        final layout = [...p.start];
        for (var pos = 0; pos < layout.length; pos++) {
          final want = p.order[pos];
          if (layout[pos] == want) continue;
          final from = layout.indexOf(want);
          await tapLabel(
            tester,
            'Piece ${p.order.indexOf(layout[pos]) + 1}, in place ${pos + 1}',
          );
          await tapLabel(
            tester,
            'Piece ${p.order.indexOf(want) + 1}, in place ${from + 1}',
          );
          layout[from] = layout[pos];
          layout[pos] = want;
        }
      case 'trace':
        final t = item as TraceSpec;
        final area = find.bySemanticsLabel(RegExp('^Tracing area'));
        await tester.ensureVisible(area);
        await tester.pumpAndSettle();
        final box = tester.getRect(area);
        Offset at(Pt p) =>
            Offset(box.left + p.x * box.width, box.top + p.y * box.height);
        for (final stroke in t.strokes) {
          final pts = TraceSpec.resample(stroke, 0.03);
          final g = await tester.startGesture(at(pts.first));
          for (final p in pts.skip(1)) {
            await g.moveTo(at(p));
          }
          await g.up();
        }
        await tester.pumpAndSettle();
        await tapLabel(tester, 'Check');
      case 'arithmetic':
        await tapLabel(tester, '3');
      case 'shape_complete':
        await tapLabel(tester, 'the right side of a circle');
      case 'jigsaw':
        final j = item as JigsawSpec;
        for (final t in [...j.tokens]) {
          final i = JigsawSpec.indexOf(t.id);
          await tapRe('^Piece ${i + 1}(,|\$)');
          await tapRe('^Place ${i + 1},');
        }
    }
    expect(
      find.text('Great job!').evaluate().isNotEmpty ||
          find.text('You did it!').evaluate().isNotEmpty,
      isTrue,
      reason: '${item.kind} answered right',
    );
    await next();
  }
}
