import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/layout/window_class.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../child_profiles/presentation/child_providers.dart';
import '../learning_providers.dart';
import 'kid_widgets.dart';

/// Scrollable page body for kid screens: gutters by window class, a centred max width, and
/// the shared loading (skeletons), error (Bolt + "Try again") handling for [kidsDataProvider].
class KidsContent extends ConsumerWidget {
  const KidsContent({
    super.key,
    required this.header,
    required this.builder,
    this.background,
  });

  final Widget header;
  final List<Widget> Function(BuildContext context, KidsData data) builder;
  final Color? background;

  static EdgeInsets padding(BuildContext context) {
    final wc = WindowClass.of(context);
    final h = switch (wc) {
      WindowClass.compact => Space.s6,
      WindowClass.medium => Space.s7,
      _ => Space.s9,
    };
    return EdgeInsets.fromLTRB(h, Space.s6, h, Space.s10);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(kidsDataProvider);
    final List<Widget> body = switch (data) {
      // While reloading (e.g. just after switching child) show skeletons, never the previous
      // child's data under the new child's name.
      AsyncValue(isLoading: true) => _loading,
      AsyncValue(:final value?) => builder(context, value),
      AsyncValue(hasError: true) => [
        const SizedBox(height: Space.s9),
        KidsErrorView(onRetry: () => refreshKidsData(ref)),
      ],
      _ => _loading,
    };
    return ColoredBox(
      color: background ?? AppColors.kidsBg,
      child: SafeArea(
        left: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Sizes.uiContentMax + Space.s12 * 3,
            ),
            child: ListView(
              // A new child starts at the top of the page, not where the last child left it.
              key: ValueKey(ref.watch(selectedChildIdProvider)),
              padding: padding(context),
              children: [header, ...body],
            ),
          ),
        ),
      ),
    );
  }
}

const _loading = <Widget>[
  SizedBox(height: Space.s7),
  LoadingRegion(
    child: Skeleton(height: Sizes.kidsHeroH, radius: Radii.x2xl),
  ),
  SizedBox(height: Space.s8),
  ShelfSkeleton(),
  SizedBox(height: Space.s8),
  ShelfSkeleton(),
];

/// A friendly "nothing here yet" for kid screens (never an error).
class KidsEmpty extends StatelessWidget {
  const KidsEmpty({super.key, required this.title, this.message, this.action});

  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.s8),
    child: EmptyStateView(
      kids: true,
      title: title,
      message: message,
      action: action,
    ),
  );
}
