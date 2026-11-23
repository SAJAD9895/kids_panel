import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../domain/item_spec.dart';
import '../../domain/kinds/memory_trace_kinds.dart';
import 'item_views.dart';

/// Tracing: the letter's path as a soft dotted guide with a green start dot; the child draws on
/// top with a finger (or mouse / stylus), then taps the check button. "Clear" starts again.
class TraceItemView extends StatefulWidget {
  const TraceItemView({super.key, required this.ctx});

  final ItemViewContext ctx;

  @override
  State<TraceItemView> createState() => _TraceItemViewState();
}

class _TraceItemViewState extends State<TraceItemView> {
  final _strokes = <List<Pt>>[];

  TraceSpec get spec => widget.ctx.spec as TraceSpec;

  @override
  void didUpdateWidget(TraceItemView old) {
    super.didUpdateWidget(old);
    if (old.ctx.locked && !widget.ctx.locked) setState(_strokes.clear);
  }

  Pt _norm(Offset p, double side) =>
      Pt((p.dx / side).clamp(0, 1), (p.dy / side).clamp(0, 1));

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      // The whole letter must be on screen while the finger moves (no scrolling mid-trace):
      // on short screens (phones held sideways) the box shrinks to the height left under the
      // top bar and prompt, and the buttons move beside it.
      final screenH = MediaQuery.sizeOf(context).height;
      final short = screenH < Sizes.kidsShortScreen;
      final byHeight = screenH - Sizes.kidsHeroH + Space.s6;
      final side =
          [
                c.maxWidth * (short ? 0.6 : 1),
                Sizes.kidsArtLg * 1.6,
                if (short) byHeight,
              ]
              .reduce((a, b) => a < b ? a : b)
              .clamp(Sizes.tapKidsXl * 2, Sizes.kidsArtLg * 1.6)
              .toDouble();
      final pointCount = _strokes.fold<int>(0, (n, s) => n + s.length);
      final box = Semantics(
        container: true,
        label:
            'Tracing area for ${spec.glyph ?? 'the shape'}. Draw with your finger, then press check.',
        // Claims the finger on touch-down: a stroke that starts straight up or down must
        // draw, not scroll the page underneath.
        child: RawGestureDetector(
          gestures: {
            _ImmediatePanRecognizer:
                GestureRecognizerFactoryWithHandlers<_ImmediatePanRecognizer>(
                  _ImmediatePanRecognizer.new,
                  (r) {
                    final locked = widget.ctx.locked;
                    r.onStart = locked
                        ? null
                        : (d) => setState(
                            () => _strokes.add([_norm(d.localPosition, side)]),
                          );
                    r.onUpdate = locked
                        ? null
                        : (d) => setState(() {
                            if (_strokes.isEmpty) _strokes.add([]);
                            _strokes.last.add(_norm(d.localPosition, side));
                          });
                  },
                ),
          },
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              color: AppColors.kidsSurface,
              borderRadius: BorderRadius.circular(Radii.x2xl),
              boxShadow: Shadows.kidRaised,
            ),
            child: CustomPaint(
              painter: TracePainter(
                guide: spec.strokes,
                drawn: _strokes,
                showStart: true,
                pulseStart: widget.ctx.hint.reveal.contains('start'),
                done: widget.ctx.feedback != null,
              ),
            ),
          ),
        ),
      );
      final buttons = [
        KidsIconButton(
          icon: Icons.refresh_rounded,
          label: 'Clear',
          onPressed: widget.ctx.locked || _strokes.isEmpty
              ? null
              : () => setState(_strokes.clear),
        ),
        const SizedBox(width: Space.s6),
        KidsButton(
          label: 'Check',
          icon: Icons.check_rounded,
          fill: AppColors.kidsMeFill,
          onPressed: widget.ctx.locked || pointCount < 3
              ? null
              : () => widget.ctx.submit(
                  TraceAnswer([
                    for (final s in _strokes) [...s],
                  ]),
                ),
        ),
      ];
      return short
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                box,
                const SizedBox(width: Space.s6),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    buttons[2],
                    const SizedBox(height: Space.s5),
                    buttons[0],
                  ],
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                box,
                const SizedBox(height: Space.s6),
                Row(mainAxisSize: MainAxisSize.min, children: buttons),
              ],
            );
    },
  );
}

class TracePainter extends CustomPainter {
  TracePainter({
    required this.guide,
    required this.drawn,
    this.showStart = true,
    this.pulseStart = false,
    this.done = false,
  });

  final List<List<Pt>> guide;
  final List<List<Pt>> drawn;
  final bool showStart;
  final bool pulseStart;
  final bool done;

  @override
  void paint(Canvas canvas, Size size) {
    Offset at(Pt p) => Offset(p.x * size.width, p.y * size.height);
    final track = Paint()
      ..color = AppColors.kidsLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in guide) {
      final path = Path()..moveTo(at(s.first).dx, at(s.first).dy);
      for (final p in s.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
      canvas.drawPath(path, track);
      for (final p in TraceSpec.resample(s, 0.05)) {
        canvas.drawCircle(
          at(p),
          size.width * 0.012,
          Paint()..color = AppColors.kidsInkMuted,
        );
      }
    }
    if (showStart) {
      for (final (i, s) in guide.indexed) {
        canvas.drawCircle(
          at(s.first),
          size.width * (pulseStart && i == 0 ? 0.06 : 0.04),
          Paint()..color = AppColors.kidsSuccess,
        );
      }
    }
    final ink = Paint()
      ..color = done ? AppColors.kidsSuccess : AppColors.kidsLearnInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in drawn) {
      if (s.isEmpty) continue;
      final path = Path()..moveTo(at(s.first).dx, at(s.first).dy);
      for (final p in s.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
      canvas.drawPath(path, ink);
    }
  }

  @override
  bool shouldRepaint(TracePainter old) => true;
}

/// A pan that wins the gesture arena as soon as the finger is down (before any scroll view
/// can take a vertical stroke), and starts at the touch point.
class _ImmediatePanRecognizer extends PanGestureRecognizer {
  _ImmediatePanRecognizer() {
    dragStartBehavior = DragStartBehavior.down;
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }
}
