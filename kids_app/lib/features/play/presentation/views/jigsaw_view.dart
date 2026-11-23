import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/audio/sfx.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/item_spec.dart';
import '../../domain/kinds/arrange_kinds.dart';
import '../widgets/play_widgets.dart';
import 'item_views.dart';

/// Jigsaw: a board with a faint outline of the picture, and a tray of pieces. Drag a piece onto
/// its place, or tap the piece and then the place. Wrong places bounce the piece back.
class JigsawItemView extends StatefulWidget {
  const JigsawItemView({super.key, required this.ctx});

  final ItemViewContext ctx;

  @override
  State<JigsawItemView> createState() => _JigsawItemViewState();
}

class _JigsawItemViewState extends State<JigsawItemView> {
  final _placed = <String, String>{}; // piece → slot
  String? _selected;
  String? _bounced;
  int _mistakes = 0;

  JigsawSpec get spec => widget.ctx.spec as JigsawSpec;

  void _pick(String piece) {
    if (widget.ctx.locked) return;
    widget.ctx.sound(Sfx.tap);
    setState(() => _selected = _selected == piece ? null : piece);
  }

  void _drop(String piece, String slot) {
    if (widget.ctx.locked || _placed.containsKey(piece)) return;
    if (_placed.containsValue(slot)) return;
    if (spec.fits(piece, slot)) {
      HapticFeedback.lightImpact();
      widget.ctx.sound(Sfx.snap);
      setState(() {
        _placed[piece] = slot;
        _selected = null;
        _bounced = null;
      });
      if (_placed.length == spec.tokens.length) {
        widget.ctx.submit(PlaceAnswer({..._placed}, mistakes: _mistakes));
      }
    } else {
      HapticFeedback.heavyImpact();
      widget.ctx.sound(Sfx.tryAgain);
      setState(() {
        _mistakes++;
        _bounced = piece;
        _selected = null;
      });
      widget.ctx.speak('Not there. Try another place!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reveal = widget.ctx.hint.reveal;
    final shown = widget.ctx.solution is PlaceAnswer
        ? (widget.ctx.solution! as PlaceAnswer).placements
        : _placed;
    final waiting = spec.tokens.where((t) => !shown.containsKey(t.id)).toList();
    return LayoutBuilder(
      builder: (context, c) {
        final room =
            MediaQuery.sizeOf(context).height - Sizes.kidsHeroH - Space.s5;
        final boardSide = [
          room,
          c.maxWidth * 0.55,
          Sizes.kidsArtLg * 1.6,
        ].reduce((a, b) => a < b ? a : b).clamp(Sizes.tapKidsXl * 2, 9999.0);
        final cell = boardSide / spec.grid;
        final trayCell = (cell * 0.9).clamp(
          Sizes.tapKids,
          Sizes.tapKidsXl * 1.6,
        );

        Widget piece(Choice t, {double? size}) => Container(
          decoration: BoxDecoration(
            color: AppColors.kidsSurface,
            borderRadius: BorderRadius.circular(Radii.sm),
            border: Border.all(
              color: t.id == _selected || reveal.contains(t.id)
                  ? AppColors.kidsLearnInk
                  : (t.id == _bounced
                        ? AppColors.kidsPlayInk
                        : AppColors.kidsLine),
              width: t.id == _selected || reveal.contains(t.id)
                  ? Space.s2
                  : Space.s1,
            ),
            boxShadow: Shadows.kidRaised,
          ),
          child: PictureSlice(
            picture: spec.picture,
            index: JigsawSpec.indexOf(t.id),
            grid: spec.grid,
            size: size ?? trayCell,
          ),
        );

        final board = SizedBox.square(
          dimension: boardSide,
          child: Wrap(
            children: [
              for (final slot in spec.targets)
                () {
                  final i = JigsawSpec.indexOf(slot.id);
                  final inside = shown.entries
                      .where((e) => e.value == slot.id)
                      .map((e) => e.key)
                      .firstOrNull;
                  return DragTarget<String>(
                    onAcceptWithDetails: (d) => _drop(d.data, slot.id),
                    builder: (context, candidates, _) => Semantics(
                      container: true,
                      button: inside == null,
                      label:
                          'Place ${i + 1}, ${slot.spoken()}${inside == null ? ', empty' : ', done'}',
                      excludeSemantics: true,
                      onTap: inside == null && _selected != null
                          ? () => _drop(_selected!, slot.id)
                          : null,
                      child: GestureDetector(
                        onTap: inside == null && _selected != null
                            ? () => _drop(_selected!, slot.id)
                            : null,
                        child: Container(
                          width: cell,
                          height: cell,
                          decoration: BoxDecoration(
                            color: candidates.isNotEmpty
                                ? AppColors.kidsLearnSoft
                                : AppColors.kidsBgAlt,
                            border: Border.all(
                              color: reveal.contains(slot.id)
                                  ? AppColors.kidsSuccess
                                  : AppColors.kidsLine,
                              width: reveal.contains(slot.id)
                                  ? Space.s2
                                  : Space.s1 / 2,
                            ),
                          ),
                          child: inside != null
                              ? PictureSlice(
                                  picture: spec.picture,
                                  index: i,
                                  grid: spec.grid,
                                  size: cell,
                                )
                              // A faint outline of the picture shows where pieces go.
                              : Opacity(
                                  opacity: 0.18,
                                  child: PictureSlice(
                                    picture: spec.picture,
                                    index: i,
                                    grid: spec.grid,
                                    size: cell,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  );
                }(),
            ],
          ),
        );

        final tray = Wrap(
          spacing: Space.s4,
          runSpacing: Space.s4,
          alignment: WrapAlignment.center,
          children: [
            for (final t in waiting)
              Semantics(
                container: true,
                button: true,
                selected: t.id == _selected,
                label:
                    'Piece ${JigsawSpec.indexOf(t.id) + 1}${t.id == _selected ? ', picked' : ''}',
                excludeSemantics: true,
                onTap: widget.ctx.locked ? null : () => _pick(t.id),
                child: GestureDetector(
                  onTap: widget.ctx.locked ? null : () => _pick(t.id),
                  child: widget.ctx.locked
                      ? piece(t)
                      : Draggable<String>(
                          data: t.id,
                          onDragStarted: () => widget.ctx.sound(Sfx.tap),
                          feedback: Material(
                            color: Colors.transparent,
                            child: piece(t, size: cell),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: piece(t),
                          ),
                          child: piece(t),
                        ),
                ),
              ),
          ],
        );

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            board,
            const SizedBox(width: Space.s6),
            Flexible(child: tray),
          ],
        );
      },
    );
  }
}
