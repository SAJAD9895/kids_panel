import 'package:flutter_test/flutter_test.dart';
import 'package:kids_app/features/child_profiles/domain/child_profile.dart';

void main() {
  final now = DateTime(2026, 11, 18);

  group('BirthYearMonth', () {
    test('parses YYYY-MM and a date column, drops the day', () {
      expect(BirthYearMonth.tryParse('2022-03'), const BirthYearMonth(2022, 3));
      expect(
        BirthYearMonth.tryParse('2022-03-01'),
        const BirthYearMonth(2022, 3),
      );
      expect(BirthYearMonth.tryParse('2022-13'), isNull);
      expect(BirthYearMonth.tryParse('March 2022'), isNull);
      expect(const BirthYearMonth(2021, 4).iso, '2021-04');
    });

    test('age is whole years at month precision', () {
      expect(const BirthYearMonth(2022, 11).ageInYears(now), 4);
      expect(const BirthYearMonth(2022, 12).ageInYears(now), 3);
    });

    test('same window as private.parse_birth_year_month (1 to 12 years)', () {
      expect(
        const BirthYearMonth(2025, 11).validate(now),
        isNull,
      ); // exactly 12 months
      expect(
        const BirthYearMonth(2025, 12).validate(now),
        BirthYearMonthProblem.tooYoung,
      );
      expect(
        const BirthYearMonth(2026, 11).validate(now),
        BirthYearMonthProblem.tooYoung,
      );
      expect(
        const BirthYearMonth(2013, 11).validate(now),
        isNull,
      ); // exactly 13 years
      expect(
        const BirthYearMonth(2013, 10).validate(now),
        BirthYearMonthProblem.tooOld,
      );
      expect(
        const BirthYearMonth(1990, 1).validate(now),
        BirthYearMonthProblem.tooOld,
      );
    });
  });

  group('validateNickname', () {
    test('accepts a first name, trims it', () {
      expect(validateNickname('  Mia '), isNull);
      expect(validateNickname('Zoë'), isNull);
    });
    test('rejects empty, too long and contact details', () {
      expect(validateNickname('   '), NicknameProblem.empty);
      expect(validateNickname('a' * 21), NicknameProblem.tooLong);
      expect(
        validateNickname('😀' * 20),
        isNull,
        reason: 'counts characters, not UTF-16 units',
      );
      expect(
        validateNickname('mia@example.com'),
        NicknameProblem.looksLikeContact,
      );
      expect(validateNickname('Mia 5551234'), NicknameProblem.looksLikeContact);
    });
  });

  test('learning stage by age', () {
    expect(LearningStage.forAge(2), LearningStage.toddler);
    expect(LearningStage.forAge(4), LearningStage.preschool);
    expect(LearningStage.forAge(4).label, 'Little explorer');
    expect(LearningStage.forAge(9), LearningStage.grade2);
  });

  test('avatar art index comes from the key', () {
    expect(const Avatar(id: 'a', key: 'buddy-04', sort: 9).artIndex, 3);
    expect(const Avatar(id: 'a', key: 'fox', sort: 2).artIndex, 2);
  });

  test('ChildDetails JSON carries no ids but the avatar', () {
    final json = const ChildDetails(
      nickname: ' Kai ',
      birthYearMonth: BirthYearMonth(2021, 5),
    ).toJson();
    expect(json, {
      'nickname': 'Kai',
      'birthYearMonth': '2021-05',
      'avatarId': null,
    });
  });
}
