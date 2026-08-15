import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

/// Registre une factory de platform view par URL unique. Réenregistrer une
/// factory à chaque rebuild fuiterait (le bandeau tourne toutes les 5 s) : on
/// mémorise donc le viewType par URL et on le réutilise.
final Map<String, String> _viewTypes = {};

Widget buildNetworkImage(
  String url, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  final viewType = _viewTypes.putIfAbsent(url, () {
    final type = 'procolis_web_image_${_viewTypes.length}';
    ui_web.platformViewRegistry.registerViewFactory(type, (int viewId) {
      final img = html.ImageElement()
        ..src = url
        ..alt = '';
      img.style
        ..width = '100%'
        ..height = '100%'
        ..setProperty('object-fit', _objectFit(fit));
      return img;
    });
    return type;
  });

  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(viewType: viewType),
  );
}

String _objectFit(BoxFit fit) {
  switch (fit) {
    case BoxFit.contain:
      return 'contain';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.none:
      return 'none';
    case BoxFit.scaleDown:
      return 'scale-down';
    case BoxFit.cover:
    default:
      return 'cover';
  }
}
