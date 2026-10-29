import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

/// Aperçu puis import du même fichier : aucun départ n'est publié implicitement.
class RouteImportSheet extends StatefulWidget {
  const RouteImportSheet({super.key});
  @override
  State<RouteImportSheet> createState() => _RouteImportSheetState();
}

class _RouteImportSheetState extends State<RouteImportSheet> {
  final _api = ApiService();
  Uint8List? _bytes;
  String? _filename, _error;
  List<Map<String, dynamic>> _preview = [];
  bool _busy = false;

  Future<void> _select() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final selected = await FilePicker.pickFiles(
          type: FileType.custom, allowedExtensions: ['csv'], withData: true);
      if (selected == null) return;
      final file = selected.files.single;
      if (file.size > 128 * 1024 || file.bytes == null) {
        throw const FormatException(
            'Choisissez un fichier CSV de 128 Ko maximum.');
      }
      final preview =
          await _api.importRouteCsv(file.bytes!, file.name, preview: true);
      if (!mounted) return;
      setState(() {
        _bytes = file.bytes;
        _filename = file.name;
        _preview = preview;
      });
    } catch (error, stack) {
      debugPrint('[RouteImport] Aperçu impossible (${error.runtimeType})');
      debugPrintStack(stackTrace: stack);
      if (mounted)
        setState(() {
          _bytes = null;
          _preview = [];
          _error = error is ApiException
              ? error.message
              : error is FormatException
                  ? error.message
                  : 'Impossible de lire le fichier. Vérifiez la connexion puis réessayez.';
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy || _bytes == null || _filename == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.importRouteCsv(_bytes!, _filename!);
      if (mounted) Navigator.pop(context, true);
    } catch (error, stack) {
      debugPrint('[RouteImport] Import impossible (${error.runtimeType})');
      debugPrintStack(stackTrace: stack);
      if (mounted)
        setState(() => _error = error is ApiException
            ? error.message
            : 'Import non confirmé. Vous pouvez réessayer le même fichier sans créer de doublons.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_busy,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Importer des itinéraires navette',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text(
                  'Une ligne par arrêt, dans le sens du trajet. Commencez les minutes à 0. Utilisez le nom exact ou l’identifiant de la zone. Maximum : 50 arrêts par fichier, 40 par itinéraire.'),
              const SizedBox(height: 12),
              const SelectableText(
                  'ligne;zone;minutes\n45;Dakar;0\n45;Thiès;90'),
              TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          await Clipboard.setData(const ClipboardData(
                              text:
                                  'ligne;zone;minutes\n45;Dakar;0\n45;Thiès;90\n'));
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Modèle copié. Adaptez les zones avant import.')));
                        },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copier le modèle CSV')),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                  onPressed: _busy ? null : _select,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_filename ?? 'Choisir un fichier CSV')),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_error!,
                        semanticsLabel: _error,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              for (final route in _preview)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                      'Ligne ${route['data']['itinerary']['lineNumber']} · '
                      '${(route['data']['itinerary']['stops'] as List).map((stop) => stop['name']).join(' → ')}'),
                ),
              if (_preview.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                    'Les itinéraires seront ajoutés à vos trajets habituels. Choisissez ensuite les horaires pour publier vos départs. Un nouvel import du même itinéraire met à jour son modèle.'),
                const SizedBox(height: 16),
                FilledButton(
                    onPressed: _busy ? null : _import,
                    child: Text(
                        'Importer ${_preview.length} itinéraire${_preview.length > 1 ? 's' : ''}')),
              ],
              TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Fermer')),
              if (_busy)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator())),
            ],
          )),
        ),
      );
}
