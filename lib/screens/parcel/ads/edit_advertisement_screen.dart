import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../models/garage.dart';
import '../../../models/parcel.dart';
import '../../../models/voice_message.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/procolis_design_system.dart';

class EditAdvertisementScreen extends ConsumerStatefulWidget {
  final Parcel parcel;

  const EditAdvertisementScreen({
    super.key,
    required this.parcel,
  });

  @override
  ConsumerState<EditAdvertisementScreen> createState() =>
      _EditAdvertisementScreenState();
}

class _EditAdvertisementScreenState
    extends ConsumerState<EditAdvertisementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _audioRecorder = Record();
  final _audioPlayer = AudioPlayer();

  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _weightController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<Garage> _garages = [];
  Garage? _departureGarage;
  Garage? _arrivalGarage;
  DateTime? _departureDate;
  TimeOfDay _departureTime = const TimeOfDay(hour: 8, minute: 0);

  final List<VoiceMessage> _voiceMessages = [];
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  String? _currentlyPlayingPath;

  bool _isLoadingGarages = true;
  bool _isLoadingData = true;
  bool _isSubmitting = false;

  Parcel get ad => widget.parcel;

  @override
  void initState() {
    super.initState();
    _prefillForm();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
      _loadGarages();
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _weightController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    for (final msg in _voiceMessages) {
      _deleteLocalFile(msg.path);
    }
    super.dispose();
  }

  void _prefillForm() {
    _descriptionController.text = ad.description;

    final weight = ad.weight > 0 ? ad.weight.toStringAsFixed(0) : '';
    _weightController.text = weight;

    if (ad.proposedPrice != null && ad.proposedPrice! > 0) {
      _priceController.text = ad.proposedPrice!.toStringAsFixed(0);
    }

    if (ad.createdAt != null) {
      _departureDate = ad.createdAt;
      _departureTime = TimeOfDay.fromDateTime(ad.createdAt);
    } else {
      _departureDate = DateTime.now().add(const Duration(days: 1));
    }
    _dateController.text = _formatDisplayDate(_departureDate!);
    _timeController.text = _formatTime(_departureTime);
  }

  void _preselectGarages() {
    if (_garages.isEmpty) return;

    if (ad.departureGarageId.isNotEmpty) {
      _departureGarage = _findGarageById(ad.departureGarageId);
      if (_departureGarage == null && ad.departureGarageName.isNotEmpty) {
        _departureGarage = _findGarageByName(ad.departureGarageName);
      }
    }

    if (ad.arrivalGarageId != null && ad.arrivalGarageId!.isNotEmpty) {
      _arrivalGarage = _findGarageById(ad.arrivalGarageId!);
      if (_arrivalGarage == null &&
          ad.arrivalGarageName != null &&
          ad.arrivalGarageName!.isNotEmpty) {
        _arrivalGarage = _findGarageByName(ad.arrivalGarageName!);
      }
    }

    if (mounted) setState(() => _isLoadingData = false);
  }

  Garage? _findGarageById(String id) {
    try {
      return _garages.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  Garage? _findGarageByName(String name) {
    try {
      return _garages.firstWhere((g) =>
          g.name.toLowerCase() == name.toLowerCase() ||
          '${g.name} · ${g.city}' == name);
    } catch (_) {
      return null;
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> _loadGarages() async {
    try {
      final garages = await _apiService.getAllGarages();
      if (mounted) {
        setState(() {
          _garages = garages;
          _isLoadingGarages = false;
          _preselectGarages();
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement garages édition: $e');
      if (mounted) {
        setState(() {
          _isLoadingGarages = false;
          _isLoadingData = false;
        });
        _showSnack('Impossible de charger les garages', isError: true);
      }
    }
  }

  List<Garage> get _departureOptions => _garages;

  List<Garage> get _arrivalOptions =>
      _garages.where((g) => g.id != _departureGarage?.id).toList();

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDate ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked == null) return;
    setState(() {
      _departureDate = picked;
      _dateController.text = _formatDisplayDate(picked);
    });
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _departureTime,
    );
    if (picked == null) return;
    setState(() {
      _departureTime = picked;
      _timeController.text = _formatTime(picked);
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<String?> _getVoicePath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      return '${dir.path}/ad_edit_voice_$ts.m4a';
    } catch (e) {
      debugPrint('Erreur chemin audio édition: $e');
      return null;
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.isRecording()) return;
      final hasPerm = await _audioRecorder.hasPermission();
      if (!hasPerm) {
        _showSnack('Permission microphone refusée', isError: true);
        return;
      }
      final path = await _getVoicePath();
      if (path == null) throw Exception('Impossible de créer le fichier audio');
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingDuration++);
      });
      await _audioRecorder.start(
        path: path,
        encoder: AudioEncoder.aacLc,
        samplingRate: 44100,
      );
    } catch (e) {
      debugPrint('Erreur enregistrement édition: $e');
      _recordingTimer?.cancel();
      if (mounted) {
        setState(() => _isRecording = false);
        _showSnack('Erreur lors de l\'enregistrement', isError: true);
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      if (path == null || !mounted) {
        setState(() => _isRecording = false);
        return;
      }
      setState(() {
        _isRecording = false;
        _voiceMessages
          ..clear()
          ..add(VoiceMessage(
            path: path,
            duration: _recordingDuration,
            createdAt: DateTime.now(),
          ));
      });
    } catch (e) {
      debugPrint('Erreur arrêt enregistrement édition: $e');
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _playVoice(VoiceMessage message) async {
    try {
      if (_currentlyPlayingPath == message.path) {
        await _audioPlayer.stop();
        setState(() => _currentlyPlayingPath = null);
        return;
      }
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(message.path));
      setState(() => _currentlyPlayingPath = message.path);
    } catch (e) {
      debugPrint('Erreur lecture audio édition: $e');
      _showSnack('Lecture audio impossible', isError: true);
    }
  }

  void _removeVoiceMessage() {
    if (_voiceMessages.isEmpty) return;
    final msg = _voiceMessages.removeLast();
    _deleteLocalFile(msg.path);
    setState(() => _currentlyPlayingPath = null);
  }

  void _deleteLocalFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (e) {
      debugPrint('Erreur suppression fichier édition: $e');
    }
  }

  Map<String, dynamic> _buildPayload(User user, DateTime departureDateTime,
      List<String> uploadedAudioUrls) {
    final cleanPrice =
        _priceController.text.replaceAll(RegExp(r'\s+'), '');
    final cleanWeight =
        _weightController.text.replaceAll(RegExp(r'\s+'), '');

    return <String, dynamic>{
      'driverId': user.id,
      'driverName': user.fullName,
      'driverPhone': user.phone,
      'departureGarageId': _departureGarage!.id,
      'departureGarageName': _departureGarage!.name,
      'departureCity': _departureGarage!.city,
      'arrivalGarageId': _arrivalGarage!.id,
      'arrivalGarageName': _arrivalGarage!.name,
      'arrivalCity': _arrivalGarage!.city,
      'departureDate': departureDateTime.toIso8601String(),
      'availableWeight': double.tryParse(cleanWeight) ?? 0,
      'proposedPrice': double.tryParse(cleanPrice) ?? 0,
      'description': _descriptionController.text.trim(),
      'audioUrls': uploadedAudioUrls,
      'vehicleModel': user.vehicleModel ?? '',
      'vehiclePlate': user.vehiclePlate ?? '',
      'vehicleColor': user.vehicleColor ?? '',
    };
  }

  Future<Map<String, dynamic>> _updateAdvertisement(
      Map<String, dynamic> data) async {
    try {
      final token = await _apiService.getToken();
      final dio = Dio(BaseOptions(
        baseUrl: ApiService.baseUrl,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (status) => status != null && status < 500,
      ));

      final response =
          await dio.put('/advertisements/${ad.id}', data: data);

      if (response.data is String) {
        return jsonDecode(response.data) as Map<String, dynamic>;
      }
      if (response.data is Map) {
        return response.data as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'Réponse inattendue du serveur'};
    } on DioException catch (e) {
      final message = e.response?.data is Map
          ? (e.response!.data as Map)['message']?.toString()
          : null;
      return {
        'success': false,
        'message': message ?? 'Erreur lors de la mise à jour',
      };
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_departureGarage == null) {
      _showSnack('Veuillez sélectionner le garage de départ', isError: true);
      return;
    }
    if (_arrivalGarage == null) {
      _showSnack('Veuillez sélectionner le garage d\'arrivée', isError: true);
      return;
    }
    if (_departureGarage!.id == _arrivalGarage!.id) {
      _showSnack('Le garage de départ et d\'arrivée doivent être différents',
          isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(authProvider).user;
      if (user == null) throw Exception('Utilisateur non connecté');

      final departureDateTime = DateTime(
        _departureDate!.year,
        _departureDate!.month,
        _departureDate!.day,
        _departureTime.hour,
        _departureTime.minute,
      );

      final uploadedAudioUrls = <String>[...ad.audioUrls];
      for (final msg in _voiceMessages) {
        try {
          final url = await _apiService.uploadFile(
            file: XFile(msg.path),
            mediaType: 'audio',
          );
          if (url != null && url.isNotEmpty) uploadedAudioUrls.add(url);
        } catch (e) {
          debugPrint('Erreur upload note vocale édition: $e');
        }
      }

      final data = _buildPayload(user, departureDateTime, uploadedAudioUrls);

      final result = await _updateAdvertisement(data);

      if (!mounted) return;

      if (result['success'] == true || result['id'] != null) {
        for (final msg in _voiceMessages) {
          _deleteLocalFile(msg.path);
        }
        _voiceMessages.clear();
        _showSnack('Annonce mise à jour avec succès');
        Navigator.pop(context, true);
      } else {
        _showSnack(
          result['message']?.toString() ?? 'Erreur lors de la mise à jour',
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('Erreur mise à jour annonce: $e');
      if (mounted) _showSnack('Erreur lors de la mise à jour', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingGarages || _isLoadingData) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Modifier l\'annonce'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
        ),
        body: const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Modifier l\'annonce'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
          children: [
            _buildHero(),
            const SizedBox(height: 20),
            _buildGaragesSection(),
            const SizedBox(height: 20),
            _buildDateTimeSection(),
            const SizedBox(height: 20),
            _buildDetailsSection(),
            const SizedBox(height: 20),
            _buildVoiceSection(),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : () => _submit(),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _isSubmitting ? 'Enregistrement...' : 'Enregistrer les modifications',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.brandShadow(),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modifier l\'annonce',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Mettez à jour votre annonce pour attirer plus de clients.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGaragesSection() {
    return _FormSection(
      title: 'Garages',
      icon: Icons.business_rounded,
      children: [
        DropdownButtonFormField<Garage>(
          value: _departureGarage,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Garage de départ',
            prefixIcon: Icon(Icons.trip_origin_rounded),
          ),
          validator: (value) => value == null ? 'Requis' : null,
          items: _departureOptions.map((g) {
            return DropdownMenuItem<Garage>(
              value: g,
              child: Text('${g.name} · ${g.city}',
                  overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _departureGarage = value;
              if (_arrivalGarage?.id == value.id) _arrivalGarage = null;
            });
          },
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<Garage>(
          value: _arrivalGarage,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Garage d\'arrivée',
            prefixIcon: Icon(Icons.pin_drop_rounded),
          ),
          validator: (value) => value == null ? 'Requis' : null,
          hint: const Text('Sélectionnez un garage'),
          items: _arrivalOptions.map((g) {
            return DropdownMenuItem<Garage>(
              value: g,
              child: Text('${g.name} · ${g.city}',
                  overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _arrivalGarage = value);
          },
        ),
      ],
    );
  }

  Widget _buildDateTimeSection() {
    return _FormSection(
      title: 'Date et heure de départ',
      icon: Icons.event_rounded,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _dateController,
                readOnly: true,
                onTap: _selectDate,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_month_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _timeController,
                readOnly: true,
                onTap: _selectTime,
                decoration: const InputDecoration(
                  labelText: 'Heure',
                  prefixIcon: Icon(Icons.schedule_rounded),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return _FormSection(
      title: 'Détails',
      icon: Icons.info_outline_rounded,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Poids disponible',
                  suffixText: 'kg',
                  prefixIcon: Icon(Icons.inventory_2_rounded),
                ),
                validator: _positiveNumberValidator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Prix proposé',
                  suffixText: 'FCFA',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                ),
                validator: _positiveNumberValidator,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _descriptionController,
          minLines: 3,
          maxLines: 5,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Décrivez votre trajet, type de véhicule, etc.',
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceSection() {
    return _FormSection(
      title: 'Note vocale (optionnel)',
      icon: Icons.mic_rounded,
      children: [
        _VoiceRecorder(
          isRecording: _isRecording,
          duration: _recordingDuration,
          message: _voiceMessages.isEmpty ? null : _voiceMessages.last,
          isPlaying: _voiceMessages.isNotEmpty &&
              _currentlyPlayingPath == _voiceMessages.last.path,
          onRecord: _toggleRecording,
          onPlay: _voiceMessages.isEmpty
              ? null
              : () => _playVoice(_voiceMessages.last),
          onDelete: _removeVoiceMessage,
        ),
        if (ad.hasAudio) ...[
          const SizedBox(height: 10),
          const Text(
            'Notes vocales existantes conservées',
            style: TextStyle(
              color: AppTheme.slate400,
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 6),
        const Text(
          'Les clients entendront ce message avant de vous confier un colis.',
          style: TextStyle(
            color: AppTheme.slate400,
            fontSize: 11.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  String? _positiveNumberValidator(String? value) {
    final clean = (value ?? '').replaceAll(RegExp(r'\s+'), '');
    final number = double.tryParse(clean);
    if (number == null || number <= 0) return 'Invalide';
    return null;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }

  String _formatDisplayDate(DateTime date) {
    const months = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _FormSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ProcolisCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _VoiceRecorder extends StatelessWidget {
  final bool isRecording;
  final int duration;
  final VoiceMessage? message;
  final bool isPlaying;
  final VoidCallback onRecord;
  final VoidCallback? onPlay;
  final VoidCallback onDelete;

  const _VoiceRecorder({
    required this.isRecording,
    required this.duration,
    required this.message,
    required this.isPlaying,
    required this.onRecord,
    required this.onPlay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (message != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onPlay,
              icon: Icon(
                isPlaying
                    ? Icons.pause_circle_rounded
                    : Icons.play_circle_rounded,
                color: AppTheme.primary,
                size: 30,
              ),
            ),
            const Expanded(child: _Waveform()),
            Text(
              _formatDuration(message!.duration),
              style: AppTheme.mono(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_rounded, color: AppTheme.slate500),
            ),
          ],
        ),
      );
    }

    return Material(
      color: isRecording ? AppTheme.red50 : AppTheme.cardColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onRecord,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isRecording ? AppTheme.red400 : AppTheme.slate200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.mic_rounded,
                color: isRecording ? AppTheme.errorColor : AppTheme.primary,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isRecording
                      ? 'Enregistrement... touchez pour arrêter'
                      : 'Enregistrer une note vocale',
                  style: TextStyle(
                    color: isRecording ? AppTheme.errorColor : AppTheme.slate700,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isRecording)
                Text(
                  _formatDuration(duration),
                  style: AppTheme.mono(
                    color: AppTheme.errorColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform();

  @override
  Widget build(BuildContext context) {
    const heights = [10.0, 18.0, 13.0, 24.0, 15.0, 29.0, 18.0, 12.0, 22.0];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: heights
          .map((h) => Container(
                width: 4,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
              ))
          .toList(),
    );
  }
}
