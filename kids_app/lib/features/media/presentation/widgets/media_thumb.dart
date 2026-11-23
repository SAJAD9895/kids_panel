import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/theme/app_theme.dart';

/// A thumbnail or cover from the public bucket (or the bundle in demo mode), decoded at the
/// size shown. While it loads, and if it fails (offline), the card's own drawn art shows.
class MediaThumb extends ConsumerWidget {
  const MediaThumb({
    super.key,
    required this.path,
    required this.width,
    this.fallback,
    this.fit = BoxFit.cover,
    this.background = AppColors.kidsBgAlt,
  });

  /// `thumbs/<id>/1/512.webp` in public-assets.
  final String path;

  /// Logical width shown (decides the 256 / 512 file and the decode size).
  final double width;
  final Widget? fallback;
  final BoxFit fit;

  /// Behind the drawn art while loading or offline.
  final Color background;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref
        .watch(mediaUrlsProvider)
        .thumbnail(
          path,
          width: width,
          dpr: MediaQuery.devicePixelRatioOf(context),
        );
    final placeholder = ColoredBox(
      color: background,
      child: Center(child: fallback),
    );
    return ExcludeSemantics(
      child: Image(
        image: image,
        fit: fit,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, sync) =>
            frame == null && !sync ? placeholder : child,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}
