import 'package:flutter/widgets.dart';

/// Where thumbnails and covers come from: the public bucket's CDN URL (Supabase) or the app
/// bundle (demo mode). Thumbnails come in 256 and 512 px; the smallest one that is sharp at the
/// size shown is used, and decoded at that size (memory), never the full file.
abstract class MediaUrls {
  const MediaUrls();

  /// The URL / asset key of a public-assets [path].
  String publicPath(String path);
  bool get isAsset;

  ImageProvider thumbnail(
    String path, {
    required double width,
    double dpr = 2,
  }) {
    final px = (width * dpr).ceil();
    final sized = px <= 256
        ? path.replaceFirst(RegExp(r'/512\.webp$'), '/256.webp')
        : path;
    final key = publicPath(sized);
    final base = isAsset ? AssetImage(key) as ImageProvider : NetworkImage(key);
    return ResizeImage(
      base,
      width: px,
      policy: ResizeImagePolicy.fit,
      allowUpscaling: false,
    );
  }
}

/// Demo mode: development media bundled under `assets/dev_media/<bucket>/<path>`.
class AssetMediaUrls extends MediaUrls {
  const AssetMediaUrls();
  @override
  bool get isAsset => true;
  @override
  String publicPath(String path) => 'assets/dev_media/public-assets/$path';
}

/// Supabase: `<project>/storage/v1/object/public/public-assets/<path>` (cached by the CDN; the
/// paths are versioned, so a new thumbnail never shows a stale one).
class PublicBucketUrls extends MediaUrls {
  const PublicBucketUrls(this.supabaseUrl);
  final String supabaseUrl;
  @override
  bool get isAsset => false;
  @override
  String publicPath(String path) =>
      '$supabaseUrl/storage/v1/object/public/public-assets/$path';
}
