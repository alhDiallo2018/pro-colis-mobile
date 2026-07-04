import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../models/payment.dart';
import '../../models/parcel.dart';
import '../../models/voice_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/procolis_design_system.dart';

class PublishTripScreen extends ConsumerStatefulWidget {
  const PublishTripScreen({super.key});

  @override
  ConsumerState<PublishTripScreen> createState() => _PublishTripScreenState();
}

class _PublishTripScreenState extends ConsumerState<PublishTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final _audioRecorder = Record();
  final _audioPlayer = AudioPlayer();

  final _dateController = TextEditingController();
  final _timeController = TextEditingController(text: '14:00');
  final _capacityController = TextEditingController(text: '50');
  final _priceController = TextEditingController(text: '1500');
  final _noteController = TextEditingController();

  final List<VoiceMessage> _voiceMessages = [];
  final Set<String> _stops = {};

  static const List<String> _cities = [
    'Abidjan',
    'Yamoussoukro',
    'Bouaké',
    'Daloa',
    'San-Pédro',
    'Korhogo',
    'Man',
    'Gagnoa',
    'Divo',
    'Abengourou',
  ];

  String _from = 'Abidjan';
  String? _to;
  DateTime? _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);
  bool _isRecording = false;
  bool _isLoading = false;
  bool _published = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  String? _currentlyPlayingPath;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _selectedDate = DateTime.now();
    _dateController.text = _formatDisplayDate(_selectedDate!);
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    for (final message in _voiceMessages) {
      _deleteLocalAudio(message.path);
    }
    super.dispose();
  }

  List<String> get _stopOptions {
    return _cities
        .where((city) => city != _from && city != _to && !_stops.contains(city))
        .take(4)
        .toList();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
      _dateController.text = _formatDisplayDate(picked);
    });
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked == null) return;

    setState(() {
      _selectedTime = picked;
      _timeController.text = _formatTime(picked);
    });
  }

  Future<String?> _getVoiceMessagePath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return '${directory.path}/trip_voice_$timestamp.m4a';
    } catch (error) {
      debugPrint('Erreur chemin audio voyage: $error');
      return null;
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.isRecording()) return;

      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        _showSnack('Permission microphone refusée', AppTheme.warningColor);
        return;
      }

      final path = await _getVoiceMessagePath();
      if (path == null) {
        throw Exception('Impossible de créer le fichier audio');
      }

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordingDuration++);
        }
      });

      await _audioRecorder.start(
        path: path,
        encoder: AudioEncoder.aacLc,
        samplingRate: 44100,
      );
    } catch (error) {
      debugPrint('Erreur enregistrement voyage: $error');
      _recordingTimer?.cancel();
      if (mounted) {
        setState(() => _isRecording = false);
        _showSnack('Erreur lors de l’enregistrement', AppTheme.errorColor);
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
          ..add(
            VoiceMessage(
              path: path,
              duration: _recordingDuration,
              createdAt: DateTime.now(),
            ),
          );
      });
    } catch (error) {
      debugPrint('Erreur arrêt enregistrement voyage: $error');
      if (mounted) {
        setState(() => _isRecording = false);
      }
    }
  }

  Future<void> _playVoiceMessage(VoiceMessage message) async {
    try {
      if (_currentlyPlayingPath == message.path) {
        await _audioPlayer.stop();
        setState(() => _currentlyPlayingPath = null);
        return;
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(message.path));
      setState(() => _currentlyPlayingPath = message.path);
    } catch (error) {
      debugPrint('Erreur lecture audio voyage: $error');
      _showSnack('Lecture audio impossible', AppTheme.errorColor);
    }
  }

  void _removeVoiceMessage() {
    if (_voiceMessages.isEmpty) return;
    final message = _voiceMessages.removeLast();
    _deleteLocalAudio(message.path);
    setState(() => _currentlyPlayingPath = null);
  }

  Future<void> _publishTrip() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authProvider).user;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      final departureDate = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Les fichiers vocaux locaux doivent être envoyés avant la création,
      // car le modèle Parcel ne transporte que des URLs côté API.
      final uploadedAudioUrls = <String>[];
      for (final message in _voiceMessages) {
        try {
          final url = await _apiService.uploadFile(file: XFile(message.path), mediaType: 'audio');
          if (url != null && url.isNotEmpty) {
            uploadedAudioUrls.add(url);
          }
        } catch (error) {
          debugPrint('Erreur upload note vocale voyage: $error');
        }
      }

      final cleanPrice = _priceController.text.replaceAll(RegExp(r'\s+'), '');
      final notes = _buildTripNotes();

      // Cette payload réutilise le contrat Parcel existant pour publier une
      // annonce chauffeur visible dans le libre-service et les listes d'offres.
      final parcelData = {
        'senderId': user.id,
        'senderName': user.fullName,
        'senderPhone': user.phone,
        'senderEmail': user.email,
        'receiverName': 'À déterminer',
        'receiverPhone': '',
        'receiverEmail': '',
        'receiverAddress': _to,
        'description': 'Voyage de $_from à $_to',
        'weight': double.tryParse(_capacityController.text) ?? 0,
        'length': null,
        'width': null,
        'height': null,
        'type': ParcelType.package.value,
        'status': 'free',
        'departureGarageId': '',
        'departureGarageName': _from,
        'arrivalGarageId': '',
        'arrivalGarageName': _to,
        'price': double.tryParse(cleanPrice) ?? 0,
        'proposedPrice': double.tryParse(cleanPrice) ?? 0,
        'isUrgent': false,
        'isInsured': false,
        'paymentMethod': PaymentMethod.cash.value,
        'paymentPhoneNumber': '',
        'isFreeForBidding': true,
        'driverId': user.id,
        'driverName': user.fullName,
        'driverPhone': user.phone,
        'departureDate': departureDate.toIso8601String(),
        'notes': notes,
        'vehicleModel': user.vehicleModel ?? '',
        'vehiclePlate': user.vehiclePlate ?? '',
        'vehicleColor': user.vehicleColor ?? '',
        'vehicleType': user.vehicleModel ?? '',
        'audioUrls': uploadedAudioUrls,
      };

      final result = await ref.read(parcelProvider.notifier).createParcel(
            parcelData,
          );

      if (result != null && mounted) {
        for (final message in _voiceMessages) {
          _deleteLocalAudio(message.path);
        }
        _voiceMessages.clear();
        setState(() => _published = true);
      }
    } catch (error) {
      debugPrint('Erreur publication voyage: $error');
      if (mounted) {
        _showSnack('Impossible de publier le voyage', AppTheme.errorColor);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _buildTripNotes() {
    final stopsText = _stops.isEmpty ? 'Aucune' : _stops.join(', ');
    final note = _noteController.text.trim();

    return '''
🛣️ Voyage de $_from à $_to
📍 Villes desservies: $stopsText
📅 Départ: ${_dateController.text} à ${_timeController.text}
📦 Capacité disponible: ${_capacityController.text} kg
💰 Prix indicatif: ${_priceController.text} FCFA/kg
${note.isNotEmpty ? '\n📝 Note: $note' : ''}
'''
        .trim();
  }

  void _deleteLocalAudio(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (error) {
      debugPrint('Erreur suppression audio voyage: $error');
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDisplayDate(DateTime date) {
    const months = [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_published) {
      return _PublishedTripSuccess(
        from: _from,
        to: _to ?? '…',
        onPool: () => Navigator.pop(context, true),
        onDashboard: () => Navigator.pop(context),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Publier un voyage'),
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
          children: [
            const _PublishTripHero(),
            const SizedBox(height: 20),
            _FormSection(
              title: 'Trajet',
              icon: Icons.route_rounded,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _CitySelect(
                        label: 'Départ',
                        icon: Icons.trip_origin_rounded,
                        value: _from,
                        cities: _cities,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _from = value;
                            if (_to == value) _to = null;
                            _stops.remove(value);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CitySelect(
                        label: 'Arrivée',
                        icon: Icons.pin_drop_rounded,
                        value: _to,
                        cities: _cities.where((city) => city != _from).toList(),
                        placeholder: 'Ville',
                        validator: (value) => value == null ? 'Requis' : null,
                        onChanged: (value) {
                          setState(() {
                            _to = value;
                            if (value != null) _stops.remove(value);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Villes desservies en chemin (optionnel)',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._stops.map(
                      (city) => _StopChip(
                        label: city,
                        selected: true,
                        onTap: () => setState(() => _stops.remove(city)),
                      ),
                    ),
                    ..._stopOptions.map(
                      (city) => _StopChip(
                        label: city,
                        selected: false,
                        onTap: () => setState(() => _stops.add(city)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _FormSection(
              title: 'Départ & capacité',
              icon: Icons.event_rounded,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TripTextField(
                        controller: _dateController,
                        label: 'Date',
                        icon: Icons.calendar_month_rounded,
                        readOnly: true,
                        onTap: _selectDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TripTextField(
                        controller: _timeController,
                        label: 'Heure',
                        icon: Icons.schedule_rounded,
                        readOnly: true,
                        mono: true,
                        onTap: _selectTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TripTextField(
                        controller: _capacityController,
                        label: 'Capacité dispo.',
                        icon: Icons.inventory_2_rounded,
                        suffix: 'kg',
                        mono: true,
                        keyboardType: TextInputType.number,
                        validator: _positiveNumberValidator,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TripTextField(
                        controller: _priceController,
                        label: 'Prix indicatif',
                        suffix: 'FCFA/kg',
                        mono: true,
                        keyboardType: TextInputType.number,
                        validator: _positiveNumberValidator,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _FormSection(
              title: 'Note pour les clients',
              icon: Icons.edit_note_rounded,
              children: [
                TextFormField(
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 3,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    hintText:
                        'Ex : Camionnette réfrigérée, je peux prendre du volumineux.',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Note vocale (optionnel)',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                _VoiceRecorder(
                  isRecording: _isRecording,
                  duration: _recordingDuration,
                  message: _voiceMessages.isEmpty ? null : _voiceMessages.last,
                  isPlaying: _voiceMessages.isNotEmpty &&
                      _currentlyPlayingPath == _voiceMessages.last.path,
                  onRecord: _toggleRecording,
                  onPlay: _voiceMessages.isEmpty
                      ? null
                      : () => _playVoiceMessage(_voiceMessages.last),
                  onDelete: _removeVoiceMessage,
                ),
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
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _publishTrip,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.campaign_rounded),
              label: Text(
                _isLoading ? 'Publication…' : 'Publier le voyage',
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _positiveNumberValidator(String? value) {
    final cleanValue = (value ?? '').replaceAll(RegExp(r'\s+'), '');
    final number = double.tryParse(cleanValue);
    if (number == null || number <= 0) {
      return 'Invalide';
    }
    return null;
  }
}

class _PublishTripHero extends StatelessWidget {
  const _PublishTripHero();

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(
              Icons.campaign_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Annoncez votre trajet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Les clients sur votre route vous enverront leurs colis directement.',
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

class _CitySelect extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? value;
  final List<String> cities;
  final String? placeholder;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _CitySelect({
    required this.label,
    required this.icon,
    required this.value,
    required this.cities,
    required this.onChanged,
    this.placeholder,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      hint: placeholder == null ? null : Text(placeholder!),
      items: cities
          .map(
            (city) => DropdownMenuItem<String>(
              value: city,
              child: Text(
                city,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _TripTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? suffix;
  final bool readOnly;
  final bool mono;
  final TextInputType? keyboardType;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;

  const _TripTextField({
    required this.controller,
    required this.label,
    this.icon,
    this.suffix,
    this.readOnly = false,
    this.mono = false,
    this.keyboardType,
    this.onTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      validator: validator,
      style: mono
          ? AppTheme.mono(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            )
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixText: suffix,
      ),
    );
  }
}

class _StopChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StopChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppTheme.primary : AppTheme.slate600;
    final background = selected ? AppTheme.primaryLight : AppTheme.slate100;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.close_rounded : Icons.add_rounded,
                color: foreground,
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
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
              icon: const Icon(
                Icons.delete_rounded,
                color: AppTheme.slate500,
              ),
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
                      ? 'Enregistrement… touchez pour arrêter'
                      : 'Enregistrer une note vocale',
                  style: TextStyle(
                    color:
                        isRecording ? AppTheme.errorColor : AppTheme.slate700,
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
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
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
          .map(
            (height) => Container(
              width: 4,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PublishedTripSuccess extends StatelessWidget {
  final String from;
  final String to;
  final VoidCallback onPool;
  final VoidCallback onDashboard;

  const _PublishedTripSuccess({
    required this.from,
    required this.to,
    required this.onPool,
    required this.onDashboard,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: const BoxDecoration(
                  color: AppTheme.teal50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: AppTheme.primary,
                  size: 54,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Voyage publié !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  text: 'Votre trajet ',
                  children: [
                    TextSpan(
                      text: '$from → $to',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const TextSpan(
                      text:
                          ' est visible par les clients. Ils peuvent désormais vous proposer leurs colis.',
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: 280,
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: onPool,
                      icon: const Icon(Icons.sell_rounded),
                      label: const Text('Voir les colis à prendre'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: onDashboard,
                      child: const Text('Tableau de bord'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
