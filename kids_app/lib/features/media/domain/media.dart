/// The multimedia module's rules (videos, songs, stories). Pure Dart, no Flutter: what a launch
/// returns, the song queue, when to resume and when something counts as finished, what a child
/// may see, search, and how a story page is narrated. docs/multimedia/media-architecture.md.
library;

import '../../learning/domain/catalog.dart';
import '../../learning/domain/progress.dart';

// ---------------------------------------------------------------------------------------------
// Launch: the files of one item, with URLs the app can play
// ---------------------------------------------------------------------------------------------

/// One file of an item. [url] is a signed URL (private buckets), a public CDN URL, or
/// `asset:<path>` (development media bundled with the app).
class MediaFile {
  const MediaFile({
    required this.role,
    required this.url,
    required this.kind,
    this.mime = '',
    this.locale = 'und',
    this.position = 0,
    this.durationMs,
    this.width,
    this.height,
    this.text = const LocalizedText({}),
    this.expiresAt,
  });

  factory MediaFile.fromJson(Map<String, dynamic> j) => MediaFile(
    role: j['role'] as String,
    url: j['url'] as String,
    kind: j['kind'] as String? ?? '',
    mime: j['mime'] as String? ?? '',
    locale: j['locale'] as String? ?? 'und',
    position: (j['position'] as num?)?.toInt() ?? 0,
    durationMs: (j['durationMs'] as num?)?.toInt(),
    width: (j['width'] as num?)?.toInt(),
    height: (j['height'] as num?)?.toInt(),
    text: LocalizedText.fromJson(j['text']),
    expiresAt: DateTime.tryParse('${j['expiresAt']}'),
  );

  /// `video_main`, `audio_main`, `subtitle`, `page_image`, `page_audio`, `cover`.
  final String role;
  final String url;

  /// `video_mp4`, `video_hls`, `audio`, `subtitle`, `image`.
  final String kind;
  final String mime;
  final String locale;
  final int position;
  final int? durationMs;
  final int? width;
  final int? height;

  /// Story pages: the words on the page.
  final LocalizedText text;

  /// When a signed URL stops working (null for public and bundled files).
  final DateTime? expiresAt;

  bool get isAsset => url.startsWith('asset:');
  String get assetPath => url.substring('asset:'.length);
}

/// What `POST /play/launch` returns: the files (signed), where the child stopped, time left.
class MediaLaunch {
  const MediaLaunch({
    required this.activityId,
    required this.type,
    required this.files,
    this.section = 'watch',
    this.contentVersion = 1,
    this.resume,
    this.remainingSeconds,
  });

  factory MediaLaunch.fromJson(Map<String, dynamic> j) => MediaLaunch(
    activityId: j['activityId'] as String,
    type: ActivityType.parse(j['type'] as String),
    section: j['section'] as String? ?? 'watch',
    contentVersion: (j['contentVersion'] as num?)?.toInt() ?? 1,
    files: [
      for (final f in (j['assets'] as List?) ?? const [])
        MediaFile.fromJson((f as Map).cast<String, dynamic>()),
    ],
    resume: ResumePoint.fromMetrics(
      j['resume'] as Map?,
      DateTime.tryParse('${(j['resume'] as Map?)?['at']}') ??
          DateTime.utc(2000),
    ),
    remainingSeconds: (j['remainingSeconds'] as num?)?.toInt(),
  );

  final String activityId;
  final ActivityType type;

  /// `watch` or `listen` (what the daily limit counts).
  final String section;
  final int contentVersion;
  final List<MediaFile> files;
  final ResumePoint? resume;

  /// Today's watching / listening time left, when the parent set a limit.
  final int? remainingSeconds;

  MediaFile? _role(String role) =>
      files.where((f) => f.role == role).firstOrNull;

  /// The video to play: MP4 (progressive, streamed in byte ranges). HLS needs the media/hls
  /// route, which isn't built yet, so an HLS-only video is "not available" for now.
  MediaFile? get video => files
      .where((f) => f.role == 'video_main' && f.kind == 'video_mp4')
      .firstOrNull;

  MediaFile? get audio => _role('audio_main');

  /// Captions for [locale], else English, else any.
  MediaFile? captions([String locale = 'en']) {
    final subs = files.where((f) => f.role == 'subtitle').toList();
    return subs.where((f) => f.locale == locale).firstOrNull ??
        subs.where((f) => f.locale == 'en').firstOrNull ??
        subs.firstOrNull;
  }

  /// Story pages in order, each with its picture, words and (if recorded) narration audio.
  List<StoryPage> get pages {
    final images = files.where((f) => f.role == 'page_image').toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final audio = {
      for (final f in files.where((f) => f.role == 'page_audio')) f.position: f,
    };
    return [
      for (final i in images)
        StoryPage(image: i, text: i.text, narration: audio[i.position]),
    ];
  }

  /// Can this app play it? (A video needs an MP4, a song an audio file, a story pages.)
  bool get playable => switch (type) {
    ActivityType.video => video != null,
    ActivityType.song || ActivityType.audiobook => audio != null,
    ActivityType.story => pages.isNotEmpty,
    _ => false,
  };
}

// ---------------------------------------------------------------------------------------------
// Playback
// ---------------------------------------------------------------------------------------------

/// What a player reports, many times a second. The same shape for video and audio.
class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.ready = false,
    this.completed = false,
    this.speed = 1.0,
    this.caption = '',
    this.error,
  });

  final Duration position;
  final Duration duration;

  /// How far the file has loaded (progressive download / streaming).
  final Duration buffered;
  final bool playing;

  /// Waiting for data (slow network).
  final bool buffering;

  /// The file is open and the length known.
  final bool ready;
  final bool completed;
  final double speed;

  /// The caption showing now ('' for none).
  final String caption;

  /// A loading / network error (the player shows "try again").
  final Object? error;

  double get fraction => duration.inMilliseconds <= 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  PlaybackSnapshot copyWith({
    Duration? position,
    Duration? duration,
    Duration? buffered,
    bool? playing,
    bool? buffering,
    bool? ready,
    bool? completed,
    double? speed,
    String? caption,
    Object? error,
    bool clearError = false,
  }) => PlaybackSnapshot(
    position: position ?? this.position,
    duration: duration ?? this.duration,
    buffered: buffered ?? this.buffered,
    playing: playing ?? this.playing,
    buffering: buffering ?? this.buffering,
    ready: ready ?? this.ready,
    completed: completed ?? this.completed,
    speed: speed ?? this.speed,
    caption: caption ?? this.caption,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Speeds offered: videos and story narration. Songs always play at 1×.
const videoSpeeds = [0.75, 1.0, 1.25];

abstract final class MediaRules {
  /// Resume where the child stopped unless that was in the first 5 s or the last 5 % (then the
  /// item starts from the beginning: nearly nothing watched, or practically finished).
  static Duration? resumeAt(ResumePoint? p, {Duration? duration}) {
    final pos = p?.positionMs;
    if (pos == null || pos < 5000) return null;
    final total = duration?.inMilliseconds ?? p?.durationMs;
    if (total != null && total > 0 && pos >= total * 0.95) return null;
    return Duration(milliseconds: pos);
  }

  /// A video or song counts as finished (completed session, daily star) from 95 % or within the
  /// last 2 s — the end credits shouldn't decide a star.
  static bool finished(Duration position, Duration duration) {
    if (duration <= Duration.zero) return false;
    return position.inMilliseconds >= duration.inMilliseconds * 0.95 ||
        duration - position <= const Duration(seconds: 2);
  }

  /// The section of a kind of media.
  static String sectionOf(ActivityType t) =>
      t == ActivityType.video ? 'watch' : 'listen';

  /// What a child may see: right age, section switched on, category not blocked. (Plus items
  /// stay visible with a lock; the server enforces everything again at launch.)
  static bool visible(
    ActivitySummary a, {
    required int ageMonths,
    required SectionSwitches sections,
    required MediaControls controls,
  }) {
    if (!a.suitsAge(ageMonths)) return false;
    if (a.type == ActivityType.video && !sections.watch) return false;
    if (a.isMedia && a.type != ActivityType.video && !sections.listen) {
      return false;
    }
    if (a.categoryId != null &&
        controls.blockedCategoryIds.contains(a.categoryId)) {
      return false;
    }
    return true;
  }

  /// "Continue watching" / "Continue reading": unfinished items, most recent first.
  static List<(ActivitySummary, ResumePoint)> continueList(
    Iterable<ActivitySummary> items,
    Map<String, ResumePoint> positions,
  ) {
    final out = [
      for (final a in items)
        if (positions[a.id] case final p?)
          if (p.page != null || resumeAt(p) != null) (a, p),
    ]..sort((x, y) => y.$2.at.compareTo(x.$2.at));
    return out;
  }

  /// Recommended for this child: suitable items not played recently first, then the rest;
  /// within each, those closest to the child's age band middle first. Stable.
  static List<ActivitySummary> recommended(
    List<ActivitySummary> items, {
    required int ageMonths,
    required Set<String> recentlyPlayed,
    int limit = 8,
  }) {
    int distance(ActivitySummary a) =>
        ((a.ageMinMonths + a.ageMaxMonths) ~/ 2 - ageMonths).abs();
    final indexed = items.indexed.toList()
      ..sort((x, y) {
        final px = recentlyPlayed.contains(x.$2.id) ? 1 : 0;
        final py = recentlyPlayed.contains(y.$2.id) ? 1 : 0;
        if (px != py) return px - py;
        final d = distance(x.$2) - distance(y.$2);
        return d != 0 ? d : x.$1 - y.$1;
      });
    return indexed.map((e) => e.$2).take(limit).toList();
  }
}

/// Search and filters for the libraries (all on the device: the catalogue is small).
class MediaFilter {
  const MediaFilter({
    this.query = '',
    this.subjectId,
    this.categoryId,
    this.maxMinutes,
  });

  final String query;
  final String? subjectId;
  final String? categoryId;

  /// Short ones only (e.g. ≤ 1 minute).
  final int? maxMinutes;

  bool get isEmpty =>
      query.trim().isEmpty &&
      subjectId == null &&
      categoryId == null &&
      maxMinutes == null;

  MediaFilter copyWith({
    String? query,
    String? subjectId,
    String? categoryId,
    int? maxMinutes,
    bool clearSubject = false,
    bool clearCategory = false,
    bool clearLength = false,
  }) => MediaFilter(
    query: query ?? this.query,
    subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    maxMinutes: clearLength ? null : (maxMinutes ?? this.maxMinutes),
  );

  /// Every word of the query must start a word of the title or description (any order,
  /// any case): "rain why" finds "Why does it rain?".
  bool matches(ActivitySummary a, {String? subjectName, String? categoryName}) {
    if (subjectId != null && a.subjectId != subjectId) return false;
    if (categoryId != null && a.categoryId != categoryId) return false;
    if (maxMinutes != null && (a.minutes ?? 999) > maxMinutes!) return false;
    final words = _words(query);
    if (words.isEmpty) return true;
    final hay = _words(
      '${a.title.of()} ${a.description.of()} ${subjectName ?? ''} ${categoryName ?? ''}',
    );
    return words.every((w) => hay.any((h) => h.startsWith(w)));
  }

  static List<String> _words(String s) => s
      .toLowerCase()
      .split(RegExp(r"[^a-z0-9áéíóúñü']+"))
      .where((w) => w.isNotEmpty)
      .toList();
}

// ---------------------------------------------------------------------------------------------
// Songs: the queue
// ---------------------------------------------------------------------------------------------

enum SongRepeat { off, all, one }

/// The song list being played: order (shuffled or not), the current song, repeat. Pure: every
/// action returns a new queue.
class SongQueue {
  const SongQueue._(
    this.ids,
    this.order,
    this.index,
    this.repeat,
    this.shuffle,
    this.seed,
  );

  factory SongQueue(List<String> ids, {String? start, int seed = 1}) =>
      SongQueue._(
        List.unmodifiable(ids),
        List.unmodifiable([for (var k = 0; k < ids.length; k++) k]),
        start == null ? 0 : ids.indexOf(start).clamp(0, ids.length - 1),
        SongRepeat.off,
        false,
        seed,
      );

  /// The songs in library order.
  final List<String> ids;

  /// Play order (indexes into [ids]); a permutation when shuffled.
  final List<int> order;

  /// Position in [order].
  final int index;
  final SongRepeat repeat;
  final bool shuffle;

  /// Seeds the next shuffle (deterministic, so tests and resumes are repeatable).
  final int seed;

  String get current => ids[order[index]];
  bool get isEmpty => ids.isEmpty;
  bool get hasNext => repeat != SongRepeat.off || index < order.length - 1;
  bool get hasPrevious => index > 0 || repeat == SongRepeat.all;

  SongQueue _copy({
    List<int>? order,
    int? index,
    SongRepeat? repeat,
    bool? shuffle,
    int? seed,
  }) => SongQueue._(
    ids,
    order ?? this.order,
    index ?? this.index,
    repeat ?? this.repeat,
    shuffle ?? this.shuffle,
    seed ?? this.seed,
  );

  /// "Next": the following song (wraps round with repeat all; repeat one still moves on when
  /// the child asks). Null at the end of the list without repeat.
  SongQueue? next() {
    if (index < order.length - 1) return _copy(index: index + 1);
    if (repeat == SongRepeat.off) return null;
    return _copy(index: 0);
  }

  /// "Previous": restarts the current song if it has played more than 3 s (like every music
  /// player), else goes back one. Returns (queue, restart?).
  (SongQueue, bool restart) previous(Duration position) {
    if (position > const Duration(seconds: 3) || !hasPrevious) {
      return (this, true);
    }
    return (_copy(index: index > 0 ? index - 1 : order.length - 1), false);
  }

  /// A song ended on its own: repeat one → same; else next (or stop at the end).
  SongQueue? afterCompletion() => repeat == SongRepeat.one ? this : next();

  SongQueue cycleRepeat() => _copy(
    repeat: SongRepeat.values[(repeat.index + 1) % SongRepeat.values.length],
  );

  /// Shuffle on: a new random order with the current song first. Off: library order, same song.
  SongQueue toggleShuffle() {
    final cur = order[index];
    if (shuffle) {
      return _copy(
        order: [for (var k = 0; k < ids.length; k++) k],
        index: cur,
        shuffle: false,
      );
    }
    final rest = [
      for (var k = 0; k < ids.length; k++)
        if (k != cur) k,
    ];
    var s = (seed * 7919 + ids.length) & 0x7fffffff;
    for (var i = rest.length - 1; i > 0; i--) {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      final j = s % (i + 1);
      final t = rest[i];
      rest[i] = rest[j];
      rest[j] = t;
    }
    return _copy(order: [cur, ...rest], index: 0, shuffle: true, seed: s);
  }

  /// Jump to a song in the list.
  SongQueue select(String id) {
    final k = ids.indexOf(id);
    if (k < 0) return this;
    return _copy(index: order.indexOf(k));
  }
}

// ---------------------------------------------------------------------------------------------
// Stories
// ---------------------------------------------------------------------------------------------

class StoryPage {
  const StoryPage({required this.image, required this.text, this.narration});

  final MediaFile image;
  final LocalizedText text;

  /// Recorded narration for this page, when there is one; else the device voice reads [text].
  final MediaFile? narration;

  /// The page's sentences, read (and highlighted) one at a time.
  List<String> sentences([String locale = 'en']) =>
      splitSentences(text.of(locale));
}

/// Splits story text into sentences, keeping quotes with their sentence:
/// `"Goodnight!" she sang. The end.` → [`"Goodnight!" she sang.`, `The end.`].
List<String> splitSentences(String text) {
  final out = <String>[];
  final buf = StringBuffer();
  final chars = text.trim().split('');
  for (var i = 0; i < chars.length; i++) {
    buf.write(chars[i]);
    final end = '.!?…'.contains(chars[i]);
    if (!end) continue;
    // swallow closing quotes / more stops
    while (i + 1 < chars.length && '"\'”’.!?…'.contains(chars[i + 1])) {
      buf.write(chars[++i]);
    }
    final rest = chars.skip(i + 1).join().trimLeft();
    // a quote ending in "!" or "?" followed by a lower-case word continues the sentence
    if (rest.isNotEmpty &&
        RegExp(r'^[a-z]').hasMatch(rest) &&
        buf.toString().trimRight().endsWith('"')) {
      continue;
    }
    if (buf.toString().trim().isNotEmpty) out.add(buf.toString().trim());
    buf.clear();
  }
  if (buf.toString().trim().isNotEmpty) out.add(buf.toString().trim());
  return out;
}

/// Reading progress: the furthest page reached and whether the story is finished.
abstract final class StoryRules {
  /// Finished once the last page has been shown (read aloud or not).
  static bool finished(int page, int pages) => pages > 0 && page >= pages - 1;

  /// Where to open: the saved page if the story wasn't finished, else the cover page.
  static int startPage(ResumePoint? p, int pages) {
    final page = p?.page;
    if (page == null || pages == 0) return 0;
    if (page >= pages - 1) return 0;
    return page.clamp(0, pages - 1);
  }
}
