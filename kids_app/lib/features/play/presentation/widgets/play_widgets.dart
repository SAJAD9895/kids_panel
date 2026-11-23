import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/art/characters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/item_spec.dart';

/// Draws a [PictureRef]: our shapes, a curated icon set, our characters, big letters and
/// numbers, or a counted group. Real artwork (`asset:`) plugs in here when media exists.
class PictureView extends StatelessWidget {
  const PictureView(this.ref, {super.key, this.size = Sizes.kidsNode});

  final PictureRef ref;
  final double size;

  static const icons = <String, IconData>{
    'cat': Icons.pets,
    'dog': Icons.cruelty_free,
    'cow': Icons.agriculture,
    'duck': Icons.water_drop,
    'fish': Icons.set_meal,
    'bird': Icons.flutter_dash,
    'apple': Icons.apple,
    'banana': Icons.lunch_dining,
    'carrot': Icons.eco,
    'sailboat': Icons.sailing,
    'car': Icons.directions_car,
    'ball': Icons.sports_baseball,
    'sun': Icons.wb_sunny,
    'moon': Icons.nightlight_round,
    'flower': Icons.local_florist,
    'tree': Icons.park,
    'house': Icons.home,
    'cake': Icons.cake,
    'pets': Icons.pets,
    'water': Icons.waves,
    'star': Icons.star,
  };

  static const _iconColors = <String, Color>{
    'cat': AppColors.kidsPlayInk,
    'dog': AppColors.kidsListenInk,
    'cow': AppColors.kidsInk,
    'duck': AppColors.kidsListenInk,
    'fish': AppColors.kidsWatchInk,
    'bird': AppColors.kidsLearnInk,
    'apple': AppColors.uiDanger,
    'banana': AppColors.kidsListenInk,
    'carrot': AppColors.kidsPlayInk,
    'sailboat': AppColors.kidsLearnInk,
    'car': AppColors.kidsPlayInk,
    'ball': AppColors.kidsLearnInk,
    'sun': AppColors.kidsStar,
    'moon': AppColors.kidsLearnInk,
    'flower': AppColors.kidsPlayInk,
    'tree': AppColors.kidsMeInk,
    'house': AppColors.kidsPlayInk,
    'cake': AppColors.kidsPlayInk,
    'water': AppColors.kidsWatchInk,
    'star': AppColors.kidsStar,
  };

  /// `?color=` values → our paint tokens.
  static const paints = <String, Color>{
    'red': AppColors.kidsPaintRed,
    'blue': AppColors.kidsPaintBlue,
    'yellow': AppColors.kidsPaintYellow,
    'green': AppColors.kidsPaintGreen,
    'purple': AppColors.kidsPaintPurple,
    'orange': AppColors.kidsPaintOrange,
  };

  /// `?size=` values → share of the box (the box stays the same, so tiles line up).
  static double scaleOf(String? size) => switch (size) {
    'small' => 0.5,
    'medium' => 0.72,
    _ => 1.0,
  };

  @override
  Widget build(BuildContext context) {
    final name = ref.name;
    final paint = paints[ref.color];
    final inner = size * scaleOf(ref.size);
    final parts = name.split(':');
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: switch (ref.scheme) {
            'shape' => CustomPaint(
              size: Size.square(inner * 0.8),
              painter: ShapePainter(name, color: paint),
            ),
            // One side of a shape (a shape-completion answer).
            'half' => CustomPaint(
              size: Size.square(inner * 0.8),
              painter: ShapePainter(
                parts.first,
                color: paint,
                keep: parts.length > 1 ? parts[1] : 'left',
              ),
            ),
            // A shape with one side missing: the missing side is a pale ghost.
            'gap' => CustomPaint(
              size: Size.square(inner * 0.8),
              painter: ShapePainter(
                parts.first,
                color: paint,
                missing: parts.length > 1 ? parts[1] : 'right',
              ),
            ),
            'icon' => Icon(
              icons[name] ?? Icons.image_outlined,
              size: inner * 0.8,
              color: paint ?? _iconColors[name] ?? AppColors.kidsInk,
            ),
            'char' => CharacterArt(
              Character.values.firstWhere(
                (c) => c.name == name,
                orElse: () => Character.pip,
              ),
              size: size * 0.8,
              mood: Mood.happy,
            ),
            'glyph' => FittedBox(
              child: Text(
                name,
                style: KidsText.display.copyWith(
                  fontSize: inner * 0.7,
                  color: paint,
                ),
              ),
            ),
            'count' => _Count(spec: name, size: size),
            _ => Icon(
              Icons.image_outlined,
              size: size * 0.6,
              color: AppColors.kidsInkMuted,
            ),
          },
        ),
      ),
    );
  }
}

/// One piece of a picture cut into a [grid] × [grid] board (puzzles): piece [index], counted row
/// by row, drawn [size] square.
class PictureSlice extends StatelessWidget {
  const PictureSlice({
    super.key,
    required this.picture,
    required this.index,
    required this.grid,
    required this.size,
  });

  final PictureRef picture;
  final int index;
  final int grid;
  final double size;

  @override
  Widget build(BuildContext context) {
    double at(int i) => grid == 1 ? 0 : -1 + 2 * i / (grid - 1);
    return LayoutBuilder(
      builder: (context, c) {
        // Fit the space we're given (a bordered cell can be a little smaller than [size]).
        final side = [
          size,
          c.maxWidth,
          c.maxHeight,
        ].reduce((a, b) => a < b ? a : b);
        final full = side * grid;
        return SizedBox.square(
          dimension: side,
          child: ClipRect(
            child: OverflowBox(
              maxWidth: full,
              maxHeight: full,
              alignment: Alignment(at(index % grid), at(index ~/ grid)),
              child: PictureView(picture, size: full),
            ),
          ),
        );
      },
    );
  }
}

/// `count:5:apple` → five apples in a neat group.
class _Count extends StatelessWidget {
  const _Count({required this.spec, required this.size});

  final String spec;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = spec.split(':');
    final n = int.tryParse(parts.first) ?? 1;
    final what = parts.length > 1 ? parts[1] : 'star';
    final per = n <= 4 ? 2 : 3;
    final cell = size / (per + 0.4);
    return Wrap(
      alignment: WrapAlignment.center,
      runAlignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < n; i++)
          PictureView(PictureRef('icon:$what'), size: cell),
      ],
    );
  }
}

/// Our flat shapes, in the section colours.
class ShapePainter extends CustomPainter {
  const ShapePainter(this.shape, {this.color, this.keep, this.missing});

  final String shape;

  /// Overrides the shape's own colour (sorting by colour).
  final Color? color;

  /// Draw only this side: left, right, top or bottom.
  final String? keep;

  /// Draw this side as a pale ghost, the rest in colour.
  final String? missing;

  static Rect side(String side, Size s) => switch (side) {
    'right' => Rect.fromLTWH(s.width / 2, 0, s.width / 2, s.height),
    'top' => Rect.fromLTWH(0, 0, s.width, s.height / 2),
    'bottom' => Rect.fromLTWH(0, s.height / 2, s.width, s.height / 2),
    _ => Rect.fromLTWH(0, 0, s.width / 2, s.height),
  };

  static String opposite(String side) => switch (side) {
    'left' => 'right',
    'right' => 'left',
    'top' => 'bottom',
    _ => 'top',
  };

  static const colors = {
    'circle': AppColors.kidsPlayFill,
    'square': AppColors.kidsLearnFill,
    'triangle': AppColors.kidsMeFill,
    'star': AppColors.kidsStar,
    'heart': AppColors.kidsPlayInk,
  };

  @override
  void paint(Canvas canvas, Size s) {
    final fill = color ?? colors[shape] ?? AppColors.kidsWatchFill;
    if (missing != null) {
      _draw(canvas, s, Paint()..color = AppColors.kidsLine);
      canvas.save();
      canvas.clipRect(side(opposite(missing!), s));
      _draw(canvas, s, Paint()..color = fill);
      canvas.restore();
      return;
    }
    if (keep != null) {
      canvas.save();
      canvas.clipRect(side(keep!, s));
      _draw(canvas, s, Paint()..color = fill);
      canvas.restore();
      return;
    }
    _draw(canvas, s, Paint()..color = fill);
  }

  void _draw(Canvas canvas, Size s, Paint paint) {
    final w = s.width, h = s.height;
    switch (shape) {
      case 'circle':
        canvas.drawCircle(Offset(w / 2, h / 2), w / 2, paint);
      case 'square':
        canvas.drawRRect(
          RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(w * 0.12)),
          paint,
        );
      case 'triangle':
        canvas.drawPath(
          Path()
            ..addPolygon([Offset(w / 2, 0), Offset(w, h), Offset(0, h)], true),
          paint,
        );
      case 'star':
        final pts = <Offset>[
          for (var i = 0; i < 10; i++)
            Offset(
              w / 2 +
                  (i.isEven ? w / 2 : w / 4.6) *
                      math.cos(-math.pi / 2 + i * math.pi / 5),
              h / 2 +
                  (i.isEven ? h / 2 : h / 4.6) *
                      math.sin(-math.pi / 2 + i * math.pi / 5),
            ),
        ];
        canvas.drawPath(Path()..addPolygon(pts, true), paint);
      case 'heart':
        final p = Path()
          ..moveTo(w / 2, h * 0.9)
          ..cubicTo(-w * 0.2, h * 0.4, w * 0.25, -h * 0.1, w / 2, h * 0.25)
          ..cubicTo(w * 0.75, -h * 0.1, w * 1.2, h * 0.4, w / 2, h * 0.9);
        canvas.drawPath(p, paint);
      default:
        canvas.drawOval(Offset.zero & s, paint);
    }
  }

  @override
  bool shouldRepaint(ShapePainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.keep != keep ||
      old.missing != missing;
}

/// The look of a tile as the game goes.
enum TileState { idle, selected, correct, wrong, dimmed, highlighted }

/// A big answer button (≥ 84 dp): a picture, a word, or a big letter. Shakes when wrong,
/// glows when right; dimmed options (removed by a hint) can't be pressed.
class AnswerTile extends StatefulWidget {
  const AnswerTile({
    super.key,
    required this.choice,
    required this.onPressed,
    this.state = TileState.idle,
    this.size = Sizes.tapKidsXl + Space.s9,
    this.glyph = false,
  });

  final Choice choice;
  final VoidCallback? onPressed;
  final TileState state;
  final double size;

  /// Show the label as a big letter / number.
  final bool glyph;

  @override
  State<AnswerTile> createState() => _AnswerTileState();
}

class _AnswerTileState extends State<AnswerTile>
    with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(vsync: this, duration: Motion.slow);

  @override
  void didUpdateWidget(AnswerTile old) {
    super.didUpdateWidget(old);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.state == TileState.wrong &&
        old.state != TileState.wrong &&
        !reduce) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final enabled = widget.onPressed != null && s != TileState.dimmed;
    final bg = switch (s) {
      TileState.correct || TileState.highlighted => AppColors.kidsSuccessFill,
      TileState.wrong => AppColors.kidsPlaySoft,
      TileState.selected => AppColors.kidsLearnSoft,
      _ => AppColors.kidsSurface,
    };
    final border = switch (s) {
      TileState.correct || TileState.highlighted => AppColors.kidsSuccess,
      TileState.wrong => AppColors.kidsPlayInk,
      TileState.selected => AppColors.kidsLearnInk,
      _ => AppColors.kidsLine,
    };
    final label = widget.choice.label.of();
    final stateWord = switch (s) {
      TileState.correct => ', right',
      TileState.wrong => ', not this one',
      TileState.highlighted => ', this is the answer',
      TileState.selected => ', chosen',
      _ => '',
    };
    // Small tiles (64 dp memory cards on a phone held sideways) scale the picture and its word
    // down together instead of overflowing.
    final content = widget.choice.picture != null
        ? FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PictureView(
                  widget.choice.picture!,
                  size:
                      widget.size *
                      (label.isEmpty || widget.glyph ? 0.8 : 0.62),
                ),
                if (label.isNotEmpty && !widget.glyph)
                  Text(
                    label,
                    style: KidsText.caption.copyWith(color: AppColors.kidsInk),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(Space.s3),
              child: Text(
                label,
                style: widget.glyph
                    ? KidsText.display.copyWith(fontSize: widget.size * 0.55)
                    : KidsText.heading,
              ),
            ),
          );
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(math.sin(_shake.value * math.pi * 6) * Space.s3, 0),
        child: child,
      ),
      child: Semantics(
        container: true,
        button: true,
        enabled: enabled,
        label: '${widget.choice.spoken()}$stateWord',
        excludeSemantics: true,
        onTap: enabled ? widget.onPressed : null,
        child: FocusableActionDetector(
          enabled: enabled,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) => enabled ? widget.onPressed?.call() : null,
            ),
          },
          child: GestureDetector(
            onTap: enabled ? widget.onPressed : null,
            child: AnimatedOpacity(
              duration: Motion.fast,
              opacity: s == TileState.dimmed ? 0.3 : 1,
              child: AnimatedContainer(
                duration: Motion.fast,
                width: widget.size,
                height: widget.size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(Radii.xl),
                  border: Border.all(
                    color: border,
                    width: s == TileState.idle ? Space.s1 : Space.s2,
                  ),
                  boxShadow: s == TileState.dimmed ? null : Shadows.kidRaised,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The question: a picture, short text, and a "hear it again" button. With [audioOnly] the
/// text is hidden and the listen button is big (audio questions).
class PromptBar extends StatelessWidget {
  const PromptBar({
    super.key,
    required this.prompt,
    required this.onListen,
    this.audioOnly = false,
    this.extra,
  });

  final Prompt prompt;
  final VoidCallback onListen;
  final bool audioOnly;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final text = prompt.text.of();
    if (audioOnly) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            button: true,
            label: 'Listen to the question',
            excludeSemantics: true,
            onTap: onListen,
            child: GestureDetector(
              onTap: onListen,
              child: Container(
                width: Sizes.tapKidsXl * 1.4,
                height: Sizes.tapKidsXl * 1.4,
                decoration: const BoxDecoration(
                  color: AppColors.kidsListenFill,
                  shape: BoxShape.circle,
                  boxShadow: Shadows.kidRaised,
                ),
                child: const Icon(
                  Icons.volume_up_rounded,
                  size: Sizes.tapKids,
                  color: AppColors.kidsInk,
                ),
              ),
            ),
          ),
          ?extra,
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prompt.picture != null) ...[
          PictureView(prompt.picture!, size: Sizes.kidsNode),
          const SizedBox(width: Space.s5),
        ],
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (text.isNotEmpty)
                Semantics(
                  container: true,
                  header: true,
                  child: Text(
                    text,
                    style: KidsText.heading,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ?extra,
            ],
          ),
        ),
      ],
    );
  }
}

/// Row of dots: done (green), current (wide), still to come.
class ItemDots extends StatelessWidget {
  const ItemDots({
    super.key,
    required this.total,
    required this.index,
    required this.done,
  });

  final int total;
  final int index;
  final List<bool> done;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Question ${index + 1} of $total',
    child: ExcludeSemantics(
      child: Wrap(
        spacing: Space.s2,
        runSpacing: Space.s2,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: Motion.base,
              width: i == index ? Space.s8 : Space.s5,
              height: Space.s5,
              decoration: BoxDecoration(
                color: done[i]
                    ? AppColors.kidsSuccessFill
                    : (i == index ? AppColors.kidsInk : AppColors.kidsSurface),
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: AppColors.kidsLine, width: Space.s1),
              ),
            ),
        ],
      ),
    ),
  );
}
