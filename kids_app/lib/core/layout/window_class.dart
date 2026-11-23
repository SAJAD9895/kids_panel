import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/tokens.g.dart';

/// Material 3 window classes (docs/design/README.md §4).
enum WindowClass {
  compact,
  medium,
  expanded,
  large,
  xlarge;

  static WindowClass ofWidth(double width) {
    if (width >= Breakpoints.xlarge) return WindowClass.xlarge;
    if (width >= Breakpoints.large) return WindowClass.large;
    if (width >= Breakpoints.expanded) return WindowClass.expanded;
    if (width >= Breakpoints.medium) return WindowClass.medium;
    return WindowClass.compact;
  }

  static WindowClass of(BuildContext context) =>
      ofWidth(MediaQuery.sizeOf(context).width);

  bool get isAtLeastMedium => index >= WindowClass.medium.index;
  bool get isAtLeastExpanded => index >= WindowClass.expanded.index;
}

/// Which way a screen group wants a phone held (docs/design/README.md §4.1–4.2).
enum OrientationPolicy {
  /// Kids Area on phones: landscape.
  kids,

  /// Grown-up forms and the Parents Area on phones: portrait.
  grownUps,
}

/// Applies an [OrientationPolicy] on phones only. Tablets, desktops and the web keep every
/// orientation (iPad multitasking can't be forced, and browsers ignore it anyway).
class OrientationScope extends StatefulWidget {
  const OrientationScope({
    super.key,
    required this.policy,
    required this.child,
  });

  final OrientationPolicy policy;
  final Widget child;

  @override
  State<OrientationScope> createState() => _OrientationScopeState();
}

class _OrientationScopeState extends State<OrientationScope> {
  OrientationPolicy? _applied;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isPhone =
        MediaQuery.sizeOf(context).shortestSide < Breakpoints.medium;
    final want = isPhone ? widget.policy : null;
    if (want == _applied) return;
    _applied = want;
    SystemChrome.setPreferredOrientations(switch (want) {
      OrientationPolicy.kids => const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      OrientationPolicy.grownUps => const [DeviceOrientation.portraitUp],
      null => const [],
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
