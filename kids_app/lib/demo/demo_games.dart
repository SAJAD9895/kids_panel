/// The Phase 10 game collection: eight games built on the learning engine, each with Easy,
/// Medium and Hard levels (`games.config.levels`). Development content only, small on purpose;
/// the shape of it (docs/games/content-requirements.md) is what the admin CMS will edit.
///
/// Mirrored into supabase/seed.sql §15 by `dart run tool/seed_content_sql.dart --write`;
/// a test fails if the two differ.
library;

/// Catalogue facts for each game (the `activities` row).
class DemoGame {
  const DemoGame({
    required this.slug,
    required this.title,
    required this.description,
    required this.subject,
    required this.ageMin,
    required this.ageMax,
    required this.seconds,
    required this.keywords,
  });

  final String slug;
  final String title;
  final String description;
  final String subject;
  final int ageMin;
  final int ageMax;
  final int seconds;
  final String keywords;
}

const demoGames = <DemoGame>[
  DemoGame(
    slug: 'memory-match',
    title: 'Memory match',
    description: 'Flip the cards and find the pairs',
    subject: 'thinking',
    ageMin: 30,
    ageMax: 108,
    seconds: 240,
    keywords: 'memory pairs cards',
  ),
  DemoGame(
    slug: 'picture-match',
    title: 'Picture match',
    description: 'Match each picture to its word',
    subject: 'english',
    ageMin: 30,
    ageMax: 96,
    seconds: 200,
    keywords: 'match pictures words',
  ),
  DemoGame(
    slug: 'word-builder',
    title: 'Word builder',
    description: 'Put the letters in order to make a word',
    subject: 'letters',
    ageMin: 42,
    ageMax: 108,
    seconds: 240,
    keywords: 'spelling words letters',
  ),
  DemoGame(
    slug: 'number-fun',
    title: 'Number fun',
    description: 'Count, match numbers, add and take away',
    subject: 'numbers',
    ageMin: 30,
    ageMax: 108,
    seconds: 300,
    keywords: 'numbers counting adding',
  ),
  DemoGame(
    slug: 'alphabet-adventure',
    title: 'Alphabet adventure',
    description: 'Letters big and small, their sounds, and tracing',
    subject: 'letters',
    ageMin: 30,
    ageMax: 96,
    seconds: 300,
    keywords: 'alphabet letters phonics tracing',
  ),
  DemoGame(
    slug: 'sort-it-out',
    title: 'Sort it out',
    description: 'Sort by shape, colour, size and kind',
    subject: 'shapes',
    ageMin: 30,
    ageMax: 96,
    seconds: 240,
    keywords: 'sorting colours shapes sizes',
  ),
  DemoGame(
    slug: 'puzzle-time',
    title: 'Puzzle time',
    description: 'Jigsaws and shapes to finish',
    subject: 'thinking',
    ageMin: 30,
    ageMax: 108,
    seconds: 300,
    keywords: 'puzzle jigsaw shapes',
  ),
  DemoGame(
    slug: 'quiz-time',
    title: 'Quiz time',
    description: 'Questions to read, look at and listen to',
    subject: 'thinking',
    ageMin: 36,
    ageMax: 108,
    seconds: 240,
    keywords: 'quiz questions',
  ),
];

Map<String, Object?> _level(
  String id,
  String label,
  int minAge,
  List<Map<String, Object?>> items, {
  int? options,
  int? attempts,
}) => {
  'id': id,
  'label': label,
  'minAgeMonths': minAge,
  'options': ?options,
  'attempts': ?attempts,
  'items': items,
};

Map<String, Object?> _card(String name, [String? picture]) => {
  'id': name,
  'picture': picture ?? 'icon:$name',
  'label': name,
};

Map<String, Object?> _wordPicture(String word, [String? picture]) => {
  'left': {'label': word},
  'right': {'picture': picture ?? 'icon:$word', 'label': word},
};

Map<String, Object?> _case(String l) => {
  'left': {
    'picture': 'glyph:${l.toUpperCase()}',
    'speak': 'big ${l.toUpperCase()}',
  },
  'right': {'picture': 'glyph:$l', 'speak': 'small $l'},
};

Map<String, Object?> _countToNumber(int n, String icon) => {
  'left': {'picture': 'count:$n:$icon', 'speak': '$n ${icon}s'},
  'right': {'label': '$n'},
};

Map<String, Object?> _sortItem(
  String id,
  String picture,
  String bin, [
  String? label,
]) => {'id': id, 'picture': picture, 'bin': bin, 'label': ?label};

final Map<String, Map<String, Object?>> demoGameContent = {
  // 1. Memory match: more pairs each level, with a move counter and a clock.
  'memory-match': {
    'intro': {
      'text': 'Find the pairs',
      'speak': 'Turn over two cards at a time. Can you find all the pairs in a few moves?',
    },
    'levels': [
      _level('easy', 'Easy', 0, options: 3, [
        {
          'kind': 'memory',
          'timer': true,
          'cards': [_card('cat'), _card('dog'), _card('duck')],
        },
        {
          'kind': 'memory',
          'timer': true,
          'cards': [_card('sun'), _card('moon'), _card('star', 'shape:star')],
        },
      ]),
      _level('medium', 'Medium', 54, options: 6, [
        {
          'kind': 'memory',
          'timer': true,
          'cards': [
            _card('apple'),
            _card('banana'),
            _card('carrot'),
            _card('cake'),
            _card('flower'),
            _card('tree'),
          ],
        },
      ]),
      _level('hard', 'Hard', 78, options: 8, [
        {
          'kind': 'memory',
          'timer': true,
          'cards': [
            _card('cat'),
            _card('dog'),
            _card('cow'),
            _card('duck'),
            _card('fish'),
            _card('bird'),
            _card('sun'),
            _card('moon'),
          ],
        },
      ]),
    ],
  },

  // 2. Picture match: words to pictures (drag or tap), each name read aloud when picked.
  'picture-match': {
    'intro': {
      'text': 'Match the pictures',
      'speak': 'Tap or drag each word to its picture. Tap a picture to hear its name.',
    },
    'levels': [
      _level('easy', 'Easy', 0, [
        {
          'kind': 'match_pairs',
          'prompt': {'text': 'Match the word to the picture'},
          'pairs': [_wordPicture('cat'), _wordPicture('sun')],
        },
        {
          'kind': 'drag_to_target',
          'prompt': {
            'text': 'Who lives where?',
            'speak': 'Take each animal to its home.',
          },
          'tokens': [_card('fish'), _card('bird')],
          'targets': [
            {'id': 'water', 'label': 'water', 'picture': 'icon:water'},
            {'id': 'tree', 'label': 'tree', 'picture': 'icon:tree'},
          ],
          'solution': {'fish': 'water', 'bird': 'tree'},
        },
      ]),
      _level('medium', 'Medium', 54, [
        {
          'kind': 'match_pairs',
          'prompt': {'text': 'Match the word to the picture'},
          'pairs': [
            _wordPicture('dog'),
            _wordPicture('car'),
            _wordPicture('cake'),
          ],
        },
        {
          'kind': 'match_pairs',
          'prompt': {'text': 'Match the word to the picture'},
          'pairs': [
            _wordPicture('apple'),
            _wordPicture('ball'),
            _wordPicture('house'),
          ],
        },
      ]),
      _level('hard', 'Hard', 78, [
        {
          'kind': 'match_pairs',
          'prompt': {'text': 'Match the word to the picture'},
          'pairs': [
            _wordPicture('flower'),
            _wordPicture('carrot'),
            _wordPicture('moon'),
            _wordPicture('sailboat', 'icon:sailboat'),
          ],
        },
        {
          'kind': 'match_pairs',
          'prompt': {
            'text': 'Which go together?',
            'speak': 'Match the things that go together.',
          },
          'pairs': [
            {'left': _card('fish'), 'right': _card('water')},
            {'left': _card('bird'), 'right': _card('tree')},
            {'left': _card('dog'), 'right': _card('house')},
          ],
        },
      ]),
    ],
  },

  // 3. Word builder: a picture hint, letters spoken as they're tapped; harder levels add a
  //    letter that doesn't belong.
  'word-builder': {
    'intro': {
      'text': 'Build the word',
      'speak':
          'Look at the picture. Tap the letters in order to spell the word.',
    },
    'levels': [
      _level('easy', 'Easy', 0, [
        {'kind': 'word_build', 'word': 'cat', 'picture': 'icon:cat'},
        {'kind': 'word_build', 'word': 'sun', 'picture': 'icon:sun'},
        {'kind': 'word_build', 'word': 'dog', 'picture': 'icon:dog'},
      ]),
      _level('medium', 'Medium', 60, [
        {
          'kind': 'word_build',
          'word': 'fish',
          'picture': 'icon:fish',
          'extra': 'a',
        },
        {
          'kind': 'word_build',
          'word': 'moon',
          'picture': 'icon:moon',
          'extra': 'e',
        },
        {
          'kind': 'word_build',
          'word': 'cake',
          'picture': 'icon:cake',
          'extra': 'o',
        },
      ]),
      _level('hard', 'Hard', 78, [
        {
          'kind': 'word_build',
          'word': 'apple',
          'picture': 'icon:apple',
          'extra': 'u',
        },
        {
          'kind': 'word_build',
          'word': 'house',
          'picture': 'icon:house',
          'extra': 'a',
        },
        {
          'kind': 'word_build',
          'word': 'flower',
          'picture': 'icon:flower',
          'extra': 'i',
        },
      ]),
    ],
  },

  // 4. Number fun: recognise, count, match, add and take away.
  'number-fun': {
    'intro': {
      'text': 'Number fun',
      'speak': 'Let us count, find numbers, and add and take away.',
    },
    'levels': [
      _level('easy', 'Easy', 0, [
        {'kind': 'number_recognition', 'count': 3, 'picture': 'icon:apple'},
        {
          'kind': 'number_recognition',
          'target': 2,
          'distractors': [5, 4],
        },
        {
          'kind': 'match_pairs',
          'prompt': {
            'text': 'Match the number',
            'speak': 'Count, then match each group to its number.',
          },
          'pairs': [
            _countToNumber(1, 'star'),
            _countToNumber(2, 'star'),
            _countToNumber(3, 'star'),
          ],
        },
        {
          'kind': 'arithmetic',
          'a': 2,
          'op': '+',
          'b': 1,
          'picture': 'icon:apple',
        },
      ]),
      _level('medium', 'Medium', 54, [
        {'kind': 'number_recognition', 'count': 6, 'picture': 'icon:sailboat'},
        {
          'kind': 'number_recognition',
          'target': 8,
          'distractors': [3, 6, 9],
        },
        {
          'kind': 'match_pairs',
          'prompt': {
            'text': 'Match the number',
            'speak': 'Count, then match each group to its number.',
          },
          'pairs': [
            _countToNumber(4, 'ball'),
            _countToNumber(5, 'ball'),
            _countToNumber(6, 'ball'),
          ],
        },
        {
          'kind': 'arithmetic',
          'a': 3,
          'op': '+',
          'b': 2,
          'picture': 'icon:banana',
        },
        {
          'kind': 'arithmetic',
          'a': 5,
          'op': '-',
          'b': 2,
          'picture': 'icon:apple',
        },
      ]),
      _level('hard', 'Hard', 78, options: 4, [
        {
          'kind': 'number_recognition',
          'target': 15,
          'distractors': [12, 18, 51],
        },
        {'kind': 'arithmetic', 'a': 6, 'op': '+', 'b': 3},
        {'kind': 'arithmetic', 'a': 9, 'op': '-', 'b': 4},
        {'kind': 'arithmetic', 'a': 7, 'op': '+', 'b': 5},
        {'kind': 'arithmetic', 'a': 10, 'op': '-', 'b': 7},
      ]),
    ],
  },

  // 5. Alphabet adventure: find letters, big and small, letter sounds, tracing capitals.
  'alphabet-adventure': {
    'intro': {
      'text': 'Alphabet adventure',
      'speak': 'Find letters, match big and small letters, listen to their sounds and trace them.',
    },
    'levels': [
      _level('easy', 'Easy', 0, [
        {'kind': 'letter_recognition', 'target': 'a'},
        {'kind': 'letter_recognition', 'target': 'B', 'mode': 'case'},
        {
          'kind': 'match_pairs',
          'prompt': {
            'text': 'Big and small',
            'speak': 'Match each big letter to its small letter.',
          },
          'pairs': [_case('a'), _case('b')],
        },
        {'kind': 'letter_recognition', 'target': 's', 'mode': 'sound'},
        {'kind': 'trace', 'glyph': 'L'},
      ]),
      _level('medium', 'Medium', 54, [
        {'kind': 'letter_recognition', 'target': 'd'},
        {'kind': 'letter_recognition', 'target': 'g', 'mode': 'case'},
        {
          'kind': 'match_pairs',
          'prompt': {
            'text': 'Big and small',
            'speak': 'Match each big letter to its small letter.',
          },
          'pairs': [_case('e'), _case('h'), _case('m')],
        },
        {'kind': 'letter_recognition', 'target': 'm', 'mode': 'sound'},
        {'kind': 'trace', 'glyph': 'T'},
        {'kind': 'trace', 'glyph': 'E'},
      ]),
      _level('hard', 'Hard', 78, options: 4, [
        {'kind': 'letter_recognition', 'target': 'q'},
        {'kind': 'letter_recognition', 'target': 'N', 'mode': 'case'},
        {
          'kind': 'match_pairs',
          'prompt': {
            'text': 'Big and small',
            'speak': 'Match each big letter to its small letter.',
          },
          'pairs': [_case('d'), _case('q'), _case('n'), _case('r')],
        },
        {'kind': 'letter_recognition', 'target': 'f', 'mode': 'sound'},
        {'kind': 'letter_recognition', 'target': 'p', 'mode': 'sound'},
        {'kind': 'trace', 'glyph': 'M'},
        {'kind': 'trace', 'glyph': 'Z'},
      ]),
    ],
  },

  // 6. Sort it out: by shape, colour, size and kind; wrong drops bounce back straight away.
  'sort-it-out': {
    'intro': {
      'text': 'Sort it out',
      'speak': 'Drag each one to the group where it belongs.',
    },
    'levels': [
      _level('easy', 'Easy', 0, [
        {
          'kind': 'sort',
          'prompt': {
            'text': 'Sort by colour',
            'speak': 'Put the red ones and the blue ones together.',
          },
          'bins': [
            {'id': 'red', 'label': 'Red', 'picture': 'shape:square?color=red'},
            {
              'id': 'blue',
              'label': 'Blue',
              'picture': 'shape:square?color=blue',
            },
          ],
          'items': [
            _sortItem('red-ball', 'icon:ball?color=red', 'red'),
            _sortItem('blue-ball', 'icon:ball?color=blue', 'blue'),
            _sortItem('red-star', 'shape:star?color=red', 'red'),
            _sortItem('blue-heart', 'shape:heart?color=blue', 'blue'),
          ],
        },
        {
          'kind': 'sort',
          'prompt': {
            'text': 'Big or small?',
            'speak': 'Put the big ones and the small ones together.',
          },
          'bins': [
            {
              'id': 'big',
              'label': 'Big',
              'picture': 'shape:circle?size=big&color=green',
            },
            {
              'id': 'small',
              'label': 'Small',
              'picture': 'shape:circle?size=small&color=green',
            },
          ],
          'items': [
            _sortItem('big-apple', 'icon:apple?size=big', 'big'),
            _sortItem('small-apple', 'icon:apple?size=small', 'small'),
            _sortItem('big-star', 'shape:star?size=big', 'big'),
            _sortItem('small-star', 'shape:star?size=small', 'small'),
          ],
        },
      ]),
      _level('medium', 'Medium', 54, [
        {
          'kind': 'sort',
          'prompt': {
            'text': 'Sort by shape',
            'speak':
                'Circles, triangles and squares. Put each shape in its group.',
          },
          'bins': [
            {'id': 'circle', 'label': 'Circles', 'picture': 'shape:circle'},
            {
              'id': 'triangle',
              'label': 'Triangles',
              'picture': 'shape:triangle',
            },
            {'id': 'square', 'label': 'Squares', 'picture': 'shape:square'},
          ],
          'items': [
            _sortItem('c1', 'shape:circle?color=red', 'circle'),
            _sortItem('t1', 'shape:triangle?color=blue', 'triangle'),
            _sortItem('s1', 'shape:square?color=yellow', 'square'),
            _sortItem('c2', 'shape:circle?color=purple&size=small', 'circle'),
            _sortItem(
              't2',
              'shape:triangle?color=green&size=small',
              'triangle',
            ),
            _sortItem('s2', 'shape:square?color=orange&size=medium', 'square'),
          ],
        },
        {
          'kind': 'sort',
          'prompt': {'text': 'Animals or food?'},
          'bins': [
            {'id': 'animals', 'label': 'Animals', 'picture': 'icon:pets'},
            {'id': 'food', 'label': 'Food', 'picture': 'icon:cake'},
          ],
          'items': [
            _sortItem('cow', 'icon:cow', 'animals', 'cow'),
            _sortItem('apple', 'icon:apple', 'food', 'apple'),
            _sortItem('fish', 'icon:fish', 'animals', 'fish'),
            _sortItem('carrot', 'icon:carrot', 'food', 'carrot'),
            _sortItem('duck', 'icon:duck', 'animals', 'duck'),
            _sortItem('banana', 'icon:banana', 'food', 'banana'),
          ],
        },
      ]),
      _level('hard', 'Hard', 78, [
        {
          'kind': 'sort',
          'prompt': {
            'text': 'Sort by colour',
            'speak': 'Red, yellow or green? Sort them all.',
          },
          'bins': [
            {'id': 'red', 'label': 'Red', 'picture': 'shape:square?color=red'},
            {
              'id': 'yellow',
              'label': 'Yellow',
              'picture': 'shape:square?color=yellow',
            },
            {
              'id': 'green',
              'label': 'Green',
              'picture': 'shape:square?color=green',
            },
          ],
          'items': [
            _sortItem('r1', 'icon:apple?color=red', 'red'),
            _sortItem('y1', 'icon:banana?color=yellow', 'yellow'),
            _sortItem('g1', 'icon:tree?color=green', 'green'),
            _sortItem('r2', 'shape:heart?color=red', 'red'),
            _sortItem('y2', 'shape:star?color=yellow', 'yellow'),
            _sortItem('g2', 'icon:flower?color=green', 'green'),
          ],
        },
        {
          'kind': 'sort',
          'prompt': {
            'text': 'Where do they live?',
            'speak': 'On a farm, in the water, or in the sky?',
          },
          'bins': [
            {'id': 'farm', 'label': 'Farm', 'picture': 'icon:house'},
            {'id': 'water', 'label': 'Water', 'picture': 'icon:water'},
            {'id': 'sky', 'label': 'Sky', 'picture': 'icon:sun'},
          ],
          'items': [
            _sortItem('cow', 'icon:cow', 'farm', 'cow'),
            _sortItem('fish', 'icon:fish', 'water', 'fish'),
            _sortItem('bird', 'icon:bird', 'sky', 'bird'),
            _sortItem('dog', 'icon:dog', 'farm', 'dog'),
            _sortItem('boat', 'icon:sailboat', 'water', 'boat'),
          ],
        },
      ]),
    ],
  },

  // 7. Puzzle time: jigsaws that grow (4 → 9 → 16 pieces) and shapes to finish.
  'puzzle-time': {
    'intro': {
      'text': 'Puzzle time',
      'speak': 'Build the pictures and finish the shapes.',
    },
    'levels': [
      _level('easy', 'Easy', 0, [
        {'kind': 'jigsaw', 'picture': 'char:pip', 'grid': 2},
        {
          'kind': 'shape_complete',
          'shape': 'circle',
          'missing': 'right',
          'distractors': ['square', 'triangle'],
        },
        {
          'kind': 'shape_complete',
          'shape': 'heart',
          'missing': 'left',
          'distractors': ['star', 'square'],
        },
      ]),
      _level('medium', 'Medium', 54, [
        {'kind': 'jigsaw', 'picture': 'char:bolt', 'grid': 3},
        {
          'kind': 'shape_complete',
          'shape': 'star',
          'missing': 'right',
          'distractors': ['heart', 'circle', 'triangle'],
        },
        {
          'kind': 'shape_complete',
          'shape': 'triangle',
          'missing': 'top',
          'distractors': ['circle', 'square', 'heart'],
        },
      ]),
      _level('hard', 'Hard', 78, options: 4, [
        {'kind': 'jigsaw', 'picture': 'char:nova', 'grid': 4},
        {'kind': 'puzzle', 'picture': 'char:pip', 'grid': 3},
        {
          'kind': 'shape_complete',
          'shape': 'heart',
          'missing': 'bottom',
          'color': 'purple',
        },
      ]),
    ],
  },

  // 8. Quiz time: read, look and listen; the score shows at the end ("8 of 10 right").
  'quiz-time': {
    'intro': {
      'text': 'Quiz time',
      'speak': 'Answer the questions. Some you read, some you look at, and some you listen to.',
    },
    'levels': [
      _level('easy', 'Easy', 0, [
        {
          'kind': 'image_choice',
          'prompt': {'text': 'Which one can swim?'},
          'options': [_card('fish'), _card('cat'), _card('car')],
          'correct': ['fish'],
          'hint': 'It lives in water.',
        },
        {
          'kind': 'audio_choice',
          'prompt': {'speak': 'Which animal says moo?'},
          'options': [_card('cow'), _card('duck'), _card('dog')],
          'correct': ['cow'],
        },
        {
          'kind': 'multiple_choice',
          'prompt': {
            'text': 'What do we see at night?',
            'picture': 'icon:moon',
          },
          'options': [
            {'id': 'moon', 'label': 'the moon'},
            {'id': 'sun', 'label': 'the sun'},
          ],
          'correct': ['moon'],
        },
      ]),
      _level('medium', 'Medium', 54, [
        {
          'kind': 'image_choice',
          'prompt': {'text': 'Which one grows in the ground?'},
          'options': [
            _card('carrot'),
            _card('cake'),
            _card('ball'),
            _card('bird'),
          ],
          'correct': ['carrot'],
        },
        {
          'kind': 'audio_choice',
          'prompt': {'speak': 'Find the one that can fly.'},
          'options': [_card('bird'), _card('fish'), _card('cow'), _card('dog')],
          'correct': ['bird'],
        },
        {
          'kind': 'multiple_choice',
          'prompt': {
            'text': 'Which ones are fruit?',
            'speak': 'Tap all the fruit, then tap Done.',
          },
          'options': [
            {'id': 'apple', 'label': 'apple', 'picture': 'icon:apple'},
            {'id': 'banana', 'label': 'banana', 'picture': 'icon:banana'},
            {'id': 'car', 'label': 'car', 'picture': 'icon:car'},
          ],
          'correct': ['apple', 'banana'],
        },
        {
          'kind': 'fill_blank',
          'sentence': 'A duck says ___',
          'picture': 'icon:duck',
          'options': ['quack', 'moo', 'woof'],
          'correct': 'quack',
        },
      ]),
      _level('hard', 'Hard', 78, options: 4, [
        {
          'kind': 'multiple_choice',
          'prompt': {'text': 'How many legs does a bird have?'},
          'options': [
            {'id': '2', 'label': 'two'},
            {'id': '4', 'label': 'four'},
            {'id': '6', 'label': 'six'},
          ],
          'correct': ['2'],
        },
        {
          'kind': 'audio_choice',
          'prompt': {'speak': 'Which one shines in the night sky?'},
          'options': [
            {'id': 'moon', 'picture': 'icon:moon', 'label': 'moon'},
            {'id': 'sun', 'picture': 'icon:sun', 'label': 'sun'},
            {'id': 'tree', 'picture': 'icon:tree', 'label': 'tree'},
          ],
          'correct': ['moon'],
        },
        {
          'kind': 'image_choice',
          'prompt': {'text': 'Which is the biggest?'},
          'options': [
            {'id': 'big', 'picture': 'icon:ball?size=big', 'label': 'big ball'},
            {
              'id': 'medium',
              'picture': 'icon:ball?size=medium',
              'label': 'middle ball',
            },
            {
              'id': 'small',
              'picture': 'icon:ball?size=small',
              'label': 'small ball',
            },
          ],
          'correct': ['big'],
        },
        {
          'kind': 'fill_blank',
          'sentence': 'Fish live in ___',
          'picture': 'icon:fish',
          'options': ['water', 'trees', 'cakes'],
          'correct': 'water',
        },
      ]),
    ],
  },
};
