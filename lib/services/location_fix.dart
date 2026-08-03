// lib/services/location_fix.dart
//
// Récupération d'un point GPS, avec les garde-fous qui manquaient aux appels
// directs à `Geolocator.getCurrentPosition` :
//
//  - un délai maximum, sans lequel la future ne se résout jamais quand aucune
//    position n'arrive (cas classique d'un simulateur iOS sans localisation
//    simulée : le bouton reste bloqué sur son indicateur de chargement) ;
//  - un contrôle du service de localisation, pour distinguer « GPS coupé » de
//    « autorisation refusée » ;
//  - un message prêt à afficher, au lieu de l'exception brute.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Pourquoi la localisation a échoué — chaque cas appelle une action
/// différente de l'utilisateur.
enum LocationFailureKind {
  /// Localisation désactivée sur l'appareil (ou aucune position simulée).
  serviceDisabled,

  /// Autorisation refusée pour cette fois.
  permissionDenied,

  /// Autorisation refusée durablement : seuls les réglages système débloquent.
  permissionDeniedForever,

  /// Aucune position obtenue dans le délai imparti.
  timeout,

  /// Erreur inattendue de la plateforme.
  unknown,
}

class LocationFailure implements Exception {
  const LocationFailure(this.kind, this.message);

  final LocationFailureKind kind;

  /// Message en français, directement affichable.
  final String message;

  /// Vrai quand seul un passage par les réglages système peut débloquer.
  bool get needsSettings => kind == LocationFailureKind.permissionDeniedForever;

  @override
  String toString() => 'LocationFailure($kind): $message';
}

/// Délai au-delà duquel on renonce. Dix secondes couvrent une acquisition
/// normale sans laisser l'interface figée.
const Duration kLocationTimeLimit = Duration(seconds: 10);

/// Renvoie la position courante ou lève un [LocationFailure] explicite.
Future<Position> resolveCurrentPosition({
  Duration timeLimit = kLocationTimeLimit,
  LocationAccuracy accuracy = LocationAccuracy.high,
}) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationFailure(
      LocationFailureKind.serviceDisabled,
      'Localisation désactivée. Activez-la dans les réglages de l’appareil.',
    );
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw const LocationFailure(
      LocationFailureKind.permissionDeniedForever,
      'Accès à la position refusé. Autorisez-le dans les réglages de l’app.',
    );
  }
  if (permission == LocationPermission.denied) {
    throw const LocationFailure(
      LocationFailureKind.permissionDenied,
      'Accès à la position refusé.',
    );
  }

  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        timeLimit: timeLimit,
      ),
    );
  } on TimeoutException {
    throw const LocationFailure(
      LocationFailureKind.timeout,
      'Position introuvable. Vérifiez que la localisation est active, puis '
      'réessayez.',
    );
  } on LocationServiceDisabledException {
    // Le service peut être coupé entre la vérification et l'acquisition.
    throw const LocationFailure(
      LocationFailureKind.serviceDisabled,
      'Localisation désactivée. Activez-la dans les réglages de l’appareil.',
    );
  } on PermissionDeniedException {
    throw const LocationFailure(
      LocationFailureKind.permissionDenied,
      'Accès à la position refusé.',
    );
  } catch (error) {
    debugPrint('[location] Position indisponible: $error');
    throw const LocationFailure(
      LocationFailureKind.unknown,
      'Position indisponible pour le moment.',
    );
  }
}

/// Message à afficher pour n'importe quelle erreur remontée d'un appel GPS.
/// Évite d'exposer une exception brute à l'utilisateur.
String locationErrorMessage(Object error) => error is LocationFailure
    ? error.message
    : 'Position indisponible pour le moment.';
