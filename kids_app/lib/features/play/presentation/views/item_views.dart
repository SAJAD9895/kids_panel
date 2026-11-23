import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../../core/audio/sfx.dart';
import '../../domain/engine.dart';
import '../../domain/item_spec.dart';
import '../../domain/kinds/arrange_kinds.dart';
import '../../domain/kinds/choice_kinds.dart';
import '../../domain/kinds/memory_trace_kinds.dart';
import '../widgets/play_widgets.dart';
import 'jigsaw_view.dart';
import 'trace_view.dart';

/// Everything an item view gets from the player. Views are dumb about rules: they collect an
/// [ItemAnswer] and hand it to [submit]; the engine judges it.
class ItemViewContext {
  const ItemViewContext({
    required this.spec,
    required this.hint,
    required this.feedback,
    required this.solution,
    required this.submit,
    required this.speak,
    required this.policy,
    this.sound = _silent,
    this.paused = false,
  });

  static void _silent(Sfx _) {}

  final ItemSpec spec;

  /// The hint showing now (eliminated options, highlighted pieces).
  final Hint hint;

  /// Null while the child is answering; set while feedback shows (the view locks).
  final FeedbackKind? feedback;

  /// The right answer, when the player shows it after the last try.
  final ItemAnswer? solution;
  final void Function(ItemAnswer answer) submit;
  final void Function(String text) speak;
  final DifficultyPolicy policy;

  /// Plays a sound effect (taps, flips, drops), unless the child turned sounds off.
  final void Function(Sfx sound) sound;

  /// True while the pause sheet is open or the app is in the background (clocks stop).
  final bool paused;

  bool get locked => feedback != null;
}

typedef ItemViewBuilder = Widget Function(
  BuildContext context,
  ItemViewContext ctx,
);

/// Type key → view. Register a builder here when adding an activity type; the player itself
/// doesn't change.
class ItemViewRegistry {
  ItemViewRegistry(this._builders);

  factory ItemViewRegistry.standard() {
    Widget choice(BuildContext c, ItemViewContext x) => ChoiceItemView(ctx: x);
    Widget place(BuildContext c, ItemViewContext x) => PlaceItemView(ctx: x);
    Widget order(BuildContext c, ItemViewContext x) => OrderItemView(ctx: x);
    return ItemViewRegistry({
      'multiple_choice': choice,
      'image_choice': choice,
      'audio_choice': choice,
      'letter_recognition': choice,
      'number_recognition': choice,
      'fill_blank': choice,
      'drag_to_target': place,
      'sort': place,
      'match_pairs': place,
      'word_build': order,
      'puzzle': order,
      'memory': (c, x) => MemoryItemView(ctx: x),
      'trace': (c, x) => TraceItemView(ctx: x),
      'arithmetic': choice,
      'shape_complete': choice,
      'jigsaw': (c, x) => JigsawItemView(ctx: x),
    });
  }

  final Map<String, ItemViewBuilder> _builders;

  void register(String kind, ItemViewBuilder builder) =>
      _builders[kind] = builder;
  bool supports(String kind) => _builders.containsKey(kind);

  Widget build(BuildContext context, ItemViewContext ctx) =>
      (_builders[ctx.spec.kind] ??
      (_, _) =>
          const Center(child: Icon(Icons.extension_off_rounded)))(context, ctx);
}

double _tileSize(BoxConstraints c, int count) {
  final perRow = count <= 2
      ? count
      : (count <= 4 ? (c.maxWidth > 600 ? count : 2) : 3);
  return ((c.maxWidth - Space.s6 * (perRow - 1)) / perRow).clamp(
    Sizes.tapKidsXl,
    Sizes.kidsArtLg * 0.75,
  );
}

// ---------------------------------------------------------------------------------------------
// Choice: multiple choice, image, audio, letters, numbers, fill the blank
// ---------------------------------------------------------------------------------------------

class ChoiceItemView extends StatefulWidget {
  const ChoiceItemView({super.key, required this.ctx});

  final ItemViewContext ctx;

  @override
  State<ChoiceItemView> createState() => _ChoiceItemViewState();
}

class _ChoiceItemViewState extends State<ChoiceItemView> {
  final _picked = <String>{};

  ChoiceSpec get spec => widget.ctx.spec as ChoiceSpec;

  @override
  void didUpdateWidget(ChoiceItemView old) {
    super.didUpdateWidget(old);
    // "Try again": clear the wrong pick.
    if (old.ctx.locked && !widget.ctx.locked) setState(_picked.clear);
  }

  void _tap(Choice o) {
    if (widget.ctx.locked) return;
    HapticFeedback.selectionClick();
    if (spec.multi) {
      setState(
        () => _picked.contains(o.id) ? _picked.remove(o.id) : _picked.add(o.id),
      );
      return;
    }
    setState(
      () => _picked
        ..clear()
        ..add(o.id),
    );
    widget.ctx.submit(PickAnswer({o.id}));
  }

  TileState _state(Choice o) {
    final ctx = widget.ctx;
    final shownAnswer =
        ctx.solution is PickAnswer &&
        (ctx.solution! as PickAnswer).ids.contains(o.id);
    if (ctx.locked && _picked.contains(o.id)) {
      return spec.correct.contains(o.id) ? TileState.correct : TileState.wrong;
    }
    if (shownAnswer) return TileState.highlighted;
    if (ctx.hint.eliminate.contains(o.id)) return TileState.dimmed;
    if (_picked.contains(o.id)) return TileState.selected;
    return TileState.idle;
  }

  @override
  Widget build(BuildContext context) {
    final sentence = spec.sentence?.of();
    final chosen = _picked.isEmpty
        ? null
        : spec.options.firstWhere((o) => o.id == _picked.first).label.of();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (spec.count != null && spec.countPicture != null)
          Container(
            padding: const EdgeInsets.all(Space.s4),
            decoration: BoxDecoration(
              color: AppColors.kidsSurface,
              borderRadius: BorderRadius.circular(Radii.xl),
            ),
            child: Semantics(
              container: true,
              label: '${spec.count} pictures to count',
              child: PictureView(
                PictureRef('count:${spec.count}:${spec.countPicture!.name}'),
                size: Sizes.kidsArtLg * 0.8,
              ),
            ),
          ),
        if (spec.equation != null) EquationView(spec.equation!),
        if (sentence != null) ...[
          Semantics(
            container: true,
            label: sentence.replaceAll(FillBlankKind.blank, chosen ?? 'blank'),
            child: ExcludeSemantics(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                children: [
                  for (final (i, part)
                      in sentence.split(FillBlankKind.blank).indexed) ...[
                    if (i > 0)
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: Space.s3,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.s5,
                          vertical: Space.s2,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: Sizes.tapKidsXl,
                        ),
                        decoration: BoxDecoration(
                          color: chosen == null
                              ? AppColors.kidsBgAlt
                              : AppColors.kidsLearnSoft,
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: Border.all(
                            color: AppColors.kidsInkMuted,
                            width: Space.s1,
                          ),
                        ),
                        child: Text(
                          chosen ?? ' ',
                          style: KidsText.title,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Text(part, style: KidsText.title),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: Space.s7),
        LayoutBuilder(
          builder: (context, c) {
            final size = _tileSize(c, spec.options.length);
            return Wrap(
              spacing: Space.s6,
              runSpacing: Space.s6,
              alignment: WrapAlignment.center,
              children: [
                for (final o in spec.options)
                  AnswerTile(
                    choice: o,
                    size: size,
                    glyph: spec.style == ChoiceStyle.glyph,
                    state: _state(o),
                    onPressed: widget.ctx.locked ? null : () => _tap(o),
                  ),
              ],
            );
          },
        ),
        if (spec.multi && !widget.ctx.locked) ...[
          const SizedBox(height: Space.s6),
          KidsButton(
            label: 'Done',
            icon: Icons.check_rounded,
            fill: AppColors.kidsMeFill,
            onPressed: _picked.isEmpty
                ? null
                : () => widget.ctx.submit(PickAnswer({..._picked})),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Place: drag to target, sorting, matching pairs. Drag, or tap one then tap where it goes.
// ---------------------------------------------------------------------------------------------

class PlaceItemView extends StatefulWidget {
  const PlaceItemView({super.key, required this.ctx});

  final ItemViewContext ctx;

  @override
  State<PlaceItemView> createState() => _PlaceItemViewState();
}

class _PlaceItemViewState extends State<PlaceItemView> {
  final _placed = <String, String>{};
  String? _selected;
  String? _bounced;
  int _mistakes = 0;

  PlaceSpec get spec => widget.ctx.spec as PlaceSpec;
  bool get _pairs => spec.kind == 'match_pairs';

  void _drop(String token, String target) {
    if (widget.ctx.locked || _placed.containsKey(token)) return;
    if (_pairs && _placed.containsValue(target)) return;
    if (spec.fits(token, target)) {
      HapticFeedback.lightImpact();
      widget.ctx.sound(Sfx.snap);
      setState(() {
        _placed[token] = target;
        _selected = null;
        _bounced = null;
      });
      if (_placed.length == spec.tokens.length) {
        widget.ctx.submit(PlaceAnswer({..._placed}, mistakes: _mistakes));
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _mistakes++;
        _bounced = token;
        _selected = null;
      });
      widget.ctx.sound(Sfx.tryAgain);
      widget.ctx.speak('Not there. Try another place!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reveal = widget.ctx.hint.reveal;
    final waiting = spec.tokens
        .where((t) => !_placed.containsKey(t.id))
        .toList();
    return LayoutBuilder(
      builder: (context, c) {
        final tokenSize =
            _tileSize(
              c,
              _pairs ? spec.tokens.length : waiting.length.clamp(1, 4),
            ) *
            0.85;
        final targetSize = _tileSize(c, spec.targets.length);
        Widget token(Choice t, {bool placed = false}) {
          final state = placed
              ? TileState.correct
              : t.id == _bounced
              ? TileState.wrong
              : t.id == _selected
              ? TileState.selected
              : reveal.contains(t.id)
              ? TileState.highlighted
              : TileState.idle;
          final tile = AnswerTile(
            choice: t,
            size: tokenSize,
            state: state,
            onPressed: placed || widget.ctx.locked
                ? null
                : () {
                    // Picture matching: hear the word for what you picked.
                    if (_selected != t.id) widget.ctx.speak(t.spoken());
                    widget.ctx.sound(Sfx.tap);
                    setState(() => _selected = _selected == t.id ? null : t.id);
                  },
          );
          if (placed || widget.ctx.locked) return tile;
          return Draggable<String>(
            data: t.id,
            onDragStarted: () => widget.ctx.speak(t.spoken()),
            feedback: Material(
              color: Colors.transparent,
              child: AnswerTile(choice: t, size: tokenSize, onPressed: () {}),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: tile),
            child: tile,
          );
        }

        Widget target(Choice g) {
          final inside = spec.tokens
              .where((t) => _placed[t.id] == g.id)
              .toList();
          return DragTarget<String>(
            onAcceptWithDetails: (d) => _drop(d.data, g.id),
            builder: (context, candidates, _) => Semantics(
              container: true,
              button: true,
              label:
                  '${g.spoken()}${inside.isEmpty ? '' : ', has ${inside.map((t) => t.spoken()).join(', ')}'}',
              excludeSemantics: true,
              onTap: _selected == null ? null : () => _drop(_selected!, g.id),
              child: GestureDetector(
                // With nothing picked, tapping a place says its name.
                onTap: _selected == null
                    ? () => widget.ctx.speak(g.spoken())
                    : () => _drop(_selected!, g.id),
                child: AnimatedContainer(
                  duration: Motion.fast,
                  constraints: BoxConstraints(
                    minWidth: targetSize,
                    minHeight: targetSize,
                  ),
                  padding: const EdgeInsets.all(Space.s3),
                  decoration: BoxDecoration(
                    color: candidates.isNotEmpty || (_selected != null)
                        ? AppColors.kidsLearnSoft
                        : AppColors.kidsBgAlt,
                    borderRadius: BorderRadius.circular(Radii.xl),
                    border: Border.all(
                      color: reveal.contains(g.id)
                          ? AppColors.kidsSuccess
                          : AppColors.kidsInkMuted,
                      width: Space.s1 + 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (g.picture != null)
                        Opacity(
                          opacity: _pairs ? 1 : 0.45,
                          child: PictureView(
                            g.picture!,
                            size: targetSize * 0.55,
                          ),
                        ),
                      if (!g.label.isEmpty)
                        Text(
                          g.label.of(),
                          style: KidsText.label,
                          textAlign: TextAlign.center,
                        ),
                      if (inside.isNotEmpty && !_pairs)
                        Wrap(
                          spacing: Space.s2,
                          children: [
                            for (final t in inside)
                              PictureViewOrLabel(t, size: targetSize * 0.32),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (_pairs) {
          // Two columns: left items, right partners; matched pairs turn green.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  for (final t in spec.tokens) ...[
                    token(t, placed: _placed.containsKey(t.id)),
                    const SizedBox(height: Space.s4),
                  ],
                ],
              ),
              const SizedBox(width: Space.s9),
              Column(
                children: [
                  for (final g in spec.targets) ...[
                    _placed.containsValue(g.id)
                        ? AnswerTile(
                            choice: g,
                            size: tokenSize,
                            state: TileState.correct,
                            onPressed: null,
                          )
                        : target(g),
                    const SizedBox(height: Space.s4),
                  ],
                ],
              ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: Space.s5,
              runSpacing: Space.s5,
              alignment: WrapAlignment.center,
              children: [for (final t in waiting) token(t)],
            ),
            const SizedBox(height: Space.s8),
            Wrap(
              spacing: Space.s6,
              runSpacing: Space.s6,
              alignment: WrapAlignment.center,
              children: [for (final g in spec.targets) target(g)],
            ),
          ],
        );
      },
    );
  }
}

/// A picture if there is one, else the word.
class PictureViewOrLabel extends StatelessWidget {
  const PictureViewOrLabel(this.choice, {super.key, required this.size});

  final Choice choice;
  final double size;

  @override
  Widget build(BuildContext context) => choice.picture != null
      ? PictureView(choice.picture!, size: size)
      : Text(choice.label.of(), style: KidsText.label);
}

// ---------------------------------------------------------------------------------------------
// Order: word building (tap letters in order), puzzles (tap two pieces to swap them)
// ---------------------------------------------------------------------------------------------

class OrderItemView extends StatefulWidget {
  const OrderItemView({super.key, required this.ctx});

  final ItemViewContext ctx;

  @override
  State<OrderItemView> createState() => _OrderItemViewState();
}

class _OrderItemViewState extends State<OrderItemView> {
  late List<String> _layout; // puzzle: current arrangement; word: unused pool
  final _built = <String>[]; // word: letters placed so far
  String? _first; // puzzle: first piece tapped
  int _swaps = 0;

  OrderSpec get spec => widget.ctx.spec as OrderSpec;
  bool get _puzzle => spec.kind == 'puzzle';

  @override
  void initState() {
    super.initState();
    _layout = [...spec.start];
  }

  @override
  void didUpdateWidget(OrderItemView old) {
    super.didUpdateWidget(old);
    if (old.ctx.locked && !widget.ctx.locked) {
      setState(() {
        _built.clear();
        _layout = [...spec.start];
      });
    }
  }

  void _tapLetter(String id) {
    if (widget.ctx.locked) return;
    HapticFeedback.selectionClick();
    widget.ctx.sound(Sfx.tap);
    setState(() => _built.add(id));
    widget.ctx.speak(spec.piece(id).label.of());
    if (_built.length == spec.order.length) {
      widget.ctx.submit(OrderAnswer([..._built]));
    }
  }

  void _tapPiece(String id) {
    if (widget.ctx.locked) return;
    if (_first == null) {
      widget.ctx.sound(Sfx.tap);
      setState(() => _first = id);
      return;
    }
    if (_first == id) {
      setState(() => _first = null);
      return;
    }
    final a = _layout.indexOf(_first!), b = _layout.indexOf(id);
    setState(() {
      _layout[a] = id;
      _layout[b] = _first!;
      _first = null;
      _swaps++;
    });
    HapticFeedback.lightImpact();
    widget.ctx.sound(Sfx.snap);
    if (_layout.join('|') == spec.order.join('|')) {
      // Swaps beyond what was needed count as small mistakes.
      final minSwaps =
          spec.start
              .asMap()
              .entries
              .where((e) => spec.order[e.key] != e.value)
              .length -
          1;
      widget.ctx.submit(
        OrderAnswer([..._layout], mistakes: (_swaps - minSwaps).clamp(0, 99)),
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      _puzzle ? _buildPuzzle(context) : _buildWord(context);

  Widget _buildWord(BuildContext context) {
    final pool = spec.start.where((id) => !_built.contains(id)).toList();
    final reveal = widget.ctx.hint.reveal;
    final nextRight = _built.length < spec.order.length
        ? spec.order[_built.length]
        : null;
    final solution = widget.ctx.solution is OrderAnswer
        ? (widget.ctx.solution! as OrderAnswer).ids
        : null;
    final slots = solution ?? _built;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (spec.picture != null)
          PictureView(spec.picture!, size: Sizes.kidsArtLg * 0.7),
        const SizedBox(height: Space.s5),
        Semantics(
          container: true,
          label:
              'Your word: ${_built.map((i) => spec.piece(i).label.of()).join()}',
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < spec.order.length; i++)
                  GestureDetector(
                    onTap: !widget.ctx.locked && i == _built.length - 1
                        ? () => setState(_built.removeLast)
                        : null,
                    child: Container(
                      width: Sizes.tapKidsXl * 0.8,
                      height: Sizes.tapKidsXl,
                      margin: const EdgeInsets.all(Space.s2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i < slots.length
                            ? AppColors.kidsLearnSoft
                            : AppColors.kidsSurface,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.kidsInk,
                            width: Space.s2,
                          ),
                        ),
                      ),
                      child: Text(
                        i < slots.length ? spec.piece(slots[i]).label.of() : '',
                        style: KidsText.display,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.s8),
        Wrap(
          spacing: Space.s5,
          runSpacing: Space.s5,
          alignment: WrapAlignment.center,
          children: [
            for (final id in pool)
              AnswerTile(
                choice: spec.piece(id),
                glyph: true,
                size: Sizes.tapKidsXl,
                state:
                    reveal.isNotEmpty &&
                        spec.piece(id).label.of() ==
                            (nextRight == null
                                ? null
                                : spec.piece(nextRight).label.of())
                    ? TileState.highlighted
                    : TileState.idle,
                onPressed: widget.ctx.locked ? null : () => _tapLetter(id),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPuzzle(BuildContext context) {
    final cols = spec.columns;
    final reveal = widget.ctx.hint.reveal;
    final layout = widget.ctx.solution is OrderAnswer
        ? (widget.ctx.solution! as OrderAnswer).ids
        : _layout;
    if (cols == 0) {
      // ordering puzzle with labelled pieces: tap two to swap
      return Wrap(
        spacing: Space.s4,
        runSpacing: Space.s4,
        alignment: WrapAlignment.center,
        children: [
          for (final id in layout)
            AnswerTile(
              choice: spec.piece(id),
              size: Sizes.tapKidsXl + Space.s7,
              state: id == _first
                  ? TileState.selected
                  : (reveal.contains(id)
                        ? TileState.highlighted
                        : TileState.idle),
              onPressed: widget.ctx.locked ? null : () => _tapPiece(id),
            ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final side = (c.maxWidth.clamp(0.0, Sizes.kidsArtLg * 1.6)).toDouble();
        final cell = side / cols;
        return SizedBox.square(
          dimension: side,
          child: GridView.count(
            crossAxisCount: cols,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final (pos, id) in layout.indexed)
                Semantics(
                  container: true,
                  button: true,
                  label:
                      'Piece ${spec.order.indexOf(id) + 1}, in place ${pos + 1}${id == _first ? ', picked' : ''}',
                  excludeSemantics: true,
                  onTap: widget.ctx.locked ? null : () => _tapPiece(id),
                  child: GestureDetector(
                    onTap: widget.ctx.locked ? null : () => _tapPiece(id),
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      margin: const EdgeInsets.all(Space.s1),
                      decoration: BoxDecoration(
                        color: AppColors.kidsSurface,
                        border: Border.all(
                          color: id == _first || reveal.contains(id)
                              ? AppColors.kidsLearnInk
                              : AppColors.kidsLine,
                          width: id == _first || reveal.contains(id)
                              ? Space.s2
                              : Space.s1,
                        ),
                      ),
                      child: PictureSlice(
                        picture: spec.picture!,
                        index: spec.order.indexOf(id),
                        grid: cols,
                        size: cell,
                      ),
                    ),
                  ),
                ),
            ].map((w) => SizedBox.square(dimension: cell, child: w)).toList(),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Memory: turn two cards; pairs stay open
// ---------------------------------------------------------------------------------------------

class MemoryItemView extends StatefulWidget {
  const MemoryItemView({super.key, required this.ctx});

  final ItemViewContext ctx;

  @override
  State<MemoryItemView> createState() => _MemoryItemViewState();
}

class _MemoryItemViewState extends State<MemoryItemView> {
  final _found = <String>{}; // pair ids
  final _open = <String>[]; // card ids face up right now (max 2)
  int _flips = 0;
  Timer? _closeTimer;

  /// The Memory Match clock: starts on the first card, stops while paused.
  final _clock = Stopwatch();
  Timer? _tick;

  MemorySpec get spec => widget.ctx.spec as MemorySpec;

  @override
  void didUpdateWidget(MemoryItemView old) {
    super.didUpdateWidget(old);
    if (widget.ctx.paused || widget.ctx.locked) {
      _clock.stop();
    } else if (_flips > 0 || _open.isNotEmpty) {
      _clock.start();
    }
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _startClock() {
    if (!spec.timer || _clock.isRunning) return;
    _clock.start();
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _clock.isRunning) setState(() {});
    });
  }

  void _tap(Choice card) {
    if (widget.ctx.locked ||
        _open.length == 2 ||
        _open.contains(card.id) ||
        _found.contains(MemorySpec.pairOf(card.id))) {
      return;
    }
    HapticFeedback.selectionClick();
    _startClock();
    widget.ctx.sound(Sfx.flip);
    setState(() => _open.add(card.id));
    widget.ctx.speak(card.spoken());
    if (_open.length < 2) return;
    setState(() => _flips++);
    final a = MemorySpec.pairOf(_open[0]), b = MemorySpec.pairOf(_open[1]);
    if (a == b) {
      widget.ctx.sound(Sfx.match);
      setState(() {
        _found.add(a);
        _open.clear();
      });
      if (_found.length == spec.pairs) {
        _clock.stop();
        _tick?.cancel();
        widget.ctx.submit(
          MemoryAnswer(
            flips: _flips,
            pairsFound: _found.length,
            timeMs: spec.timer ? _clock.elapsedMilliseconds : null,
          ),
        );
      }
    } else {
      _closeTimer = Timer(Motion.slow * 2, () {
        if (mounted) setState(_open.clear);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reveal = widget.ctx.hint.reveal;
    return LayoutBuilder(
      builder: (context, c) {
        // The whole board must fit on one screen (a child can't scroll mid-game): on short
        // screens (phones held sideways) use more columns and fewer rows.
        final n = spec.cards.length;
        // Phones held sideways: smaller (still ≥ 64 dp) cards and tighter gaps, so even the
        // 16-card board fits without scrolling.
        final short = MediaQuery.sizeOf(context).height < Sizes.kidsShortScreen;
        final gap = short ? Space.s4 : Space.s5;
        final minCard = short ? Sizes.tapKids : Sizes.tapKidsXl;
        final room =
            MediaQuery.sizeOf(context).height -
            Sizes.kidsHeroH - // top bar + prompt
            Sizes.tapKidsSecondary; // moves and clock
        final maxRows = ((room + gap) / (minCard + gap)).floor().clamp(1, n);
        var cols = n <= 4 ? 2 : (n <= 6 ? 3 : 4);
        if ((n / cols).ceil() > maxRows) cols = (n / maxRows).ceil();
        final rows = (n / cols).ceil();
        final byWidth = (c.maxWidth - gap * (cols - 1)) / cols;
        final byHeight = (room - gap * (rows - 1)) / rows;
        final size = (byWidth < byHeight ? byWidth : byHeight).clamp(
          minCard,
          Sizes.kidsBuddyTile,
        );
        final board = Wrap(
          spacing: gap,
          runSpacing: gap,
          alignment: WrapAlignment.center,
          children: [
            for (final (i, card) in spec.cards.indexed)
              () {
                final faceUp =
                    _open.contains(card.id) ||
                    _found.contains(MemorySpec.pairOf(card.id));
                final face = faceUp
                    ? AnswerTile(
                        choice: card,
                        size: size,
                        state: _found.contains(MemorySpec.pairOf(card.id))
                            ? TileState.correct
                            : TileState.selected,
                        onPressed: null,
                      )
                    : Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          color: reveal.contains(card.id)
                              ? AppColors.kidsSuccessFill
                              : AppColors.kidsLearnFill,
                          borderRadius: BorderRadius.circular(Radii.xl),
                          boxShadow: Shadows.kidRaised,
                        ),
                        child: const Icon(
                          Icons.question_mark_rounded,
                          color: AppColors.kidsInk,
                          size: Sizes.iconKids,
                        ),
                      );
                return Semantics(
                  container: true,
                  button: !faceUp,
                  label: faceUp ? card.spoken() : 'Card ${i + 1}, face down',
                  excludeSemantics: true,
                  onTap: faceUp ? null : () => _tap(card),
                  child: GestureDetector(
                    onTap: () => _tap(card),
                    child: FlipCard(faceUp: faceUp, child: face),
                  ),
                );
              }(),
          ],
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MemoryStats(
              moves: _flips,
              pairsLeft: spec.pairs - _found.length,
              time: spec.timer ? _clock.elapsed : null,
            ),
            const SizedBox(height: Space.s3),
            // Exactly [cols] cards per row, so rows come out even (4 × 4, not 9 + 7).
            SizedBox(width: cols * size + (cols - 1) * gap, child: board),
          ],
        );
      },
    );
  }
}

/// Moves, pairs left and (Memory Match) the clock, above the board.
class MemoryStats extends StatelessWidget {
  const MemoryStats({
    super.key,
    required this.moves,
    required this.pairsLeft,
    this.time,
  });

  final int moves;
  final int pairsLeft;
  final Duration? time;

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, String text) => Container(
      constraints: const BoxConstraints(
        minHeight: Sizes.tapKidsSecondary - Space.s3,
      ),
      padding: const EdgeInsets.symmetric(horizontal: Space.s5),
      decoration: BoxDecoration(
        color: AppColors.kidsSurface,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: AppColors.kidsLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Sizes.iconMd, color: AppColors.kidsInkMuted),
          const SizedBox(width: Space.s2),
          Text(text, style: KidsText.label),
        ],
      ),
    );
    final t = time;
    final clock = t == null
        ? null
        : '${t.inMinutes}:${(t.inSeconds % 60).toString().padLeft(2, '0')}';
    return Semantics(
      container: true,
      label:
          '$moves ${moves == 1 ? 'move' : 'moves'}, $pairsLeft '
          '${pairsLeft == 1 ? 'pair' : 'pairs'} left${clock == null ? '' : ', time $clock'}',
      excludeSemantics: true,
      child: Wrap(
        spacing: Space.s4,
        runSpacing: Space.s2,
        alignment: WrapAlignment.center,
        children: [
          chip(Icons.touch_app_rounded, '$moves'),
          chip(Icons.style_rounded, '$pairsLeft left'),
          if (clock != null) chip(Icons.timer_outlined, clock),
        ],
      ),
    );
  }
}

/// Turns a card over with a quick 3D flip (a cross-fade when "reduce motion" is on).
class FlipCard extends StatelessWidget {
  const FlipCard({super.key, required this.faceUp, required this.child});

  final bool faceUp;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return AnimatedSwitcher(
        duration: Motion.fast,
        child: KeyedSubtree(key: ValueKey(faceUp), child: child),
      );
    }
    return AnimatedSwitcher(
      duration: Motion.base,
      transitionBuilder: (child, anim) => AnimatedBuilder(
        animation: anim,
        child: child,
        builder: (context, c) {
          // The incoming face turns from edge-on (90°) to flat; the old one fades under it.
          final angle = (1 - anim.value) * math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: c,
          );
        },
      ),
      layoutBuilder: (current, previous) =>
          Stack(alignment: Alignment.center, children: [current!]),
      child: KeyedSubtree(key: ValueKey(faceUp), child: child),
    );
  }
}

/// `3 + 2 = ?` with the things to count: two groups for adding; for taking away, one group with
/// the ones that "go away" faded and crossed out.
class EquationView extends StatelessWidget {
  const EquationView(this.eq, {super.key});

  final Equation eq;

  @override
  Widget build(BuildContext context) {
    final pic = eq.picture;
    final small = Sizes.tapKids * 0.8;
    Widget group(int n, {int gone = 0}) => Container(
      constraints: BoxConstraints(minWidth: small, minHeight: small),
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(
        color: AppColors.kidsSurface,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: small * 5),
        child: Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < n; i++)
              i >= n - gone
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Opacity(
                          opacity: 0.3,
                          child: PictureView(pic!, size: small),
                        ),
                        Icon(
                          Icons.close_rounded,
                          size: small * 0.8,
                          color: AppColors.kidsPlayInk,
                        ),
                      ],
                    )
                  : PictureView(pic!, size: small),
          ],
        ),
      ),
    );
    Widget sign(String t) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.s3),
      child: Text(t, style: KidsText.display),
    );
    return Semantics(
      container: true,
      label: eq.spoken,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: Space.s4),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: Space.s3,
          children: [
            if (pic != null) ...[
              if (eq.op == '-')
                group(eq.a, gone: eq.b)
              else ...[
                group(eq.a),
                sign('+'),
                group(eq.b),
              ],
              sign('='),
              sign('?'),
            ] else ...[
              sign('${eq.a}'),
              sign(eq.op == '-' ? '−' : '+'),
              sign('${eq.b}'),
              sign('='),
              sign('?'),
            ],
          ],
        ),
      ),
    );
  }
}
