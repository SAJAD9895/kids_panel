/// Turns rows of the `questions` / `answers` tables into engine items, so quizzes written in the
/// admin CMS play in the same player as games. Pure: tested in test/unit/quiz_mapping_test.dart.
library;

int _pos(Map a) => (a['position'] as num?)?.toInt() ?? 0;

Map<String, dynamic> _option(Map a) {
  final content = (a['content'] as Map?) ?? const {};
  final label = Map<String, dynamic>.from(content)..remove('picture');
  return {
    'id': a['id'],
    if (label.isNotEmpty) 'label': label,
    if (content['picture'] != null) 'picture': content['picture'],
  };
}

/// One question row (with its `answers`) → one engine item, or null for a type the engine
/// can't play yet.
Map<String, dynamic>? itemFromQuestion(Map<String, dynamic> q) {
  final answers = ((q['answers'] as List?) ?? const []).cast<Map>()
    ..sort((a, b) => _pos(a).compareTo(_pos(b)));
  final id = q['id'] as String;
  final prompt = q['prompt'];
  switch (q['type']) {
    case 'single_choice' ||
        'multi_choice' ||
        'true_false' ||
        'tap_target' ||
        'listen_choose':
      final options = answers.map(_option).toList();
      return {
        'kind': q['type'] == 'listen_choose'
            ? 'audio_choice'
            : 'multiple_choice',
        'questionId': id,
        'prompt': q['type'] == 'listen_choose'
            ? {'speak': prompt}
            : {'text': prompt},
        'options': options,
        'correct': [
          for (final a in answers)
            if (a['is_correct'] == true) a['id'],
        ],
        'answerIds': {for (final a in answers) '${a['id']}': a['id']},
        'shuffle': q['type'] != 'true_false',
      };
    case 'match':
      final byKey = <String, List<Map>>{};
      for (final a in answers) {
        final k = a['match_key'] as String?;
        if (k != null) byKey.putIfAbsent(k, () => []).add(a);
      }
      final pairs = [
        for (final p in byKey.values)
          if (p.length == 2) {'left': _option(p[0]), 'right': _option(p[1])},
      ];
      return pairs.length < 2
          ? null
          : {
              'kind': 'match_pairs',
              'questionId': id,
              'prompt': {'text': prompt},
              'pairs': pairs,
            };
    case 'order':
      final ordered = [...answers]
        ..sort(
          (a, b) => ((a['correct_order'] as num?) ?? 0).compareTo(
            (b['correct_order'] as num?) ?? 0,
          ),
        );
      return {
        'kind': 'puzzle',
        'questionId': id,
        'prompt': {'text': prompt},
        'pieces': ordered.map(_option).toList(),
      };
    default:
      return null;
  }
}
