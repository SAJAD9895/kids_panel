import 'engine.dart';

/// What the completion screen tells the child (and the grown-up looking over their shoulder):
/// how many were right, and for memory games the moves and time. Pure, so it is tested.
class RunSummary {
  const RunSummary({
    required this.correct,
    required this.total,
    this.moves,
    this.timeMs,
  });

  factory RunSummary.of(RunState run) {
    int? moves, timeMs;
    for (var i = 0; i < run.items.length; i++) {
      if (run.items[i].kind != 'memory') continue;
      for (final a in run.progress[i].answers) {
        if (a is! Map) continue;
        moves = (moves ?? 0) + ((a['f'] as num?)?.toInt() ?? 0);
        final ms = (a['ms'] as num?)?.toInt();
        if (ms != null) timeMs = (timeMs ?? 0) + ms;
      }
    }
    return RunSummary(
      correct: run.correctCount,
      total: run.items.length,
      moves: moves,
      timeMs: timeMs,
    );
  }

  /// Right first time or after a retry (not the answers shown by the player).
  final int correct;
  final int total;

  /// Memory: pairs of cards turned, including misses.
  final int? moves;
  final int? timeMs;

  static String clock(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// Short lines for the completion screen, e.g. "8 of 10 right", "14 moves", "Time 0:42".
  List<String> get lines => [
    if (total > 1) '$correct of $total right',
    if (moves != null) '$moves moves',
    if (timeMs != null) 'Time ${clock(timeMs!)}',
  ];
}
