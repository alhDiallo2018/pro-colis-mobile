// lib/utils/back_nav.dart
//
// Un `Navigator.pop` sur une page atteinte via deep-link n'a rien à
// dépiler : la pile GoRouter est vide. Résultat : l'utilisateur reste
// bloqué sur l'écran, ou pire, quitte l'app via la flèche système.
// Ce helper centralise le repli : si pas d'historique, va vers la page
// d'accueil raisonnable du rôle.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tente un pop natif ; si impossible, navigue vers `fallback`
/// (par défaut : `/dashboard`). Jamais d'exit implicite de l'app.
Future<void> safeBack(
  BuildContext context, {
  String fallback = '/dashboard',
}) async {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  if (context.mounted) {
    context.go(fallback);
  }
}

/// Variante retournant une valeur à l'appelant (utile pour les sheets).
/// Si pas de pile, replie sur `/dashboard`.
Future<void> safeBackWith<T>(
  BuildContext context,
  T? result, {
  String fallback = '/dashboard',
}) async {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop<T>(result);
    return;
  }
  if (context.mounted) {
    context.go(fallback);
  }
}
