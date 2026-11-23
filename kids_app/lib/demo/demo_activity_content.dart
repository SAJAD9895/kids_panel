/// Engine content for development: `games.config` of a few seed activities, plus "Try
/// everything" with one item of every activity type. Mirrored exactly in supabase/seed.sql §14;
/// test/unit/seed_content_test.dart fails if the two differ. Small on purpose: real content
/// comes from the admin CMS.
library;

const demoActivityContent = <String, Map<String, Object?>>{
  'find-the-b': {
    'intro': {
      'text': 'Find the letter',
      'speak': 'Listen, then tap the letter you hear.',
    },
    'items': [
      {'kind': 'letter_recognition', 'target': 'b'},
      {'kind': 'letter_recognition', 'target': 'd'},
      {'kind': 'letter_recognition', 'target': 'p'},
    ],
  },
  'count-the-boats': {
    'intro': {
      'text': 'Count with me',
      'speak': 'Count the boats, then tap the number.',
    },
    'items': [
      {'kind': 'number_recognition', 'count': 3, 'picture': 'icon:sailboat'},
      {'kind': 'number_recognition', 'count': 5, 'picture': 'icon:sailboat'},
      {'kind': 'number_recognition', 'count': 4, 'picture': 'icon:sailboat'},
    ],
  },
  'trace-a-to-h': {
    'intro': {
      'text': 'Trace the letters',
      'speak': 'Use your finger to trace each letter.',
    },
    'items': [
      {'kind': 'trace', 'glyph': 'a'},
      {'kind': 'trace', 'glyph': 'b'},
      {'kind': 'trace', 'glyph': 'c'},
    ],
  },
  'number-trace-1-5': {
    'intro': {
      'text': 'Trace the numbers',
      'speak': 'Trace each number with your finger.',
    },
    'items': [
      {'kind': 'trace', 'glyph': '1'},
      {'kind': 'trace', 'glyph': '2'},
      {'kind': 'trace', 'glyph': '3'},
    ],
  },
  'shape-homes': {
    'intro': {'text': 'Shape homes', 'speak': 'Help each shape find its home.'},
    'items': [
      {
        'kind': 'drag_to_target',
        'prompt': {
          'text': 'Take each shape home',
          'speak': 'Drag each shape to the home with the same shape.',
        },
        'tokens': [
          {'id': 'circle', 'picture': 'shape:circle'},
          {'id': 'square', 'picture': 'shape:square'},
          {'id': 'triangle', 'picture': 'shape:triangle'},
        ],
        'targets': [
          {'id': 'home-circle', 'picture': 'shape:circle', 'label': 'circle'},
          {'id': 'home-square', 'picture': 'shape:square', 'label': 'square'},
          {
            'id': 'home-triangle',
            'picture': 'shape:triangle',
            'label': 'triangle',
          },
        ],
        'solution': {
          'circle': 'home-circle',
          'square': 'home-square',
          'triangle': 'home-triangle',
        },
      },
    ],
  },
  'shape-sort': {
    'intro': {
      'text': 'Shape sort',
      'speak': 'Is it round, or does it have corners?',
    },
    'items': [
      {
        'kind': 'sort',
        'prompt': {
          'text': 'Round or corners?',
          'speak': 'Put the round things on one side and the things with corners on the other.',
        },
        'bins': [
          {'id': 'round', 'label': 'Round', 'picture': 'shape:circle'},
          {'id': 'corners', 'label': 'Corners', 'picture': 'shape:square'},
        ],
        'items': [
          {
            'id': 'ball',
            'picture': 'icon:ball',
            'label': 'ball',
            'bin': 'round',
          },
          {'id': 'sun', 'picture': 'icon:sun', 'label': 'sun', 'bin': 'round'},
          {
            'id': 'house',
            'picture': 'icon:house',
            'label': 'house',
            'bin': 'corners',
          },
          {
            'id': 'star',
            'picture': 'shape:star',
            'label': 'star',
            'bin': 'corners',
          },
        ],
      },
    ],
  },
  'more-or-less': {
    'intro': {
      'text': 'More or less?',
      'speak': 'Look at the baskets. Which has more?',
    },
    'items': [
      {
        'kind': 'image_choice',
        'prompt': {
          'text': 'Which has more?',
          'speak': 'Which basket has more apples?',
        },
        'options': [
          {'id': 'three', 'picture': 'count:3:apple', 'label': 'three apples'},
          {'id': 'five', 'picture': 'count:5:apple', 'label': 'five apples'},
        ],
        'correct': ['five'],
      },
      {
        'kind': 'image_choice',
        'prompt': {
          'text': 'Which has less?',
          'speak': 'Which basket has fewer carrots?',
        },
        'options': [
          {'id': 'two', 'picture': 'count:2:carrot', 'label': 'two carrots'},
          {'id': 'six', 'picture': 'count:6:carrot', 'label': 'six carrots'},
        ],
        'correct': ['two'],
      },
    ],
  },
  'engine-sampler': {
    'intro': {
      'text': 'Try everything!',
      'speak': 'Here is one of every kind of game. Ready?',
    },
    'items': [
      {
        'kind': 'multiple_choice',
        'prompt': {'text': 'Which one is a fruit?'},
        'options': [
          {'id': 'banana', 'label': 'banana'},
          {'id': 'car', 'label': 'car'},
          {'id': 'shoe', 'label': 'shoe'},
        ],
        'correct': ['banana'],
        'hint': 'You can eat it!',
      },
      {
        'kind': 'image_choice',
        'prompt': {'text': 'Which one can fly?', 'picture': 'icon:tree'},
        'options': [
          {'id': 'bird', 'picture': 'icon:bird', 'label': 'bird'},
          {'id': 'fish', 'picture': 'icon:fish', 'label': 'fish'},
          {'id': 'cow', 'picture': 'icon:cow', 'label': 'cow'},
        ],
        'correct': ['bird'],
      },
      {
        'kind': 'audio_choice',
        'prompt': {'speak': 'Find the cat.'},
        'options': [
          {'id': 'cat', 'picture': 'icon:cat', 'label': 'cat'},
          {'id': 'dog', 'picture': 'icon:dog', 'label': 'dog'},
          {'id': 'duck', 'picture': 'icon:duck', 'label': 'duck'},
        ],
        'correct': ['cat'],
      },
      {'kind': 'letter_recognition', 'target': 'm'},
      {
        'kind': 'number_recognition',
        'target': 7,
        'distractors': [1, 4, 9],
      },
      {
        'kind': 'drag_to_target',
        'prompt': {'text': 'Who lives where?'},
        'tokens': [
          {'id': 'fish', 'picture': 'icon:fish', 'label': 'fish'},
          {'id': 'bird', 'picture': 'icon:bird', 'label': 'bird'},
        ],
        'targets': [
          {'id': 'water', 'label': 'water', 'picture': 'icon:water'},
          {'id': 'tree', 'label': 'tree', 'picture': 'icon:tree'},
        ],
        'solution': {'fish': 'water', 'bird': 'tree'},
      },
      {
        'kind': 'sort',
        'prompt': {'text': 'Animals or food?'},
        'bins': [
          {'id': 'animals', 'label': 'Animals', 'picture': 'icon:pets'},
          {'id': 'food', 'label': 'Food', 'picture': 'icon:cake'},
        ],
        'items': [
          {
            'id': 'cow',
            'picture': 'icon:cow',
            'label': 'cow',
            'bin': 'animals',
          },
          {
            'id': 'apple',
            'picture': 'icon:apple',
            'label': 'apple',
            'bin': 'food',
          },
          {
            'id': 'duck',
            'picture': 'icon:duck',
            'label': 'duck',
            'bin': 'animals',
          },
        ],
      },
      {
        'kind': 'match_pairs',
        'prompt': {'text': 'Match the word to the picture'},
        'pairs': [
          {
            'left': {'label': 'cat'},
            'right': {'picture': 'icon:cat', 'label': 'cat'},
          },
          {
            'left': {'label': 'sun'},
            'right': {'picture': 'icon:sun', 'label': 'sun'},
          },
          {
            'left': {'label': 'car'},
            'right': {'picture': 'icon:car', 'label': 'car'},
          },
        ],
      },
      {
        'kind': 'fill_blank',
        'sentence': 'The cow says ___',
        'picture': 'icon:cow',
        'options': [
          {'id': 'moo', 'label': 'moo'},
          {'id': 'quack', 'label': 'quack'},
          {'id': 'woof', 'label': 'woof'},
        ],
        'correct': 'moo',
      },
      {'kind': 'word_build', 'word': 'cat', 'picture': 'icon:cat'},
      {
        'kind': 'memory',
        'cards': [
          {'id': 'sun', 'picture': 'icon:sun', 'label': 'sun'},
          {'id': 'moon', 'picture': 'icon:moon', 'label': 'moon'},
          {'id': 'star', 'picture': 'shape:star', 'label': 'star'},
        ],
      },
      {'kind': 'puzzle', 'picture': 'char:pip', 'grid': 2},
      {'kind': 'trace', 'glyph': 'o'},
      // Phase 10 types
      {
        'kind': 'arithmetic',
        'a': 2,
        'op': '+',
        'b': 1,
        'picture': 'icon:apple',
      },
      {
        'kind': 'shape_complete',
        'shape': 'circle',
        'missing': 'right',
        'distractors': ['square', 'triangle'],
      },
      {'kind': 'jigsaw', 'picture': 'char:pip', 'grid': 2},
    ],
  },
};
