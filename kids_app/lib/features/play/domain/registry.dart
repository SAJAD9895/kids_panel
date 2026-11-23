import 'item_spec.dart';
import 'kinds/arrange_kinds.dart';
import 'kinds/choice_kinds.dart';
import 'kinds/memory_trace_kinds.dart';

/// Everything an activity type needs to know, in pure Dart: how to read its JSON, how to judge
/// an answer, and what its hints do. The UI side registers a matching view by the same [key].
///
/// Adding a type = one [ActivityKind] here + one view in the presentation registry. The player,
/// the session engine and progress tracking don't change.
abstract class ActivityKind<S extends ItemSpec> {
  const ActivityKind();

  String get key;

  /// Reads one item. [id] is stable for the item (position or question id).
  S parse(Map<String, dynamic> json, ParseContext ctx);

  Verdict evaluate(S spec, ItemAnswer answer);

  /// Hint [level] (1, 2, …). Return [Hint.none] when there's nothing more to give.
  Hint hint(S spec, int level) => level == 1 && !spec.hintText.isEmpty
      ? Hint(text: spec.hintText)
      : Hint.none;

  /// The correct answer, shown after the last try (null if it can't be shown).
  ItemAnswer? solution(S spec) => null;
}

/// Context for parsing: a stable id and seed for each item, and the difficulty policy.
class ParseContext {
  const ParseContext({
    required this.itemId,
    required this.seed,
    required this.policy,
  });

  final String itemId;
  final int seed;
  final DifficultyPolicy policy;

  SeededRandom get random => SeededRandom(seed);
}

/// The known activity types.
class KindRegistry {
  KindRegistry([Iterable<ActivityKind> kinds = const []]) {
    for (final k in kinds) {
      register(k);
    }
  }

  /// Every type built into the app.
  factory KindRegistry.standard() => KindRegistry(const [
    MultipleChoiceKind(),
    ImageChoiceKind(),
    AudioChoiceKind(),
    LetterRecognitionKind(),
    NumberRecognitionKind(),
    FillBlankKind(),
    DragToTargetKind(),
    SortKind(),
    MatchPairsKind(),
    WordBuildKind(),
    PuzzleKind(),
    MemoryKind(),
    TraceKind(),
    ArithmeticKind(),
    ShapeCompleteKind(),
    JigsawKind(),
  ]);

  final _kinds = <String, ActivityKind>{};

  void register(ActivityKind kind) => _kinds[kind.key] = kind;

  bool supports(String key) => _kinds.containsKey(key);

  Iterable<String> get keys => _kinds.keys;

  ActivityKind kindOf(ItemSpec spec) =>
      _kinds[spec.kind] ??
      (throw ContentException('unknown kind ${spec.kind}'));

  /// Reads one item; throws [ContentException] for unknown kinds or bad content.
  ItemSpec parseItem(Map<String, dynamic> json, ParseContext ctx) {
    final key = json['kind'];
    final kind = _kinds[key] ?? (throw ContentException('unknown kind $key'));
    try {
      return kind.parse(json, ctx);
    } on ContentException {
      rethrow;
    } catch (e) {
      throw ContentException('bad $key item ${ctx.itemId}: $e');
    }
  }

  Verdict evaluate(ItemSpec spec, ItemAnswer answer) =>
      kindOf(spec).evaluate(spec, answer);

  Hint hint(ItemSpec spec, int level) => kindOf(spec).hint(spec, level);

  ItemAnswer? solution(ItemSpec spec) => kindOf(spec).solution(spec);
}
