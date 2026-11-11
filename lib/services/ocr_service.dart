import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_label_parser.dart';

/// Orchestrateur OCR : passe une image au moteur Google ML Kit, récupère
/// le texte brut, puis délègue l'extraction des champs au parser pur.
///
/// Le reconnaisseur ML Kit est **lourd à instancier** (chargement du modèle
/// en mémoire) — on le garde en singleton de process. Appeler `dispose()`
/// quand l'application se termine si on veut libérer la mémoire ; en
/// pratique inutile sur un appareil mobile (c'est le cycle de vie du
/// process qui le fera).
///
/// 100 % on-device : aucun appel réseau, aucun upload d'image.
class OcrService {
  OcrService._();
  static final OcrService instance = OcrService._();

  TextRecognizer? _recognizer;

  TextRecognizer _ensureRecognizer() {
    return _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
  }

  /// Scanne une image depuis son chemin local et retourne les champs extraits.
  /// Retourne un [OcrLabelResult] avec `hasAnyField == false` si le moteur
  /// n'a reconnu aucun texte exploitable — jamais d'exception vers l'UI.
  Future<OcrLabelResult> scanLabel(String imagePath) async {
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await _ensureRecognizer().processImage(input);
      if (result.text.trim().isEmpty) return const OcrLabelResult();
      return parseOcrLabel(result.text);
    } catch (error, stack) {
      debugPrint('[OCR] Reconnaissance impossible (${error.runtimeType})');
      debugPrintStack(stackTrace: stack);
      return const OcrLabelResult();
    }
  }

  /// À appeler si l'app est fermée et qu'on veut libérer la mémoire modèle.
  /// Non obligatoire — le process OS libère tout à la terminaison.
  Future<void> dispose() async {
    final rec = _recognizer;
    _recognizer = null;
    if (rec != null) await rec.close();
  }
}
