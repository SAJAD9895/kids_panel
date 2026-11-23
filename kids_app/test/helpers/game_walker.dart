import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/features/play/domain/item_spec.dart';
import 'package:kids_app/features/play/domain/kinds/arrange_kinds.dart';
import 'package:kids_app/features/play/domain/kinds/choice_kinds.dart';
import 'package:kids_app/features/play/domain/kinds/memory_trace_kinds.dart';

import 'test_app.dart';

/// Plays any engine item the way a child would (taps, tap-to-place, swaps, a finger trace),
/// working only from the item's content, so every game and level can be walked by one helper.
class GameWalker {
  GameWalker(this.tester);

  final WidgetTester tester;

  Future<void> _tap(Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Finder _exact(String label) => find.bySemanticsLabel(label);
  Finder _place(String label) =>
      find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}(,|\$)'));

  /// Answers [item] correctly.
  Future<void> answerRight(ItemSpec item) async {
    switch (item) {
      case JigsawSpec j:
        for (final t in [...j.tokens]) {
          final i = JigsawSpec.indexOf(t.id);
          await _tap(
            find.bySemanticsLabel(RegExp('^Piece ${i + 1}(,|\$)')).first,
          );
          await _tap(find.bySemanticsLabel(RegExp('^Place ${i + 1},')).first);
        }
      case ChoiceSpec c:
        for (final id in c.correct) {
          final o = c.options.firstWhere((o) => o.id == id);
          await _tap(_exact(o.spoken()).last);
        }
        if (c.multi) await tapLabel(tester, 'Done');
      case PlaceSpec p:
        for (final t in p.tokens) {
          final target = p.targets.firstWhere((g) => g.id == p.solution[t.id]);
          // a token's label can carry its state ("cat, not this one" after a bounce)
          await _tap(_place(t.spoken()).first);
          await _tap(_place(target.spoken()).last);
        }
      case OrderSpec o when o.kind == 'word_build':
        for (final id in o.order) {
          await tapLabel(tester, o.piece(id).label.of());
        }
      case OrderSpec o:
        final layout = [...o.start];
        for (var pos = 0; pos < layout.length; pos++) {
          final want = o.order[pos];
          if (layout[pos] == want) continue;
          final from = layout.indexOf(want);
          String label(String id, int at) => o.columns == 0
              ? o.piece(id).spoken()
              : 'Piece ${o.order.indexOf(id) + 1}, in place ${at + 1}';
          await tapLabel(tester, label(layout[pos], pos));
          await tapLabel(tester, label(want, from));
          layout[from] = layout[pos];
          layout[pos] = want;
        }
      case MemorySpec m:
        final pairs = <String, List<int>>{};
        for (final (j, c) in m.cards.indexed) {
          pairs.putIfAbsent(MemorySpec.pairOf(c.id), () => []).add(j);
        }
        for (final idx in pairs.values) {
          for (final j in idx) {
            await tapLabel(tester, 'Card ${j + 1}, face down');
          }
        }
      case TraceSpec t:
        await trace(t.strokes);
        await tapLabel(tester, 'Check');
      default:
        fail('no walker for ${item.kind}');
    }
  }

  /// Gives a wrong answer where the type has one (choices, words, tracing). Returns false for
  /// types where a wrong move is only a mistake inside a right answer (placing, memory, puzzles).
  Future<bool> answerWrong(ItemSpec item) async {
    switch (item) {
      case ChoiceSpec c when !c.multi:
        final o = c.options.firstWhere((o) => !c.correct.contains(o.id));
        await _tap(_exact(o.spoken()).last);
        return true;
      case OrderSpec o when o.kind == 'word_build':
        for (final id in o.order.reversed) {
          await tapLabel(tester, o.piece(id).label.of());
        }
        // a palindrome-free word list: reversed is wrong unless it reads the same
        return o.order.map((i) => o.piece(i).label.of()).join() !=
            o.order.reversed.map((i) => o.piece(i).label.of()).join();
      case TraceSpec _:
        await trace([
          [const Pt(0.1, 0.1), const Pt(0.15, 0.12)],
        ]);
        await tapLabel(tester, 'Check');
        return true;
      default:
        return false;
    }
  }

  Future<void> trace(List<List<Pt>> strokes) async {
    final area = find.bySemanticsLabel(RegExp('^Tracing area'));
    await tester.ensureVisible(area);
    await tester.pumpAndSettle();
    final box = tester.getRect(area);
    Offset at(Pt p) =>
        Offset(box.left + p.x * box.width, box.top + p.y * box.height);
    for (final stroke in strokes) {
      final pts = TraceSpec.resample(stroke, 0.03);
      final g = await tester.startGesture(at(pts.first));
      for (final p in pts.skip(1)) {
        await g.moveTo(at(p));
      }
      await g.up();
    }
    await tester.pumpAndSettle();
  }
}
