import '../../../media/presentation/screens/audio_screens.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../core/art/characters.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/kids_controls.dart';
import '../../../child_profiles/presentation/child_providers.dart';
import '../../../learning/domain/progress.dart';
import '../../../learning/presentation/learning_providers.dart';
import '../../../learning/presentation/widgets/kid_widgets.dart';

/// One rail item (docs/design/README.md §2.1).
class _RailItem {
  const _RailItem(this.label, this.icon, this.route, this.palette);

  final String label;
  final IconData icon;
  final String route;
  final SectionPalette palette;
}

const _home = _RailItem(
  'Home',
  Icons.home_rounded,
  Routes.kids,
  SectionPalette.play,
);
const _learn = _RailItem(
  'Learn',
  Icons.menu_book_rounded,
  Routes.learn,
  SectionPalette.learn,
);
const _watch = _RailItem(
  'Watch',
  Icons.tv_rounded,
  Routes.watch,
  SectionPalette.watch,
);
const _listen = _RailItem(
  'Listen',
  Icons.headphones_rounded,
  Routes.listen,
  SectionPalette.listen,
);
const _me = _RailItem(
  'Me',
  Icons.sentiment_satisfied_alt_rounded,
  Routes.me,
  SectionPalette.me,
);

/// Which rail item a path belongs to.
_RailItem _current(String path) {
  if (path.startsWith(Routes.learn) ||
      path.startsWith('${Routes.kids}/paths') ||
      path.startsWith(Routes.courses)) {
    return _learn;
  }
  if (path.startsWith(Routes.watch)) return _watch;
  if (path.startsWith(Routes.listen)) return _listen;
  if (path.startsWith(Routes.me)) return _me;
  return _home;
}

/// The Kids Area frame: a left rail on wide windows, a bottom bar on narrow portrait ones
/// (design README §4.1). Sections the parent switched off disappear (§2.3). Back on the
/// rail roots does nothing, so a child can't leave the app by accident.
class KidsShell extends ConsumerWidget {
  const KidsShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childId = ref.watch(selectedChildIdProvider);
    final sections = childId == null
        ? const SectionSwitches()
        : ref.watch(childProgressProvider(childId)).value?.sections ??
              const SectionSwitches();
    final items = [
      _home,
      if (sections.learn) _learn,
      if (sections.watch) _watch,
      if (sections.listen) _listen,
      _me,
    ];
    final current = _current(location);
    final size = MediaQuery.sizeOf(context);
    final useRail =
        size.width >= Breakpoints.medium || size.width > size.height;
    final isRoot = items.any((i) => i.route == location);

    // A song keeps playing while the child browses: the mini player sits under the page.
    final body = OrientationScope(
      policy: OrientationPolicy.kids,
      child: Column(
        children: [
          Expanded(child: child),
          const MiniPlayer(),
        ],
      ),
    );
    return PopScope(
      canPop: !isRoot,
      child: Scaffold(
        backgroundColor: AppColors.kidsBg,
        body: useRail
            ? Row(
                children: [
                  _Rail(
                    items: items,
                    current: current,
                    compact: size.width < Breakpoints.expanded,
                  ),
                  Expanded(child: body),
                ],
              )
            : body,
        bottomNavigationBar: useRail
            ? null
            : _BottomBar(items: items, current: current),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.items,
    required this.current,
    required this.compact,
  });

  final List<_RailItem> items;
  final _RailItem current;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    width: compact ? Sizes.kidsRailW - Space.s7 : Sizes.kidsRailW,
    decoration: const BoxDecoration(
      color: AppColors.kidsSurface,
      border: Border(
        right: BorderSide(color: AppColors.kidsLine, width: Space.s1),
      ),
    ),
    child: SafeArea(
      right: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: Space.s5),
        child: Column(
          children: [
            const ChildAvatarButton(),
            const SizedBox(height: Space.s5),
            for (final i in items) ...[
              _RailButton(item: i, selected: i == current, showLabel: !compact),
              const SizedBox(height: Space.s4),
            ],
          ],
        ),
      ),
    ),
  );
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.items, required this.current});

  final List<_RailItem> items;
  final _RailItem current;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.kidsSurface,
      border: Border(
        top: BorderSide(color: AppColors.kidsLine, width: Space.s1),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final i in items)
              _RailButton(item: i, selected: i == current, showLabel: true),
          ],
        ),
      ),
    ),
  );
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.selected,
    required this.showLabel,
  });

  final _RailItem item;
  final bool selected;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final tile = AnimatedContainer(
      duration: Motion.base,
      // a bouncy curve would overshoot the shadow blur below zero
      curve: Motion.easeStandard,
      width: Sizes.tapKidsSecondary + (selected ? Space.s3 : 0),
      height: Sizes.tapKidsSecondary + (selected ? Space.s3 : 0),
      decoration: BoxDecoration(
        color: selected ? item.palette.fill : item.palette.soft,
        borderRadius: BorderRadius.circular(Radii.xl),
        boxShadow: selected ? Shadows.kidRaised : null,
      ),
      child: Icon(
        item.icon,
        size: Sizes.iconKids,
        color: selected ? AppColors.kidsInk : item.palette.ink,
      ),
    );
    void go() => context.go(item.route);
    return AnimatedContainer(
      duration: Motion.base,
      curve: Motion.easeStandard,
      padding: const EdgeInsets.all(Space.s2),
      decoration: BoxDecoration(
        color: selected ? item.palette.soft : null,
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      child: showLabel
          ? TileWithCaption(
              label: item.label,
              onPressed: go,
              tile: tile,
              selected: selected,
            )
          : Semantics(
              container: true,
              button: true,
              selected: selected,
              label: item.label,
              excludeSemantics: true,
              onTap: go,
              child: GestureDetector(onTap: go, child: tile),
            ),
    );
  }
}

/// The child's buddy at the top of the rail (or in the header on phones). Opens the player
/// switcher (F-023).
class ChildAvatarButton extends ConsumerWidget {
  const ChildAvatarButton({super.key, this.size = Sizes.tapKids + Space.s3});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(selectedChildProvider);
    final art = ref.watch(buddyArtIndexProvider(child?.avatarId));
    return Semantics(
      container: true,
      button: true,
      label: '${child?.nickname ?? 'Player'}: switch player',
      excludeSemantics: true,
      onTap: () => showPlayerSwitcher(context),
      child: GestureDetector(
        onTap: () => showPlayerSwitcher(context),
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(Space.s2),
          decoration: const BoxDecoration(
            color: AppColors.kidsMeSoft,
            shape: BoxShape.circle,
          ),
          child: BuddyArt(art, size: size),
        ),
      ),
    );
  }
}

/// Bottom sheet with every child's buddy. Picking one switches the whole Kids Area to that
/// child's progress (providers are keyed by child id).
Future<void> showPlayerSwitcher(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.kidsSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.x2xl)),
      ),
      builder: (_) => const _PlayerSwitcher(),
    );

class _PlayerSwitcher extends ConsumerWidget {
  const _PlayerSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(childrenProvider).value ?? const [];
    final selected = ref.watch(selectedChildIdProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              container: true,
              header: true,
              child: Text("Who's playing?", style: KidsText.title),
            ),
            const SizedBox(height: Space.s7),
            Wrap(
              spacing: Space.s7,
              runSpacing: Space.s7,
              alignment: WrapAlignment.center,
              children: [
                for (final c in children.take(5))
                  SelectableTile(
                    selected: c.id == selected,
                    semanticLabel: c.nickname,
                    caption: c.nickname,
                    onPressed: () {
                      ref.read(selectedChildIdProvider.notifier).select(c.id);
                      Navigator.pop(context);
                      context.go(Routes.kids);
                    },
                    child: BuddyArt(
                      ref.watch(buddyArtIndexProvider(c.avatarId)),
                    ),
                  ),
              ],
            ),
            if (children.length <= 1) ...[
              const SizedBox(height: Space.s6),
              Text(
                'Grown-ups can add more players in the Grown-ups area.',
                style: KidsText.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Top bar of inner kid pages: back, title, stars, Grown-ups.
class KidsTopBar extends ConsumerWidget {
  const KidsTopBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.color,
  });

  final String title;
  final bool showBack;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childId = ref.watch(selectedChildIdProvider);
    // null while loading: the counter appears with the real number, never a false "0"
    final stars = childId == null
        ? null
        : ref.watch(childProgressProvider(childId)).value?.starsTotal;
    final narrow = MediaQuery.sizeOf(context).width < Breakpoints.medium;
    return Row(
      children: [
        if (showBack) ...[
          KidsIconButton(
            icon: Icons.arrow_back_rounded,
            label: 'Back',
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(Routes.kids),
          ),
          const SizedBox(width: Space.s5),
        ] else if (narrow) ...[
          const ChildAvatarButton(size: Sizes.tapKids),
          const SizedBox(width: Space.s4),
        ],
        Expanded(
          child: Semantics(
            container: true,
            header: true,
            child: Text(
              title,
              style: KidsText.title.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: Space.s4),
        if (!narrow && stars != null) ...[
          StarCounter(count: stars),
          const SizedBox(width: Space.s4),
        ],
        GrownUpsButton(onPressed: () => context.go(Routes.parents)),
      ],
    );
  }
}
