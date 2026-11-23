/// Child profile entities and the rules the app checks before the server does.
/// Pure Dart. The server is the authority: these checks mirror private.parse_birth_year_month
/// and the child_profiles constraints so the parent gets an answer before a round trip.
library;

/// Birth month and year only: the platform never stores a day (data minimisation,
/// docs/architecture/14-security-and-child-privacy.md).
class BirthYearMonth implements Comparable<BirthYearMonth> {
  const BirthYearMonth(this.year, this.month)
    : assert(month >= 1 && month <= 12);

  final int year;
  final int month;

  /// Parses `YYYY-MM` or a date `YYYY-MM-DD` (the column type) and drops the day.
  static BirthYearMonth? tryParse(String? value) {
    final m = RegExp(r'^(\d{4})-(\d{2})').firstMatch(value ?? '');
    if (m == null) return null;
    final month = int.parse(m.group(2)!);
    if (month < 1 || month > 12) return null;
    return BirthYearMonth(int.parse(m.group(1)!), month);
  }

  /// `YYYY-MM`, the API format.
  String get iso =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  int get _index => year * 12 + (month - 1);

  /// Whole years of age in [now]'s month (month precision, like the server).
  int ageInYears(DateTime now) =>
      ((now.year * 12 + now.month - 1) - _index) ~/ 12;

  /// Same window as the server: at least 12 months ago, at most 13 years ago.
  BirthYearMonthProblem? validate(DateTime now) {
    final nowIndex = now.year * 12 + now.month - 1;
    if (_index > nowIndex - 12) return BirthYearMonthProblem.tooYoung;
    if (_index < nowIndex - 13 * 12) return BirthYearMonthProblem.tooOld;
    return null;
  }

  @override
  int compareTo(BirthYearMonth other) => _index.compareTo(other._index);

  @override
  bool operator ==(Object other) =>
      other is BirthYearMonth && other._index == _index;

  @override
  int get hashCode => _index;

  @override
  String toString() => iso;
}

enum BirthYearMonthProblem {
  tooYoung('Children need to be at least one year old to play.'),
  tooOld('This app is for children up to 12.');

  const BirthYearMonthProblem(this.message);
  final String message;
}

const nicknameMaxLength = 20;

enum NicknameProblem {
  empty("Add your child's first name or a nickname."),
  tooLong('Use $nicknameMaxLength characters or fewer.'),
  looksLikeContact(
    "Just a first name or nickname, please: no email addresses or numbers.",
  );

  const NicknameProblem(this.message);
  final String message;
}

/// Trims and checks a nickname. Counts characters the way Postgres `char_length` does.
NicknameProblem? validateNickname(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return NicknameProblem.empty;
  if (v.runes.length > nicknameMaxLength) return NicknameProblem.tooLong;
  // Minimise personal data: no contact details in the one free-text field we keep.
  if (v.contains('@') || RegExp(r'\d{4,}').hasMatch(v)) {
    return NicknameProblem.looksLikeContact;
  }
  return null;
}

/// Learning stage shown to the parent, from age (the server uses the same bands when
/// `learning_stage` is `auto`).
enum LearningStage {
  toddler('Tiny explorer'),
  preschool('Little explorer'),
  kindergarten('Big explorer'),
  grade1('Star learner'),
  grade2('Super learner');

  const LearningStage(this.label);
  final String label;

  static LearningStage forAge(int years) => switch (years) {
    <= 3 => LearningStage.toddler,
    4 => LearningStage.preschool,
    5 => LearningStage.kindergarten,
    6 => LearningStage.grade1,
    _ => LearningStage.grade2,
  };
}

/// What a parent fills in for a child: the same fields for creating and editing.
class ChildDetails {
  const ChildDetails({
    required this.nickname,
    required this.birthYearMonth,
    this.avatarId,
  });

  final String nickname;
  final BirthYearMonth birthYearMonth;
  final String? avatarId;

  Map<String, Object?> toJson() => {
    'nickname': nickname.trim(),
    'birthYearMonth': birthYearMonth.iso,
    'avatarId': avatarId,
  };
}

class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.nickname,
    required this.birthYearMonth,
    this.avatarId,
    this.sort = 0,
  });

  final String id;
  final String nickname;
  final BirthYearMonth birthYearMonth;
  final String? avatarId;
  final int sort;

  ChildDetails get details => ChildDetails(
    nickname: nickname,
    birthYearMonth: birthYearMonth,
    avatarId: avatarId,
  );

  ChildProfile withDetails(ChildDetails d) => ChildProfile(
    id: id,
    nickname: d.nickname.trim(),
    birthYearMonth: d.birthYearMonth,
    avatarId: d.avatarId,
    sort: sort,
  );
}

/// A buddy from the `avatars` table. [artIndex] picks the drawn placeholder art until the
/// commissioned images exist (key `buddy-01` → art 0).
class Avatar {
  const Avatar({required this.id, required this.key, required this.sort});

  final String id;
  final String key;
  final int sort;

  int get artIndex {
    final n = int.tryParse(RegExp(r'(\d+)$').firstMatch(key)?.group(1) ?? '');
    return ((n ?? sort + 1) - 1).clamp(0, 1 << 20);
  }
}
