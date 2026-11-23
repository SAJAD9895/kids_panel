/// The development media library's catalogue facts: which activity each generated file belongs
/// to, its category, ages and Plus flag. The files themselves are in demo_media.g.dart (made by
/// content/dev-media/make_dev_media.py). Seed §16 is generated from both by
/// `dart run tool/seed_content_sql.dart --write`, so demo mode and the database agree.
library;

import 'demo_media.g.dart';

class DemoMediaCategory {
  const DemoMediaCategory(this.key, this.name, this.sort, {this.isNew = false});

  final String key;
  final String name;
  final int sort;

  /// Not in the hand-written seed yet (§4 has animals, garden, space, bedtime).
  final bool isNew;
}

const demoMediaCategories = <DemoMediaCategory>[
  DemoMediaCategory('animals', 'Animals', 1),
  DemoMediaCategory('garden', 'Garden', 2),
  DemoMediaCategory('space', 'Space', 3),
  DemoMediaCategory('bedtime', 'Bedtime', 4),
  DemoMediaCategory('weather', 'Weather', 5, isNew: true),
  DemoMediaCategory('colours-and-shapes', 'Colour fun', 6, isNew: true),
  DemoMediaCategory('music-time', 'Music time', 7, isNew: true),
  DemoMediaCategory('feelings', 'Calm and kind', 8, isNew: true),
];

class DemoMediaItem {
  const DemoMediaItem({
    required this.slug,
    required this.type,
    required this.title,
    required this.description,
    required this.subject,
    required this.category,
    required this.ageMin,
    required this.ageMax,
    this.plus = false,
    this.isNew = false,
    this.keywords = '',
  });

  final String slug;

  /// `video`, `song` or `story`.
  final String type;
  final String title;
  final String description;
  final String subject;
  final String category;
  final int ageMin;
  final int ageMax;
  final bool plus;

  /// Not in the hand-written seed (§6 / §13): inserted by §16.
  final bool isNew;
  final String keywords;

  /// The real length of the media (the video or song file; stories ≈ 12 s a page read aloud).
  int get seconds {
    final pages = devStoryText[slug]?.length;
    if (pages != null) return pages * 12;
    final main = files
        .where((f) => f.$1 == 'video_main' || f.$1 == 'audio_main')
        .firstOrNull;
    return ((main?.$2.durationMs ?? 60000) / 1000).ceil();
  }

  /// Files of this item, by role (`video_main`, `subtitle`, `audio_main`, `page_image`, `thumb`).
  List<(String role, DevMediaFile file)> get files => [
    for (final f in devMediaFiles)
      if (f.path.contains('/$slug/') || f.path.startsWith('$slug/'))
        (
          switch (f.kind) {
            'video_mp4' => 'video_main',
            'subtitle' => 'subtitle',
            'audio' => 'audio_main',
            _ when f.path.contains('/pages/') => 'page_image',
            _ => 'thumb',
          },
          f,
        ),
  ];

  /// The 512 px thumbnail's path in public-assets.
  String get thumbnail => 'thumbs/$slug/1/512.webp';
}

const demoMediaItems = <DemoMediaItem>[
  // videos
  DemoMediaItem(
    slug: 'pip-meets-a-snail',
    type: 'video',
    title: 'Pip meets a snail',
    description: 'A slow, friendly visitor in the garden',
    subject: 'nature',
    category: 'garden',
    ageMin: 24,
    ageMax: 84,
  ),
  DemoMediaItem(
    slug: 'numbers-on-the-farm',
    type: 'video',
    title: 'Numbers on the farm',
    description: 'Count the sheep with Bolt',
    subject: 'numbers',
    category: 'animals',
    ageMin: 24,
    ageMax: 72,
  ),
  DemoMediaItem(
    slug: 'why-does-it-rain',
    type: 'video',
    title: 'Why does it rain?',
    description: 'Nova follows a raindrop',
    subject: 'science',
    category: 'weather',
    ageMin: 36,
    ageMax: 96,
    plus: true,
  ),
  DemoMediaItem(
    slug: 'shapes-all-around',
    type: 'video',
    title: 'Shapes all around',
    description: 'Circles, squares, triangles, stars and hearts',
    subject: 'shapes',
    category: 'colours-and-shapes',
    ageMin: 24,
    ageMax: 72,
    isNew: true,
    keywords: 'shapes circle square triangle',
  ),
  DemoMediaItem(
    slug: 'rainbow-colours',
    type: 'video',
    title: 'Rainbow colours',
    description: 'Six colours make a rainbow',
    subject: 'art',
    category: 'colours-and-shapes',
    ageMin: 24,
    ageMax: 72,
    isNew: true,
    keywords: 'colours rainbow',
  ),
  // songs
  DemoMediaItem(
    slug: 'counting-train',
    type: 'song',
    title: 'The counting train',
    description: 'All aboard: one, two, three, four!',
    subject: 'music',
    category: 'music-time',
    ageMin: 24,
    ageMax: 84,
  ),
  DemoMediaItem(
    slug: 'ten-little-seeds',
    type: 'song',
    title: 'Ten little seeds',
    description: 'Grow and count to ten',
    subject: 'numbers',
    category: 'garden',
    ageMin: 24,
    ageMax: 72,
  ),
  DemoMediaItem(
    slug: 'feelings-song',
    type: 'song',
    title: 'How do you feel?',
    description: 'Happy, sleepy, cross and calm',
    subject: 'feelings',
    category: 'feelings',
    ageMin: 24,
    ageMax: 84,
  ),
  DemoMediaItem(
    slug: 'tidy-up-tune',
    type: 'song',
    title: 'Tidy-up tune',
    description: 'A bouncy tune for tidying toys',
    subject: 'health',
    category: 'music-time',
    ageMin: 24,
    ageMax: 84,
    isNew: true,
    keywords: 'tidy song',
  ),
  DemoMediaItem(
    slug: 'moon-lullaby',
    type: 'song',
    title: 'Moon lullaby',
    description: 'A soft tune for sleepy time',
    subject: 'music',
    category: 'bedtime',
    ageMin: 24,
    ageMax: 96,
    isNew: true,
    keywords: 'lullaby bedtime moon',
  ),
  // stories
  DemoMediaItem(
    slug: 'the-sleepy-cloud',
    type: 'story',
    title: 'The sleepy cloud',
    description: 'A little cloud looks for a place to rest',
    subject: 'feelings',
    category: 'bedtime',
    ageMin: 24,
    ageMax: 84,
    plus: true,
  ),
  DemoMediaItem(
    slug: 'calm-breathing',
    type: 'story',
    title: 'Bolt takes a breath',
    description: 'A calm story about big feelings',
    subject: 'feelings',
    category: 'feelings',
    ageMin: 36,
    ageMax: 96,
    plus: true,
  ),
  DemoMediaItem(
    slug: 'pip-and-the-lost-seed',
    type: 'story',
    title: 'Pip and the lost seed',
    description: 'Where did the wind take Pip\'s seed?',
    subject: 'nature',
    category: 'garden',
    ageMin: 24,
    ageMax: 84,
    isNew: true,
    keywords: 'story seed garden',
  ),
  DemoMediaItem(
    slug: 'nova-counts-the-stars',
    type: 'story',
    title: 'Nova counts the stars',
    description: 'Count to ten under the night sky',
    subject: 'numbers',
    category: 'space',
    ageMin: 24,
    ageMax: 84,
    isNew: true,
    keywords: 'story stars counting night',
  ),
];

/// Watch and Listen rows (collections).
const demoMediaRows =
    <
      (
        String slug,
        String surface,
        String kind,
        String title,
        List<String> items,
      )
    >[
      (
        'featured-videos',
        'watch',
        'drop',
        'Featured',
        ['shapes-all-around', 'pip-meets-a-snail'],
      ),
      (
        'shows',
        'watch',
        'row',
        'Shows',
        [
          'pip-meets-a-snail',
          'numbers-on-the-farm',
          'why-does-it-rain',
          'shapes-all-around',
          'rainbow-colours',
        ],
      ),
      (
        'featured-listen',
        'listen',
        'drop',
        'Featured',
        ['moon-lullaby', 'pip-and-the-lost-seed'],
      ),
      (
        'songs',
        'listen',
        'row',
        'Songs',
        [
          'counting-train',
          'ten-little-seeds',
          'feelings-song',
          'tidy-up-tune',
          'moon-lullaby',
        ],
      ),
      (
        'stories',
        'listen',
        'row',
        'Stories',
        [
          'pip-and-the-lost-seed',
          'nova-counts-the-stars',
          'the-sleepy-cloud',
          'calm-breathing',
        ],
      ),
      (
        'bedtime-stories',
        'listen',
        'row',
        'Bedtime stories',
        ['the-sleepy-cloud', 'moon-lullaby', 'calm-breathing'],
      ),
    ];
