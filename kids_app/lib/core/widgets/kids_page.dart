import 'package:flutter/material.dart';

import '../layout/window_class.dart';
import '../theme/app_theme.dart';

/// Frame for kid-zone screens: warm background, safe areas as padding, gutters by window
/// class, and the phone orientation for the screen group.
class KidsPage extends StatelessWidget {
  const KidsPage({
    super.key,
    required this.child,
    this.orientation = OrientationPolicy.kids,
    this.background = AppColors.kidsBg,
    this.scrollable = true,
  });

  final Widget child;
  final OrientationPolicy orientation;
  final Color background;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final wc = WindowClass.of(context);
    final gutter = switch (wc) {
      WindowClass.compact => Space.s6,
      WindowClass.medium => Space.s8,
      _ => Space.s11,
    };
    final padding = EdgeInsets.symmetric(
      horizontal: gutter,
      vertical: wc.isAtLeastExpanded ? Space.s9 : Space.s6,
    );
    return OrientationScope(
      policy: orientation,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Sizes.uiContentMax + Space.s12 * 3,
              ),
              child: scrollable
                  ? SingleChildScrollView(padding: padding, child: child)
                  : Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
