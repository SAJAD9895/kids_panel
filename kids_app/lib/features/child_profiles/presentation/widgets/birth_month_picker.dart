import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../domain/child_profile.dart';

const monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const monthNamesLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Born Mar 2022"
String formatBirth(BirthYearMonth b) => '${monthNames[b.month - 1]} ${b.year}';

/// Month chips (2 rows of 6) and year chips (K05). Only a month and a year: never a day.
class BirthMonthPicker extends StatelessWidget {
  const BirthMonthPicker({
    super.key,
    required this.month,
    required this.year,
    required this.years,
    required this.onMonth,
    required this.onYear,
  });

  final int? month;
  final int? year;
  final List<int> years;
  final ValueChanged<int> onMonth;
  final ValueChanged<int> onYear;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LayoutBuilder(
        builder: (context, c) {
          final perRow = c.maxWidth >= Sizes.uiFormW ? 6 : 4;
          final w = (c.maxWidth - Space.s4 * (perRow - 1)) / perRow;
          return Semantics(
            label: 'Birth month',
            container: true,
            child: Wrap(
              spacing: Space.s4,
              runSpacing: Space.s4,
              children: [
                for (var m = 1; m <= 12; m++)
                  SizedBox(
                    width: w,
                    child: PillChoice(
                      label: monthNames[m - 1],
                      semanticLabel: monthNamesLong[m - 1],
                      selected: month == m,
                      onSelected: () => onMonth(m),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: Space.s5),
      Semantics(
        label: 'Birth year',
        container: true,
        child: Wrap(
          spacing: Space.s4,
          runSpacing: Space.s4,
          children: [
            for (final y in years)
              PillChoice(
                label: '$y',
                selected: year == y,
                onSelected: () => onYear(y),
              ),
          ],
        ),
      ),
    ],
  );
}

/// The years offered: ages 1 to 8 this year, newest last (the app is for 2 to 8; the server
/// accepts 1 to 12, and the parent edit screen offers the full range).
List<int> pickerYears(DateTime now, {int oldest = 8}) => [
  for (var y = now.year - oldest; y <= now.year - 1; y++) y,
];
