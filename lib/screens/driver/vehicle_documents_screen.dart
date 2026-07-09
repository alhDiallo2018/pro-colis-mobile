// lib/screens/driver/vehicle_documents_screen.dart
//
// Page chauffeur « Documents & véhicule » : le chauffeur téléverse les photos
// de son véhicule et ses documents officiels (permis, carte grise, assurance,
// CNI). Chaque téléversement passe par uploadFile (POST /upload) pour obtenir
// une URL, puis uploadIdentityDocument (POST /identity/upload) pour la persister.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/pc_components.dart';

/// Descripteur d'un document officiel affiché sous forme de carte.
class _DocType {
  final String type;
  final String label;
  final IconData icon;
  const _DocType(this.type, this.label, this.icon);
}

const List<_DocType> _officialDocs = [
  _DocType('driver_license', 'Permis de conduire', Icons.badge_rounded),
  _DocType('vehicle_registration', 'Carte grise', Icons.article_rounded),
  _DocType('insurance', 'Assurance', Icons.verified_user_rounded),
  _DocType('id_card', 'Pièce d\'identité (CNI)', Icons.perm_identity_rounded),
];

class VehicleDocumentsScreen extends ConsumerStatefulWidget {
  const VehicleDocumentsScreen({super.key});

  @override
  ConsumerState<VehicleDocumentsScreen> createState() =>
      _VehicleDocumentsScreenState();
}

class _VehicleDocumentsScreenState
    extends ConsumerState<VehicleDocumentsScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  bool _loading = true;
  Map<String, dynamic>? _vehicle;

  /// Photos du véhicule téléversées durant / avant la session.
  final List<String> _vehiclePhotos = [];

  /// URLs des documents officiels, clé = '<type>_<side>'.
  final Map<String, String> _docUrls = {};

  /// Slots en cours de téléversement, même convention de clé.
  final Set<String> _uploading = {};

  static String _slotKey(String type, String side) => '${type}_$side';

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  /// Chargement best-effort : véhicule + dernier document d'identité connu.
  /// Le backend étant un placeholder, on ne plante jamais si la donnée manque.
  Future<void> _loadInitial() async {
    try {
      final results = await Future.wait([
        _api.getDriverVehicle(),
        _api.getIdentityStatus(),
      ]);
      if (!mounted) return;
      final vehicle = results[0];
      final status = results[1];
      setState(() {
        _vehicle = vehicle;
        _prefillFromIdentity(status);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Tente de reconstruire les URLs déjà connues depuis /identity/status.
  /// Format attendu (souple) : { identity: { documents: [ { documentType,
  /// side, url } ] } } — sinon on démarre à vide.
  void _prefillFromIdentity(Map<String, dynamic>? status) {
    if (status == null) return;
    final identity = status['identity'];
    if (identity is! Map) return;
    final docs = identity['documents'];
    if (docs is! List) return;
    for (final d in docs) {
      if (d is! Map) continue;
      final type = d['documentType']?.toString();
      final side = d['side']?.toString();
      final url = d['url']?.toString();
      if (type == null || url == null || url.isEmpty) continue;
      if (type == 'vehicle_photo') {
        if (!_vehiclePhotos.contains(url)) _vehiclePhotos.add(url);
      } else if (side != null) {
        _docUrls[_slotKey(type, side)] = url;
      }
    }
  }

  /// Résout une URL de média : les chemins relatifs `/uploads/...` sont
  /// préfixés avec le backend, comme dans le reste de l'application.
  String _mediaUrl(String url) => url.startsWith('http')
      ? url
      : 'https://procolis-backend.onrender.com$url';

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  /// Petit sélecteur Appareil photo / Galerie.
  Future<ImageSource?> _pickSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded,
                  color: AppTheme.primary),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppTheme.primary),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Flux commun : choisir la source, prendre l'image, uploader le fichier,
  /// puis persister l'URL via /identity/upload. Retourne l'URL finale ou null.
  Future<String?> _pickUploadPersist({
    required String documentType,
    required String side,
    required String slotKey,
  }) async {
    final source = await _pickSource();
    if (source == null) return null;

    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 2000,
    );
    if (file == null) return null;

    setState(() => _uploading.add(slotKey));
    try {
      final url = await _api.uploadFile(file: file, mediaType: 'photo');
      if (url == null || url.isEmpty) {
        _snack('Échec du téléversement');
        return null;
      }
      await _api.uploadIdentityDocument(
        documentType: documentType,
        side: side,
        url: url,
      );
      return url;
    } catch (_) {
      _snack('Téléversement impossible');
      return null;
    } finally {
      if (mounted) setState(() => _uploading.remove(slotKey));
    }
  }

  Future<void> _addVehiclePhoto() async {
    final slotKey = 'vehicle_photo_new_${_vehiclePhotos.length}';
    final url = await _pickUploadPersist(
      documentType: 'vehicle_photo',
      side: 'front',
      slotKey: slotKey,
    );
    if (url != null && mounted) {
      setState(() => _vehiclePhotos.add(url));
    }
  }

  Future<void> _uploadDocSide(_DocType doc, String side) async {
    final slotKey = _slotKey(doc.type, side);
    final url = await _pickUploadPersist(
      documentType: doc.type,
      side: side,
      slotKey: slotKey,
    );
    if (url != null && mounted) {
      setState(() => _docUrls[slotKey] = url);
    }
  }

  void _openFullscreen(String url) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Icon(Icons.broken_image_rounded,
                        color: Colors.white54, size: 48),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                children: [
                  const PcSectionHeader('Véhicule'),
                  _buildVehicleCard(),
                  const SizedBox(height: 18),
                  const PcSectionHeader('Photos du véhicule'),
                  _buildVehiclePhotos(),
                  const SizedBox(height: 18),
                  const PcSectionHeader('Documents officiels'),
                  for (final doc in _officialDocs) ...[
                    _buildDocCard(doc),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
      child: Row(
        children: [
          PcIconButton(
            Icons.arrow_back_rounded,
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Retour',
          ),
          const SizedBox(width: 4),
          const Text(
            'Documents & véhicule',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard() {
    final v = _vehicle;
    if (v == null || v.isEmpty) {
      return PcCard(
        child: PcEmptyState(
          icon: Icons.directions_car_rounded,
          title: 'Aucun véhicule',
          message:
              'Renseignez les informations de votre véhicule dans les Paramètres.',
          tone: PcTone.primary,
        ),
      );
    }

    String field(String key, String fallback) {
      final value = v[key];
      if (value == null) return fallback;
      final s = value.toString().trim();
      return s.isEmpty ? fallback : s;
    }

    return PcCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.teal50,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(Icons.directions_car_rounded,
                    color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field('model', 'Véhicule'),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      field('type', 'Type non renseigné'),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _VehicleInfoRow(
            label: 'Plaque',
            value: field('plateNumber', 'Non renseignée'),
          ),
          const PcDivider(),
          _VehicleInfoRow(
            label: 'Capacité',
            value: field('capacity', 'Non renseignée'),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclePhotos() {
    final addingKey = 'vehicle_photo_new_${_vehiclePhotos.length}';
    final isAdding = _uploading.contains(addingKey);
    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_vehiclePhotos.isEmpty && !isAdding)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Ajoutez des photos de votre véhicule (avant, arrière, intérieur).',
                style: const TextStyle(
                  color: AppTheme.slate500,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final url in _vehiclePhotos)
                _PhotoThumb(
                  url: _mediaUrl(url),
                  onTap: () => _openFullscreen(_mediaUrl(url)),
                ),
              if (isAdding) const _UploadingTile(),
              _AddTile(
                label: 'Ajouter une photo',
                onTap: isAdding ? null : _addVehiclePhoto,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocCard(_DocType doc) {
    return PcCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.teal50,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(doc.icon, size: 20, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  doc.label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (_isDocComplete(doc))
                const PcBadge('Complet',
                    tone: PcTone.green, icon: Icons.check_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDocSlot(doc, 'front', 'Recto')),
              const SizedBox(width: 10),
              Expanded(child: _buildDocSlot(doc, 'back', 'Verso')),
            ],
          ),
        ],
      ),
    );
  }

  bool _isDocComplete(_DocType doc) =>
      _docUrls.containsKey(_slotKey(doc.type, 'front')) &&
      _docUrls.containsKey(_slotKey(doc.type, 'back'));

  Widget _buildDocSlot(_DocType doc, String side, String label) {
    final slotKey = _slotKey(doc.type, side);
    final url = _docUrls[slotKey];
    final uploading = _uploading.contains(slotKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.slate500,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            if (url != null)
              const Icon(Icons.check_circle_rounded,
                  size: 16, color: AppTheme.green500),
          ],
        ),
        const SizedBox(height: 6),
        _DocSlotTile(
          url: url == null ? null : _mediaUrl(url),
          uploading: uploading,
          onTap: uploading ? null : () => _uploadDocSide(doc, side),
          onView: url == null ? null : () => _openFullscreen(_mediaUrl(url)),
        ),
      ],
    );
  }
}

// ============================================================
// Widgets internes
// ============================================================

class _VehicleInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _VehicleInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.slate500,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  const _PhotoThumb({required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Image.network(
          url,
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 88,
            height: 88,
            color: AppTheme.slate100,
            child:
                const Icon(Icons.broken_image_rounded, color: AppTheme.slate400),
          ),
        ),
      ),
    );
  }
}

class _UploadingTile extends StatelessWidget {
  const _UploadingTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2.4, color: AppTheme.primary),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _AddTile({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppTheme.teal50,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.teal100,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_rounded,
                color: AppTheme.primary, size: 24),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tuile d'un côté (recto/verso) d'un document : ajoute, affiche le
/// chargement, ou montre la miniature une fois téléversée.
class _DocSlotTile extends StatelessWidget {
  final String? url;
  final bool uploading;
  final VoidCallback? onTap;
  final VoidCallback? onView;

  const _DocSlotTile({
    required this.url,
    required this.uploading,
    required this.onTap,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    const double h = 96;
    if (uploading) {
      return Container(
        height: h,
        decoration: BoxDecoration(
          color: AppTheme.slate100,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: AppTheme.primary),
          ),
        ),
      );
    }

    if (url != null) {
      return Stack(
        children: [
          GestureDetector(
            onTap: onView,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Image.network(
                url!,
                height: h,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: h,
                  color: AppTheme.slate100,
                  child: const Icon(Icons.broken_image_rounded,
                      color: AppTheme.slate400),
                ),
              ),
            ),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Material(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(999),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: AppTheme.slate50,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_rounded,
                color: AppTheme.slate400, size: 26),
            SizedBox(height: 4),
            Text(
              'Ajouter',
              style: TextStyle(
                color: AppTheme.slate500,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
