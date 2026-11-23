import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A titled card for one chart. Screen readers get [summary]; everyone can open the exact
/// numbers as a table ([rows]), so nothing is only shown as a picture.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.title,
    required this.summary,
    required this.child,
    this.subtitle,
    this.rows = const [],
    this.columns = const ['', 'Value'],
  });

  final String title;
  final String? subtitle;

  /// One sentence that says what the chart shows, with its key numbers.
  final String summary;
  final Widget child;
  final List<List<String>> rows;
  final List<String> columns;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(Space.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: UiText.h3),
          if (subtitle != null) ...[
            const SizedBox(height: Space.s1),
            Text(subtitle!, style: UiText.small),
          ],
          const SizedBox(height: Space.s5),
          Semantics(
            container: true,
            label: summary,
            child: ExcludeSemantics(child: child),
          ),
          if (rows.isNotEmpty)
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Show as a table', style: UiText.small),
                children: [
                  Table(
                    columnWidths: const {0: FlexColumnWidth(2)},
                    children: [
                      TableRow(
                        children: [
                          for (final c in columns)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: Space.s2,
                              ),
                              child: Text(c, style: UiText.bodyStrong),
                            ),
                        ],
                      ),
                      for (final r in rows)
                        TableRow(
                          children: [
                            for (final c in r)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: Space.s2,
                                ),
                                child: Text(
                                  c,
                                  style: UiText.small.copyWith(
                                    color: AppColors.uiText,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// Vertical bars (one per day or week). Labels are thinned out when there are many bars.
class ColumnChart extends StatelessWidget {
  const ColumnChart({
    super.key,
    required this.values,
    required this.labels,
    this.max,
    this.color = AppColors.uiChart1,
    this.height = Sizes.kidsCardArtH,
    this.highlight,
  });

  final List<double> values;
  final List<String> labels;

  /// The top of the scale (defaults to the largest value).
  final double? max;
  final Color color;
  final double height;

  /// Index drawn darker (e.g. today).
  final int? highlight;

  @override
  Widget build(BuildContext context) {
    final top = max ?? values.fold<double>(0, (a, b) => b > a ? b : a);
    final every = values.length > 14 ? 5 : 1;
    return SizedBox(
      height: height + Space.s7,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.s1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: top <= 0
                          ? Space.s1
                          : (height * values[i] / top).clamp(Space.s1, height),
                      decoration: BoxDecoration(
                        color: values[i] <= 0
                            ? AppColors.uiBorder
                            : i == highlight
                            ? AppColors.uiPrimaryHover
                            : color,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(Radii.xs),
                        ),
                      ),
                    ),
                    const SizedBox(height: Space.s2),
                    SizedBox(
                      height: Space.s5,
                      child: FittedBox(
                        child: Text(
                          i % every == 0 || i == values.length - 1
                              ? labels[i]
                              : '',
                          style: UiText.caption,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal bars with a label and a value at the end.
class BarList extends StatelessWidget {
  const BarList({
    super.key,
    required this.rows,
    this.color = AppColors.uiChart3,
  });

  final List<({String label, double fraction, String value})> rows;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.label,
                      style: UiText.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Space.s3),
                  Text(r.value, style: UiText.bodyStrong),
                ],
              ),
              const SizedBox(height: Space.s2),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: LinearProgressIndicator(
                  value: r.fraction.clamp(0.0, 1.0),
                  minHeight: Space.s3,
                  color: color,
                  backgroundColor: AppColors.uiBorder,
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// A small number tile ("Time", "1 h 05 min", "+12 min vs last week").
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.icon,
    this.width,
  });

  final String label;
  final String value;
  final String? note;
  final IconData? icon;
  final double? width;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label: $value${note == null ? '' : ', $note'}',
    child: ExcludeSemantics(
      child: Container(
        width: width,
        padding: const EdgeInsets.all(Space.s5),
        decoration: BoxDecoration(
          color: AppColors.uiSurface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: AppColors.uiBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: Sizes.iconMd, color: AppColors.uiPrimary),
                  const SizedBox(width: Space.s3),
                ],
                Flexible(child: Text(label, style: UiText.small)),
              ],
            ),
            const SizedBox(height: Space.s2),
            Text(value, style: UiText.h3),
            if (note != null) ...[
              const SizedBox(height: Space.s1),
              Text(note!, style: UiText.caption),
            ],
          ],
        ),
      ),
    ),
  );
}
