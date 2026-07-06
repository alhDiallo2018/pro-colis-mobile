import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Onglet du dashboard actuellement sélectionné.
///
/// Partagé afin que la barre de navigation persistante (`AppBottomNav`),
/// présente sur toutes les pages, puisse revenir au dashboard racine et
/// sélectionner le bon onglet depuis n'importe quelle page poussée.
final dashboardTabProvider = StateProvider<int>((ref) => 0);
