import 'package:flutter/widgets.dart';

import 'web_safe_image_io.dart'
    if (dart.library.html) 'web_safe_image_web.dart' as platform;

/// Affiche une image réseau sans subir les restrictions CORS du web.
///
/// Sur Flutter Web, `Image.network` charge l'image via XHR, ce qui exige des
/// en-têtes CORS que beaucoup d'hébergeurs tiers ne fournissent pas. Ce widget
/// utilise alors un élément HTML `<img>` (chargé directement, sans CORS), et
/// `Image.network` sur mobile.
class WebSafeNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  const WebSafeNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return platform.buildNetworkImage(
      url,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
