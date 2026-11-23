import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../media/presentation/widgets/media_thumb.dart';
import '../../domain/rewards.dart';

/// A rounded progress bar with its words ("2 of 3") for screen readers and sighted kids.
class GoalBar extends StatelessWidget {
  const GoalBar({
    super.key,
    required this.fraction,
    required this.label,
    this.fill = AppColors.kidsStar,
    this.track = AppColors.kidsSurface,
  });

  final double fraction;
  final String label;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: ExcludeSemantics(
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: fraction.clamp(0, 1)),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : Motion.slow,
                curve: Motion.easeDecelerate,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: Space.s5,
                  color: fill,
                  backgroundColor: track,
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.s4),
          Text(label, style: KidsText.label),
        ],
      ),
    ),
  );
}

/// A ring that fills as a goal is reached, with something in the middle.
class GoalRing extends StatelessWidget {
  const GoalRing({
    super.key,
    required this.fraction,
    required this.size,
    required this.child,
    this.fill = AppColors.kidsStar,
    this.track = AppColors.kidsLine,
  });

  final double fraction;
  final double size;
  final Widget child;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: fraction.clamp(0, 1)),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Motion.celebrate,
    curve: Motion.easeDecelerate,
    builder: (_, v, c) => CustomPaint(
      size: Size.square(size),
      painter: _RingPainter(v, fill, track),
      child: SizedBox.square(
        dimension: size,
        child: Center(child: c),
      ),
    ),
    child: child,
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.fill, this.track);
  final double v;
  final Color fill;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.1;
    final rect = (Offset.zero & size).deflate(w / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, p..color = track);
    if (v > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * v,
        false,
        p..color = fill,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.v != v || old.fill != fill || old.track != track;
}

/// A badge's picture. Not earned yet: shown in grey and a little faded, never hidden, so a
/// child can see what there is to look forward to.
class BadgeArt extends StatelessWidget {
  const BadgeArt({
    super.key,
    required this.art,
    required this.size,
    this.earned = true,
  });

  final String art;
  final double size;
  final bool earned;

  static const _grey = ColorFilter.matrix([
    0.33, 0.33, 0.33, 0, 0, //
    0.33, 0.33, 0.33, 0, 0, //
    0.33, 0.33, 0.33, 0, 0, //
    0, 0, 0, 0.55, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      Icons.workspace_premium_rounded,
      size: size * 0.6,
      color: earned ? AppColors.kidsStar : AppColors.kidsInkMuted,
    );
    final pic = art.isEmpty
        ? Center(child: fallback)
        : MediaThumb(
            path: art,
            width: size,
            fit: BoxFit.contain,
            fallback: fallback,
            background: Colors.transparent,
          );
    return SizedBox.square(
      dimension: size,
      child: earned ? pic : ColorFiltered(colorFilter: _grey, child: pic),
    );
  }
}

/// Six weeks of learning days, Monday first. A learning day shows a star; other days are
/// plain (never a cross or a red mark): rest is fine.
class StreakCalendar extends StatelessWidget {
  const StreakCalendar({
    super.key,
    required this.today,
    required this.learningDays,
    this.weeks = 6,
  });

  final DateTime today;
  final Set<DateTime> learningDays;
  final int weeks;

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final t = dayOf(today);
    final first = weekStartOf(t).subtract(Duration(days: 7 * (weeks - 1)));
    final days = {for (final d in learningDays) dayOf(d)};
    final count = days.where((d) => !d.isBefore(first) && !d.isAfter(t)).length;
    return Semantics(
      container: true,
      label:
          'Learning calendar: $count learning ${count == 1 ? 'day' : 'days'} in the last $weeks weeks',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, c) {
            final cell = math.min(
              (c.maxWidth - Space.s2 * 6) / 7,
              Sizes.tapKidsSecondary,
            );
            Widget row(List<Widget> cells) => Padding(
              padding: const EdgeInsets.only(bottom: Space.s2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, w) in cells.indexed) ...[
                    if (i > 0) const SizedBox(width: Space.s2),
                    SizedBox.square(dimension: cell, child: w),
                  ],
                ],
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row([
                  for (final l in _dayLetters)
                    Center(child: Text(l, style: KidsText.caption)),
                ]),
                for (var w = 0; w < weeks; w++)
                  row([
                    for (var d = 0; d < 7; d++)
                      _DayCell(
                        day: first.add(Duration(days: w * 7 + d)),
                        today: t,
                        learned: days.contains(
                          first.add(Duration(days: w * 7 + d)),
                        ),
                      ),
                  ]),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.learned,
  });

  final DateTime day;
  final DateTime today;
  final bool learned;

  @override
  Widget build(BuildContext context) {
    final future = day.isAfter(today);
    final isToday = day == today;
    return Container(
      decoration: BoxDecoration(
        color: learned
            ? AppColors.kidsListenSoft
            : future
            ? Colors.transparent
            : AppColors.kidsSurface,
        shape: BoxShape.circle,
        border: isToday
            ? Border.all(color: AppColors.kidsInk, width: Space.s1)
            : null,
      ),
      child: learned
          ? const FittedBox(
              child: Padding(
                padding: EdgeInsets.all(Space.s2),
                child: Icon(Icons.star_rounded, color: AppColors.kidsStar),
              ),
            )
          : Center(
              child: Text(
                '${day.day}',
                style: KidsText.caption.copyWith(
                  color: future ? AppColors.kidsLine : AppColors.kidsInkMuted,
                ),
              ),
            ),
    );
  }
}

/// The look of a celebration (all drawn here; original).
enum CelebrationStyle { stars, badge, goal, course, milestone }

/// A short, one-time burst behind a celebration: stars fly out (stars), soft rays turn behind
/// a badge (badge), a ring of stars (goal), shapes fall like confetti (course), stepping stones
/// light up (milestone). It plays once and stops; with "reduce motion" it shows a still picture.
class CelebrationBurst extends StatefulWidget {
  const CelebrationBurst({
    super.key,
    required this.style,
    required this.size,
    this.child,
  });

  final CelebrationStyle style;
  final double size;
  final Widget? child;

  @override
  State<CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: Motion.celebrate * 2,
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1; // the finished picture, no movement
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, c) => CustomPaint(
        painter: _BurstPainter(widget.style, _c.value),
        child: Center(
          child: Transform.scale(
            scale: Motion.easeBounce.transform(
              (_c.value * 2.5).clamp(0.0, 1.0),
            ),
            child: c,
          ),
        ),
      ),
      child: widget.child,
    ),
  );
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.style, this.t);
  final CelebrationStyle style;
  final double t;

  static const _colours = [
    AppColors.kidsPaintRed,
    AppColors.kidsPaintBlue,
    AppColors.kidsPaintYellow,
    AppColors.kidsPaintGreen,
    AppColors.kidsPaintPurple,
    AppColors.kidsPaintOrange,
  ];

  static Path star(Offset c, double r, [double rot = 0]) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + rot + i * math.pi / 5;
      final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rnd = math.Random(7);
    final out = Curves.easeOutCubic.transform(t);
    final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
    final paint = Paint();
    switch (style) {
      case CelebrationStyle.stars:
      case CelebrationStyle.goal:
        final n = style == CelebrationStyle.goal ? 10 : 12;
        for (var i = 0; i < n; i++) {
          final a = i * math.pi * 2 / n + rnd.nextDouble() * 0.3;
          final d = r * (0.35 + 0.55 * out) * (0.8 + rnd.nextDouble() * 0.2);
          final p = c + Offset(math.cos(a) * d, math.sin(a) * d);
          paint.color = (i.isEven ? AppColors.kidsStar : _colours[i % 6])
              .withValues(alpha: style == CelebrationStyle.goal ? 1 : fade);
          canvas.drawPath(star(p, r * 0.09, t * 3 + i), paint);
        }
      case CelebrationStyle.badge:
        paint.color = AppColors.kidsListenSoft;
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6 + t * 0.8;
          final path = Path()
            ..moveTo(c.dx, c.dy)
            ..lineTo(
              c.dx + math.cos(a - 0.12) * r * out,
              c.dy + math.sin(a - 0.12) * r * out,
            )
            ..lineTo(
              c.dx + math.cos(a + 0.12) * r * out,
              c.dy + math.sin(a + 0.12) * r * out,
            )
            ..close();
          canvas.drawPath(path, paint);
        }
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3 + 0.4;
          final p = c + Offset(math.cos(a), math.sin(a)) * r * 0.85 * out;
          paint.color = AppColors.kidsStar.withValues(alpha: fade);
          canvas.drawPath(star(p, r * 0.07, t * 4), paint);
        }
      case CelebrationStyle.course:
        for (var i = 0; i < 28; i++) {
          final x = rnd.nextDouble() * size.width;
          final y0 = -rnd.nextDouble() * size.height * 0.5;
          final y =
              y0 + (size.height * 1.1) * out * (0.6 + rnd.nextDouble() * 0.5);
          paint.color = _colours[i % 6].withValues(alpha: fade);
          final s = r * (0.05 + rnd.nextDouble() * 0.04);
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(t * 6 + i);
          i % 3 == 0
              ? canvas.drawCircle(Offset.zero, s, paint)
              : canvas.drawRRect(
                  RRect.fromRectAndRadius(
                    Rect.fromCenter(
                      center: Offset.zero,
                      width: s * 2,
                      height: s,
                    ),
                    Radius.circular(s / 3),
                  ),
                  paint,
                );
          canvas.restore();
        }
      case CelebrationStyle.milestone:
        for (var i = 0; i < 5; i++) {
          final on = t * 5 > i;
          final p = Offset(
            size.width * (0.14 + i * 0.18),
            size.height * (0.88 - i * 0.07),
          );
          paint.color = AppColors.kidsLine;
          canvas.drawOval(
            Rect.fromCenter(center: p, width: r * 0.3, height: r * 0.16),
            paint,
          );
          if (on) {
            paint.color = AppColors.kidsStar;
            canvas.drawPath(star(p - Offset(0, r * 0.04), r * 0.07), paint);
          }
        }
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t || old.style != style;
}
