/// Parser d'étiquettes de colis — service pur, sans dépendance Flutter ni
/// package tiers. Prend du texte brut (fourni par ML Kit ou par un test) et
/// extrait les champs utiles pour pré-remplir le formulaire de création
/// de colis :
///
/// - nom destinataire
/// - téléphone destinataire (format sénégalais, avec ou sans +221)
/// - adresse destinataire
/// - poids en kg
///
/// Tous les champs sont **optionnels** : le parser ne devine pas quand il
/// n'a pas confiance. L'utilisateur voit toujours un preview avant
/// validation (jamais de setState silencieux sur des données hasardeuses).

/// Résultat du parsing d'une étiquette. Les champs valent `null` quand ils
/// n'ont pas pu être extraits avec une confiance raisonnable.
class OcrLabelResult {
  final String? receiverName;
  final String? receiverPhone;
  final String? receiverAddress;
  final double? weightKg;

  const OcrLabelResult({
    this.receiverName,
    this.receiverPhone,
    this.receiverAddress,
    this.weightKg,
  });

  /// `true` quand au moins un champ a été extrait. Si `false`, afficher à
  /// l'utilisateur un message explicite au lieu d'ouvrir un preview vide.
  bool get hasAnyField =>
      receiverName != null ||
      receiverPhone != null ||
      receiverAddress != null ||
      weightKg != null;

  @override
  String toString() =>
      'OcrLabelResult(name=$receiverName, phone=$receiverPhone, '
      'address=$receiverAddress, weight=${weightKg?.toStringAsFixed(2)}kg)';
}

/// Points chauds de reconnaissance. Ordre d'application :
///  1. Nettoyage lignes (trim, lignes vides enlevées).
///  2. Extraction téléphone (regex Sénégal tolérante).
///  3. Extraction poids (chiffre + kg).
///  4. Extraction nom (ligne précédée de "Destinataire"/"Nom"/"To:", ou
///     première ligne en majuscules avec au moins deux mots).
///  5. Extraction adresse (lignes après "Adresse:" ou lignes avec mots-clés
///     « rue », « avenue », « quartier », « BP »).
OcrLabelResult parseOcrLabel(String rawText) {
  if (rawText.trim().isEmpty) return const OcrLabelResult();

  final lines = rawText
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final phone = _extractPhone(lines);
  final weight = _extractWeight(lines);
  final name = _extractName(lines, phoneMatched: phone);
  final address = _extractAddress(lines, phone: phone, name: name);

  return OcrLabelResult(
    receiverName: name,
    receiverPhone: phone,
    receiverAddress: address,
    weightKg: weight,
  );
}

// ─────────────────────────────────────────────────────────────────────
// Téléphone
// ─────────────────────────────────────────────────────────────────────

/// Numéros sénégalais : opérateurs mobiles 70/75/76/77/78 et parfois fixes 3x.
/// On accepte avec/sans +221, avec séparateurs (espaces, points, tirets).
/// Retourne un format normalisé `+221XXXXXXXXX` quand reconnu.
final RegExp _phoneSnRegex = RegExp(
  r'(?:\+?221[\s.\-]?)?(7[05678])[\s.\-]?(\d{3})[\s.\-]?(\d{2})[\s.\-]?(\d{2})',
);

String? _extractPhone(List<String> lines) {
  for (final line in lines) {
    final match = _phoneSnRegex.firstMatch(line);
    if (match != null) {
      final prefix = match.group(1)!;
      final a = match.group(2)!;
      final b = match.group(3)!;
      final c = match.group(4)!;
      return '+221$prefix$a$b$c';
    }
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────
// Poids
// ─────────────────────────────────────────────────────────────────────

/// Patterns acceptés : "2 kg", "2.5 KG", "1,2kg", "Poids : 3 kg".
final RegExp _weightRegex = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(?:k\s*g|kilos?|kilogrammes?)\b',
  caseSensitive: false,
);

double? _extractWeight(List<String> lines) {
  for (final line in lines) {
    final match = _weightRegex.firstMatch(line);
    if (match != null) {
      final raw = match.group(1)!.replaceAll(',', '.');
      final value = double.tryParse(raw);
      // Ignore valeurs absurdes (OCR confond souvent 1 et L, O et 0).
      if (value != null && value > 0 && value < 500) return value;
    }
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────
// Nom
// ─────────────────────────────────────────────────────────────────────

final RegExp _nameLabelRegex = RegExp(
  r'^(?:destinataire|recevant|dest|nom|to|receiver|name)\s*[:\-–]\s*(.+)$',
  caseSensitive: false,
);

String? _extractName(List<String> lines, {String? phoneMatched}) {
  // 1. Priorité : ligne "Destinataire: Xxx" ou "Nom: Xxx".
  for (final line in lines) {
    final match = _nameLabelRegex.firstMatch(line);
    if (match != null) {
      final value = _sanitizeFreeform(match.group(1));
      if (value != null && _looksLikeName(value)) return value;
    }
  }

  // 2. Repli : première ligne vraisemblable (2+ mots, pas de digits, pas
  // de mots-clés adresse).
  for (final line in lines) {
    if (_phoneSnRegex.hasMatch(line)) continue;
    if (_weightRegex.hasMatch(line)) continue;
    if (_looksLikeAddress(line)) continue;
    if (_looksLikeName(line)) return _sanitizeFreeform(line);
  }
  return null;
}

bool _looksLikeName(String value) {
  final cleaned = value.trim();
  if (cleaned.length < 3 || cleaned.length > 60) return false;
  if (RegExp(r'\d').hasMatch(cleaned)) return false;
  final words = cleaned.split(RegExp(r'\s+'));
  if (words.length < 2) return false;
  // Au moins une lettre majuscule attendue (Xxx Xxx).
  if (!RegExp(r'[A-ZÀ-Ý]').hasMatch(cleaned)) return false;
  return true;
}

// ─────────────────────────────────────────────────────────────────────
// Adresse
// ─────────────────────────────────────────────────────────────────────

final RegExp _addressLabelRegex = RegExp(
  r'^(?:adresse|address|addr|livraison|quartier)\s*[:\-–]\s*(.+)$',
  caseSensitive: false,
);

final RegExp _addressHintRegex = RegExp(
  r'\b(rue|avenue|av\.|boulevard|bd\.|route|quartier|cite|cité|villa|'
  r'immeuble|hlm|sacr[ée]-?c[oœ]eur|parcelles?|liberte|libert[ée]|'
  r'ngor|yoff|almadies|ouakam|mermoz|plateau|m[ée]dina|bp|lot\s?\d+)\b',
  caseSensitive: false,
);

String? _extractAddress(List<String> lines, {String? phone, String? name}) {
  // 1. Priorité : ligne "Adresse: xxx".
  for (final line in lines) {
    final match = _addressLabelRegex.firstMatch(line);
    if (match != null) {
      final value = _sanitizeFreeform(match.group(1));
      if (value != null && value.length >= 3) return value;
    }
  }

  // 2. Repli : ligne contenant un mot-clé d'adresse (hors lignes nom/phone).
  for (final line in lines) {
    if (phone != null && _phoneSnRegex.hasMatch(line)) continue;
    if (name != null && line.trim() == name) continue;
    if (_addressHintRegex.hasMatch(line)) return _sanitizeFreeform(line);
  }

  return null;
}

bool _looksLikeAddress(String line) => _addressHintRegex.hasMatch(line);

// ─────────────────────────────────────────────────────────────────────
// Utilitaires
// ─────────────────────────────────────────────────────────────────────

String? _sanitizeFreeform(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.trim().replaceAll(RegExp(r'\s{2,}'), ' ');
  if (cleaned.isEmpty) return null;
  return cleaned;
}
