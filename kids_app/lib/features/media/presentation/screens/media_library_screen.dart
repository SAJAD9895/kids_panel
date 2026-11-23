import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../child_profiles/presentation/child_providers.dart';
import '../../../kids_home/presentation/widgets/kids_shell.dart';
import '../../../learning/domain/catalog.dart';
import '../../../learning/domain/progress.dart';
import '../../../learning/presentation/learning_providers.dart';
import '../../../learning/presentation/widgets/kid_widgets.dart';
import '../../../learning/presentation/widgets/kids_content.dart';
import '../../domain/media.dart';
import '../media_providers.dart';
import '../widgets/media_thumb.dart';
import '../widgets/media_widgets.dart';

/// K12 Watch and K14 Listen: the video library, and the songs + stories library. One screen,
/// two sections: featured, continue, recommended, recently played, the curated rows, every
/// category; search and filters (category, subject, short ones).
class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen({super.key, required this.surface});

  /// `watch` or `listen`.
  final String surface;

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  final _search = TextEditingController();
  var _filter = const MediaFilter();

  bool get _watch => widget.surface == 'watch';

  bool _inSection(ActivitySummary a) => _watch
      ? a.type == ActivityType.video
      : a.type == ActivityType.song ||
            a.type == ActivityType.story ||
            a.type == ActivityType.audiobook;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final childId = ref.watch(selectedChildIdProvider);
    final positions = childId == null
        ? const <String, ResumePoint>{}
        : ref.watch(mediaPositionsProvider(childId)).value ?? const {};
    final title = _watch ? 'Watch' : 'Listen';
    return KidsContent(
      header: KidsTopBar(title: title, showBack: false),
      builder: (context, d) {
        final on = _watch
            ? d.progress.sections.watch
            : d.progress.sections.listen;
        if (!on) {
          return [
            const SizedBox(height: Space.s9),
            const KidsEmpty(
              title: 'Not today',
              message: 'A grown-up switched this off.',
            ),
          ];
        }
        final all = d.catalog.activities
            .where(_inSection)
            .where(d.canSee)
            .toList();
        if (all.isEmpty) {
          return [
            KidsEmpty(
              title: 'Nothing here yet',
              message:
                  'New ${_watch ? 'shows' : 'songs and stories'} are on their way!',
            ),
          ];
        }
        final cats = [
          for (final c in d.catalog.categories)
            if (all.any((a) => a.categoryId == c.id)) c,
        ];
        final subjects = [
          for (final s in d.catalog.subjects)
            if (all.any((a) => a.subjectId == s.id)) s,
        ];
        return [
          const SizedBox(height: Space.s5),
          _SearchBar(
            controller: _search,
            hint: _watch ? 'Find a video' : 'Find a song or story',
            onChanged: (q) =>
                setState(() => _filter = _filter.copyWith(query: q)),
          ),
          const SizedBox(height: Space.s4),
          _Chips(
            label: 'Categories',
            children: [
              for (final c in cats)
                PillChoice(
                  label: c.name.of(),
                  semanticLabel: 'Category ${c.name.of()}',
                  selected: _filter.categoryId == c.id,
                  onSelected: () => setState(
                    () => _filter = _filter.categoryId == c.id
                        ? _filter.copyWith(clearCategory: true)
                        : _filter.copyWith(categoryId: c.id),
                  ),
                ),
            ],
          ),
          _Chips(
            label: 'Subjects',
            children: [
              for (final s in subjects)
                PillChoice(
                  label: s.name.of(),
                  semanticLabel: 'Subject ${s.name.of()}',
                  fill: AppColors.kidsLearnFill,
                  selected: _filter.subjectId == s.id,
                  onSelected: () => setState(
                    () => _filter = _filter.subjectId == s.id
                        ? _filter.copyWith(clearSubject: true)
                        : _filter.copyWith(subjectId: s.id),
                  ),
                ),
              PillChoice(
                label: 'Short ones',
                semanticLabel: 'Only short ones, 1 minute or less',
                fill: AppColors.kidsListenFill,
                selected: _filter.maxMinutes != null,
                onSelected: () => setState(
                  () => _filter = _filter.maxMinutes != null
                      ? _filter.copyWith(clearLength: true)
                      : _filter.copyWith(maxMinutes: 1),
                ),
              ),
            ],
          ),
          if (!_filter.isEmpty)
            ..._results(d, all)
          else
            ..._library(d, all, cats, positions),
        ];
      },
    );
  }

  List<Widget> _results(KidsData d, List<ActivitySummary> all) {
    final found = [
      for (final a in all)
        if (_filter.matches(
          a,
          subjectName: d.catalog.subject(a.subjectId)?.name.of(),
          categoryName: d.catalog.category(a.categoryId)?.name.of(),
        ))
          a,
    ];
    return [
      ShelfTitle(
        found.isEmpty ? 'Nothing found' : '${found.length} found',
        action: KidsIconButton(
          icon: Icons.close_rounded,
          label: 'Clear search',
          onPressed: () => setState(() {
            _search.clear();
            _filter = const MediaFilter();
          }),
        ),
      ),
      if (found.isEmpty)
        Semantics(
          liveRegion: true,
          child: Text(
            'Try another word, or clear the search.',
            style: KidsText.body.copyWith(color: AppColors.kidsInkMuted),
          ),
        )
      else
        // A Wrap inside the page's lazy list: rows build as they scroll into view.
        Wrap(
          spacing: Space.s6,
          runSpacing: Space.s6,
          children: [
            for (final a in found)
              ActivityCard(activity: a, locked: d.locked(a)),
          ],
        ),
    ];
  }

  List<Widget> _library(
    KidsData d,
    List<ActivitySummary> all,
    List<Category> cats,
    Map<String, ResumePoint> positions,
  ) {
    final c = d.catalog;
    final featured = [
      for (final col in c.collections)
        if (col.surface == widget.surface && col.kind == 'drop')
          for (final id in col.activityIds)
            ?all.where((a) => a.id == id).firstOrNull,
    ];
    final continuing = MediaRules.continueList(all, positions);
    final recentIds = [for (final r in d.progress.recent) r.activityId];
    final recent = [
      for (final id in recentIds) ?all.where((a) => a.id == id).firstOrNull,
    ];
    final recommended = MediaRules.recommended(
      all,
      ageMonths: d.ageMonths,
      recentlyPlayed: recentIds.toSet(),
    );
    final rows = [
      for (final col in c.collections)
        if (col.surface == widget.surface && col.kind == 'row')
          (
            col.title.of(),
            [
              for (final id in col.activityIds)
                ?all.where((a) => a.id == id).firstOrNull,
            ],
          ),
    ].where((r) => r.$2.isNotEmpty);
    Widget shelf(
      List<ActivitySummary> items, {
      Map<String, ResumePoint> p = const {},
    }) => MediaShelf(items: items, progress: p, locked: d.locked);
    return [
      if (featured.isNotEmpty) ...[
        const SizedBox(height: Space.s6),
        _Featured(activity: featured.first, locked: d.locked(featured.first)),
      ],
      if (!_watch) const _NowPlayingCard(),
      if (continuing.isNotEmpty) ...[
        ShelfTitle(_watch ? 'Keep watching' : 'Keep reading and listening'),
        shelf(
          [for (final x in continuing) x.$1],
          p: {for (final x in continuing) x.$1.id: x.$2},
        ),
      ],
      ShelfTitle(_watch ? 'Picked for you' : 'Picked for you'),
      shelf(recommended),
      if (recent.isNotEmpty) ...[
        ShelfTitle(_watch ? 'Watched lately' : 'Played lately'),
        shelf(recent),
      ],
      for (final (title, items) in rows) ...[ShelfTitle(title), shelf(items)],
      for (final cat in cats) ...[
        ShelfTitle(cat.name.of()),
        shelf([
          for (final a in all)
            if (a.categoryId == cat.id) a,
        ]),
      ],
      const SizedBox(height: Space.s7),
      Center(
        child: CharacterArt(
          _watch ? Character.nova : Character.pip,
          size: Sizes.kidsBuddyTile,
          mood: Mood.happy,
        ),
      ),
    ];
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: Sizes.uiContentMax * 0.6),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: KidsText.body,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: Sizes.iconKids),
        filled: true,
        fillColor: AppColors.kidsSurface,
        constraints: const BoxConstraints(minHeight: Sizes.tapKids),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.pill),
          borderSide: const BorderSide(color: AppColors.kidsLine),
        ),
      ),
    ),
  );
}

class _Chips extends StatelessWidget {
  const _Chips({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => children.isEmpty
      ? const SizedBox.shrink()
      : Semantics(
          container: true,
          label: label,
          child: Padding(
            padding: const EdgeInsets.only(bottom: Space.s4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: Space.s4),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        );
}

/// The big featured card at the top: thumbnail, title, one Play button.
class _Featured extends StatelessWidget {
  const _Featured({required this.activity, required this.locked});

  final ActivitySummary activity;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    return CardTap(
      semanticLabel:
          'Featured: ${typeLabel(a.type)}, ${a.title.of()}${locked ? ', ask a grown-up' : ''}',
      onPressed: () => context.push(Routes.open(a.id, a.type.name)),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= Sizes.kidsCardW * 2.5;
          final art = AspectRatio(
            aspectRatio: 16 / 9,
            child: a.thumbnail == null
                ? ColoredBox(
                    color: AppColors.kidsBgAlt,
                    child: Center(child: ActivityArt(a)),
                  )
                : MediaThumb(
                    path: a.thumbnail!,
                    width: wide ? c.maxWidth / 2 : c.maxWidth,
                  ),
          );
          final info = Padding(
            padding: const EdgeInsets.all(Space.s6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TypeChip(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Featured',
                  ink: AppColors.kidsPlayInk,
                ),
                const SizedBox(height: Space.s3),
                Text(a.title.of(), style: KidsText.title),
                if (!a.description.isEmpty) ...[
                  const SizedBox(height: Space.s2),
                  Text(
                    a.description.of(),
                    style: KidsText.body.copyWith(
                      color: AppColors.kidsInkMuted,
                    ),
                  ),
                ],
                const SizedBox(height: Space.s5),
                ExcludeSemantics(
                  child: KidsButton(
                    label: locked
                        ? 'Ask a grown-up'
                        : (a.type == ActivityType.story ? 'Read' : 'Play'),
                    icon: locked
                        ? Icons.lock_rounded
                        : Icons.play_arrow_rounded,
                    fill: AppColors.kidsMeFill,
                    onPressed: () =>
                        context.push(Routes.open(a.id, a.type.name)),
                  ),
                ),
              ],
            ),
          );
          return wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: art),
                    Expanded(child: info),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [art, info],
                );
        },
      ),
    );
  }
}

/// Listen: the song playing now (it keeps playing while the child browses).
class _NowPlayingCard extends ConsumerWidget {
  const _NowPlayingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(audioProvider);
    if (!a.active || a.currentId == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Space.s6),
      child: CardTap(
        semanticLabel: 'Now playing: ${a.title}. Open the player',
        onPressed: () => context.push(Routes.song(a.currentId!)),
        child: Padding(
          padding: const EdgeInsets.all(Space.s5),
          child: Row(
            children: [
              const Icon(
                Icons.music_note_rounded,
                size: Sizes.iconKids,
                color: AppColors.kidsListenInk,
              ),
              const SizedBox(width: Space.s4),
              Expanded(
                child: Text(
                  'Now playing: ${a.title}',
                  style: KidsText.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                a.snapshot.playing
                    ? Icons.graphic_eq_rounded
                    : Icons.pause_rounded,
                color: AppColors.kidsListenInk,
                size: Sizes.iconKids,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
