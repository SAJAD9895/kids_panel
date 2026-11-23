// Generates engine-parity.golden.json from the Flutter app's Dart engine, so the TypeScript port
// (web_app/src/lib/engine) is checked against the real thing item by item.
// Regenerate after changing the Dart engine or the seed content:
//   cd web_app/test/unit && dart run engine-parity.golden.dart > engine-parity.golden.json
import 'dart:convert';
import 'dart:io';
import '../../../kids_app/lib/features/learning/domain/catalog.dart';
import '../../../kids_app/lib/features/play/domain/item_spec.dart';
import '../../../kids_app/lib/features/play/domain/registry.dart';
import '../../../kids_app/lib/features/play/domain/engine.dart';
import '../../../kids_app/lib/features/play/domain/session_report.dart';
import '../../../kids_app/lib/features/play/domain/kinds/choice_kinds.dart';
import '../../../kids_app/lib/features/play/domain/kinds/arrange_kinds.dart';
import '../../../kids_app/lib/features/play/domain/kinds/memory_trace_kinds.dart';

Map<String, Object?> txt(LocalizedText t) => t.values;
Object? pic(PictureRef? p) => p?.value;
Map<String, Object?> ch(Choice c) => {'id': c.id, 'label': txt(c.label), 'picture': pic(c.picture), 'speak': txt(c.speak)};
Map<String, Object?> hint(Hint h) => {'text': txt(h.text), 'eliminate': h.eliminate.toList(), 'reveal': h.reveal.toList()};

Map<String, Object?> project(KindRegistry r, ItemSpec s) {
  final out = <String, Object?>{
    'id': s.id, 'kind': s.kind, 'questionId': s.questionId,
    'prompt': {'text': txt(s.prompt.text), 'speak': txt(s.prompt.speak), 'picture': pic(s.prompt.picture)},
    'hintText': txt(s.hintText),
    'hint1': hint(r.hint(s, 1)), 'hint2': hint(r.hint(s, 2)),
  };
  if (s is ChoiceSpec) {
    out.addAll({'options': s.options.map(ch).toList(), 'correct': s.correct.toList(), 'style': s.style.name,
      'audioOnly': s.audioOnly, 'count': s.count, 'countPicture': pic(s.countPicture),
      'sentence': s.sentence == null ? null : txt(s.sentence!), 'answerIds': s.answerIds});
  } else if (s is PlaceSpec) {
    out.addAll({'tokens': s.tokens.map(ch).toList(), 'targets': s.targets.map(ch).toList(), 'solution': s.solution});
    if (s is JigsawSpec) out.addAll({'picture': s.picture.value, 'grid': s.grid});
  } else if (s is OrderSpec) {
    out.addAll({'pieces': s.pieces.map(ch).toList(), 'order': s.order, 'start': s.start, 'picture': pic(s.picture), 'columns': s.columns});
  } else if (s is MemorySpec) {
    out.addAll({'cards': s.cards.map(ch).toList(), 'timer': s.timer, 'pairs': s.pairs});
  } else if (s is TraceSpec) {
    out.addAll({'strokes': s.strokes.map((st) => st.length).toList(), 'firstPoint': [s.strokes.first.first.x, s.strokes.first.first.y], 'tolerance': s.tolerance, 'glyph': s.glyph});
  }
  return out;
}

void main() {
  final seed = File.fromUri(Platform.script.resolve('../../../supabase/seed.sql')).readAsStringSync();
  final rows = RegExp(r"update games set config = '(.*)'::jsonb -- engine:([a-z0-9-]+)").allMatches(seed);
  final configs = <String, Map<String, dynamic>>{
    for (final m in rows) m.group(2)!: (jsonDecode(m.group(1)!.replaceAll("''", "'")) as Map).cast<String, dynamic>(),
  };
  configs['admin-every-kind'] = (jsonDecode(File.fromUri(Platform.script.resolve('../../../kids_app/test/fixtures/admin_cms/every_kind.json')).readAsStringSync()) as Map).cast<String, dynamic>();
  final r = KindRegistry.standard();
  final out = <String, Object?>{};
  for (final e in configs.entries) {
    final base = ActivitySource.fromConfig(
      activity: ActivitySummary(id: e.key, slug: e.key, type: ActivityType.game, title: LocalizedText({'en': e.key})),
      config: e.value, difficulty: 2);
    for (final age in [30, 60, 100]) {
      final levelIds = base.levels.isEmpty ? <String?>[null] : base.levels.map((l) => l.id).toList();
      for (final lid in levelIds) {
        final src = base.forLevel(lid);
        final p0 = DifficultyPolicy.forChild(ageMonths: age, difficulty: src.difficulty);
        final p = src.level?.apply(p0) ?? p0;
        final items = src.build(r, p, 'sess-$age');
        out['${e.key}|$age|${lid ?? '-'}'] = {
          'defaultLevel': base.defaultLevel(age)?.id,
          'policy': {'maxAttempts': p.maxAttempts, 'maxOptions': p.maxOptions, 'autoSpeak': p.autoSpeak, 'offerHintAfterWrong': p.offerHintAfterWrong, 'traceTolerance': p.traceTolerance},
          'intro': {'text': txt(src.intro.text), 'speak': txt(src.intro.speak)},
          'items': items.map((s) => project(r, s)).toList(),
        };
      }
    }
  }
  // a scripted run with mixed outcomes, reported
  final quizItem = {
    'kind': 'multiple_choice', 'questionId': 'q1', 'prompt': {'text': {'en': 'Which?'}},
    'options': [{'id': 'a1', 'label': {'en': 'a'}}, {'id': 'a2', 'label': {'en': 'b'}}, {'id': 'a3', 'label': {'en': 'c'}}],
    'correct': ['a1'], 'answerIds': {'a1': 'a1', 'a2': 'a2', 'a3': 'a3'}, 'shuffle': true,
  };
  final src = ActivitySource.fromConfig(
    activity: const ActivitySummary(id: 'x', slug: 'x', type: ActivityType.game, title: LocalizedText({'en': 'x'})),
    config: {'items': [
      {'kind': 'letter_recognition', 'target': 'b'},
      quizItem,
      {'kind': 'memory', 'cards': ['a', 'b', 'c']},
      {'kind': 'word_build', 'word': 'cat'},
    ]});
  const pol = DifficultyPolicy(maxOptions: 4, maxAttempts: 2);
  final eng = SessionEngine(r, pol);
  final t0 = DateTime.utc(2026, 11, 18, 10);
  DateTime at(int s) => t0.add(Duration(seconds: s));
  var s = eng.begin(eng.create(sessionId: 'run-1', childId: 'c', activityId: 'x', items: src.build(r, pol, 'run-1'), now: t0, level: 'lv'), t0);
  s = eng.hint(s).$1;
  s = eng.retry(eng.answer(s, const PickAnswer({'d'}), at(3)).$1, at(4));
  s = eng.next(eng.answer(s, const PickAnswer({'b'}), at(6)).$1, at(7));
  s = eng.retry(eng.answer(s, const PickAnswer({'a2'}), at(9)).$1, at(10));
  s = eng.next(eng.answer(s, const PickAnswer({'a3'}), at(12)).$1, at(13)); // revealed
  s = eng.pause(s, at(14));
  s = eng.resume(s, at(40));
  s = eng.next(eng.answer(s, const MemoryAnswer(flips: 9, pairsFound: 3, timeMs: 20000), at(50)).$1, at(51));
  final mid = SessionReport.ended(s, now: at(52), source: PlaySource.course, platform: 'web', appVersion: '1.0.0', contentVersion: 3).toJson();
  s = eng.next(eng.answer(s, const OrderAnswer(['w0', 'w1', 'w2'], mistakes: 1), at(60)).$1, at(61));
  final end = SessionReport.ended(s, now: at(62), source: PlaySource.course, platform: 'web', appVersion: '1.0.0', contentVersion: 3).toJson();
  final started = SessionReport.started(s, source: PlaySource.feed, platform: 'web', appVersion: '1.0.0').toJson();
  out['__run'] = {'abandoned': mid, 'completed': end, 'started': started, 'snapshot': s.toSnapshot(at(62))};
  print(jsonEncode(out));
}
