import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/tokens.g.dart';

/// Original characters, drawn in code (no image files): Pip (a seedling), Bolt (a robot) and
/// Nova (a star), plus 12 buddy avatars. They are placeholders for the commissioned art and
/// follow the shapes in docs/design/mockups/lib.js. Colours come from the design tokens.
enum Character { pip, bolt, nova }

enum Mood { normal, happy }

/// A character at [size] logical pixels wide. Decorative: hidden from screen readers unless
/// a [semanticLabel] is given.
class CharacterArt extends StatelessWidget {
  const CharacterArt(
    this.character, {
    super.key,
    this.size = Sizes.kidsArtLg,
    this.mood = Mood.normal,
    this.semanticLabel,
  });

  final Character character;
  final double size;
  final Mood mood;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final art = SizedBox(
      width: size,
      height: size * 130 / 120,
      child: CustomPaint(painter: _CharacterPainter(character, mood)),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: art)
        : Semantics(label: semanticLabel, image: true, child: art);
  }
}

/// Buddy avatar [index] (0–11). Buddies are mapped from the `avatars` table by key.
class BuddyArt extends StatelessWidget {
  const BuddyArt(this.index, {super.key, this.size = Sizes.kidsBuddyTile});

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _BuddyPainter(index % buddyCount)),
    ),
  );
}

const buddyCount = 12;

/// Spoken names for the buddies (screen readers and the "hear the name" button).
const buddyNames = [
  'Bun',
  'Zippy',
  'Sprout',
  'Rumble',
  'Fluff',
  'Momo',
  'Leafy',
  'Beepo',
  'Tufty',
  'Dino',
  'Pebble',
  'Maple',
];

// ---------------------------------------------------------------------------------------------
// drawing helpers (coordinates are in the art's own viewBox; the painter scales the canvas)
// ---------------------------------------------------------------------------------------------

Paint _fill(Color c, [double opacity = 1]) => Paint()
  ..color = c.withValues(alpha: opacity)
  ..style = PaintingStyle.fill
  ..isAntiAlias = true;

Paint _stroke(Color c, double width) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..isAntiAlias = true;

void _eyes(Canvas c, double cx, double cy, double gap, double r, Mood mood) {
  final l = cx - gap, rr = cx + gap;
  if (mood == Mood.happy) {
    final p = Path()
      ..moveTo(l - r, cy)
      ..quadraticBezierTo(l, cy - r * 1.4, l + r, cy)
      ..moveTo(rr - r, cy)
      ..quadraticBezierTo(rr, cy - r * 1.4, rr + r, cy);
    c.drawPath(p, _stroke(AppColors.kidsInk, r * 0.55));
    return;
  }
  for (final x in [l, rr]) {
    c.drawCircle(Offset(x, cy), r, _fill(AppColors.kidsInk));
    c.drawCircle(
      Offset(x + r * 0.35, cy - r * 0.35),
      r * 0.35,
      _fill(AppColors.kidsSurface),
    );
  }
}

void _smile(Canvas c, double cx, double cy, double w) {
  final p = Path()
    ..moveTo(cx - w, cy)
    ..quadraticBezierTo(cx, cy + w * 0.9, cx + w, cy);
  c.drawPath(p, _stroke(AppColors.kidsInk, w * 0.28));
}

void _cheeks(Canvas c, double cx, double cy, double gap) {
  for (final x in [cx - gap, cx + gap]) {
    c.drawCircle(Offset(x, cy), 6, _fill(AppColors.kidsPlayFill, 0.45));
  }
}

RRect _rr(double x, double y, double w, double h, double r) =>
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

class _CharacterPainter extends CustomPainter {
  const _CharacterPainter(this.character, this.mood);

  final Character character;
  final Mood mood;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 130);
    switch (character) {
      case Character.pip:
        canvas.drawPath(
          Path()
            ..moveTo(60, 30)
            ..cubicTo(40, 6, 18, 14, 22, 30)
            ..cubicTo(34, 34, 50, 34, 60, 30)
            ..close(),
          _fill(AppColors.kidsSuccess),
        );
        canvas.drawPath(
          Path()
            ..moveTo(60, 30)
            ..cubicTo(80, 4, 104, 12, 98, 28)
            ..cubicTo(86, 34, 70, 34, 60, 30)
            ..close(),
          _fill(AppColors.kidsMeFill),
        );
        canvas.drawRRect(_rr(57, 22, 6, 16, 3), _fill(AppColors.kidsSuccess));
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(60, 82), width: 92, height: 88),
          _fill(AppColors.kidsMeFill),
        );
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(60, 96), width: 60, height: 44),
          _fill(AppColors.kidsMeSoft),
        );
        _eyes(canvas, 60, 74, 15, 7, mood);
        _smile(canvas, 60, 90, 9);
        _cheeks(canvas, 60, 86, 30);
      case Character.bolt:
        canvas.drawLine(
          const Offset(60, 8),
          const Offset(60, 28),
          _stroke(AppColors.kidsInk, 5),
        );
        canvas.drawCircle(
          const Offset(60, 10),
          8,
          _fill(AppColors.kidsPlayFill),
        );
        canvas.drawRRect(
          _rr(14, 28, 92, 84, 30),
          _fill(AppColors.kidsLearnFill),
        );
        canvas.drawRRect(
          _rr(26, 42, 68, 46, 18),
          _fill(AppColors.kidsLearnSoft),
        );
        _eyes(canvas, 60, 62, 14, 6, mood);
        _smile(canvas, 60, 74, 8);
        canvas.drawRRect(_rr(4, 60, 12, 26, 6), _fill(AppColors.kidsLearnInk));
        canvas.drawRRect(
          _rr(104, 60, 12, 26, 6),
          _fill(AppColors.kidsLearnInk),
        );
      case Character.nova:
        const pts = [
          Offset(60, 8),
          Offset(74, 44),
          Offset(112, 46),
          Offset(82, 70),
          Offset(93, 108),
          Offset(60, 86),
          Offset(27, 108),
          Offset(38, 70),
          Offset(8, 46),
          Offset(46, 44),
        ];
        final star = Path()..addPolygon(pts, true);
        canvas.drawPath(star, _fill(AppColors.kidsListenFill));
        canvas.drawPath(star, _stroke(AppColors.kidsListenFill, 10));
        _eyes(canvas, 60, 58, 12, 6, mood);
        _smile(canvas, 60, 72, 7);
        _cheeks(canvas, 60, 68, 24);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CharacterPainter old) =>
      old.character != character || old.mood != mood;
}

const _bodyFill = [
  AppColors.kidsPlayFill,
  AppColors.kidsLearnFill,
  AppColors.kidsWatchFill,
  AppColors.kidsListenFill,
  AppColors.kidsMeFill,
  AppColors.kidsPlayFill,
  AppColors.kidsLearnFill,
  AppColors.kidsWatchFill,
  AppColors.kidsListenFill,
  AppColors.kidsMeFill,
  AppColors.kidsLearnFill,
  AppColors.kidsPlayFill,
];
const _bodySoft = [
  AppColors.kidsPlaySoft,
  AppColors.kidsLearnSoft,
  AppColors.kidsWatchSoft,
  AppColors.kidsListenSoft,
  AppColors.kidsMeSoft,
  AppColors.kidsPlaySoft,
  AppColors.kidsLearnSoft,
  AppColors.kidsWatchSoft,
  AppColors.kidsListenSoft,
  AppColors.kidsMeSoft,
  AppColors.kidsLearnSoft,
  AppColors.kidsPlaySoft,
];

enum _Top { ears, antenna, leaf, horns, tuft }

const _tops = [
  _Top.ears,
  _Top.antenna,
  _Top.leaf,
  _Top.horns,
  _Top.tuft,
  _Top.ears,
  _Top.leaf,
  _Top.antenna,
  _Top.tuft,
  _Top.horns,
  _Top.ears,
  _Top.leaf,
];

class _BuddyPainter extends CustomPainter {
  const _BuddyPainter(this.i);

  final int i;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final s = math.min(size.width, size.height) / 100;
    canvas.scale(s, s);
    final fill = _bodyFill[i], soft = _bodySoft[i];
    switch (_tops[i]) {
      case _Top.ears:
        canvas.drawCircle(const Offset(28, 26), 12, _fill(fill));
        canvas.drawCircle(const Offset(72, 26), 12, _fill(fill));
      case _Top.antenna:
        canvas.drawLine(
          const Offset(50, 6),
          const Offset(50, 22),
          _stroke(AppColors.kidsInk, 4),
        );
        canvas.drawCircle(const Offset(50, 7), 6, _fill(AppColors.kidsStar));
      case _Top.leaf:
        canvas.drawPath(
          Path()
            ..moveTo(50, 20)
            ..cubicTo(38, 2, 24, 8, 28, 18)
            ..cubicTo(36, 22, 44, 22, 50, 20)
            ..close(),
          _fill(AppColors.kidsSuccess),
        );
      case _Top.horns:
        canvas.drawPath(
          Path()
            ..addPolygon(const [
              Offset(28, 26),
              Offset(22, 6),
              Offset(38, 20),
            ], true)
            ..addPolygon(const [
              Offset(72, 26),
              Offset(78, 6),
              Offset(62, 20),
            ], true),
          _fill(AppColors.kidsInk),
        );
      case _Top.tuft:
        canvas.drawPath(
          Path()
            ..moveTo(38, 20)
            ..relativeQuadraticBezierTo(6, -16, 12, 0)
            ..relativeQuadraticBezierTo(6, -16, 12, 0),
          _stroke(fill, 8),
        );
    }
    canvas.drawRRect(_rr(12, 20, 76, 74, i % 3 == 0 ? 38 : 28), _fill(fill));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 72), width: 48, height: 32),
      _fill(soft),
    );
    _eyes(canvas, 50, 52, 12, 6, i % 4 == 1 ? Mood.happy : Mood.normal);
    _smile(canvas, 50, 66, 7);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BuddyPainter old) => old.i != i;
}
