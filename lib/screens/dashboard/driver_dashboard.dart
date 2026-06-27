// mobile/lib/screens/dashboard/driver_dashboard.dart
// ignore_for_file: unused_import, deprecated_member_use, prefer_const_constructors

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/models/payment.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/models/voice_message.dart';
import 'package:procolis/screens/dashboard/notifications/notifications_screen.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/theme/app_theme.dart';
import 'package:procolis/widgets/score_display_widget.dart';
import 'package:record/record.dart';

import '../../providers/auth_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../widgets/app_logo.dart';
import '../parcel/free_parcels_screen.dart';
import '../parcel/new_parcel_screen.dart';
import '../parcel/parcel_detail_screen.dart';
import '../profile/profile_screen.dart';

// ==================== ÉCRAN DE CRÉATION D'ANNONCE POUR CHAUFFEUR ====================

class DriverCreateAdScreen extends ConsumerStatefulWidget {
  const DriverCreateAdScreen({super.key});

  @override
  ConsumerState<DriverCreateAdScreen> createState() => _DriverCreateAdScreenState();
}

class _DriverCreateAdScreenState extends ConsumerState<DriverCreateAdScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  // Contrôleurs pour les champs de base
  final _departureController = TextEditingController();
  final _arrivalController = TextEditingController();
  final _departureDateController = TextEditingController();
  final _departureTimeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  // Contrôleurs pour les détails du colis
  final _maxWeightController = TextEditingController();
  final _maxLengthController = TextEditingController();
  final _maxWidthController = TextEditingController();
  final _maxHeightController = TextEditingController();

  // Contrôleurs pour les options (masqués mais conservés pour les données)
  final _pricePerKgController = TextEditingController();
  final _basePriceController = TextEditingController();

  // Date et heure
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Sélecteurs (masqués mais conservés pour les données)
  bool _isUrgent = false;
  bool _isInsured = false;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  ParcelType _parcelType = ParcelType.package;

  // Messages vocaux
  final _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<VoiceMessage> _voiceMessages = [];
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  String? _currentlyPlayingPath;

  // Informations du chauffeur (masquées mais conservées pour les données)
  String _vehicleModel = '';
  String _vehiclePlate = '';
  String _vehicleColor = '';
  String _vehicleType = '';

  // Lieux existants (pour l'autocomplétion)
  List<String> _existingLocations = [];
  List<String> _departureSuggestions = [];
  List<String> _arrivalSuggestions = [];
  bool _isLoadingLocations = false;

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6B7A8F);
  static const Color backgroundColor = Color(0xFFF0F4F8);

  @override
  void initState() {
    super.initState();
    _loadDriverInfo();
    _requestPermissions();
    _loadExistingLocations();
    
    // Écouteurs pour mettre à jour l'aperçu en temps réel
    _departureController.addListener(_updateSummary);
    _arrivalController.addListener(_updateSummary);
    _departureDateController.addListener(_updateSummary);
    _departureTimeController.addListener(_updateSummary);
    _maxWeightController.addListener(_updateSummary);
    _maxLengthController.addListener(_updateSummary);
    _maxWidthController.addListener(_updateSummary);
    _maxHeightController.addListener(_updateSummary);
    _notesController.addListener(_updateSummary);
  }

  @override
  void dispose() {
    _departureController.dispose();
    _arrivalController.dispose();
    _departureDateController.dispose();
    _departureTimeController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _maxWeightController.dispose();
    _maxLengthController.dispose();
    _maxWidthController.dispose();
    _maxHeightController.dispose();
    _pricePerKgController.dispose();
    _basePriceController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    for (final msg in _voiceMessages) {
      try {
        final file = File(msg.path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
    super.dispose();
  }

  void _updateSummary() {
    setState(() {});
  }

  Future<void> _loadExistingLocations() async {
    setState(() => _isLoadingLocations = true);
    try {
      final parcels = await _apiService.getGarageParcels();
      if (mounted) {
        final Set<String> locationSet = {};
        for (final parcel in parcels) {
          if (parcel.departureGarageName != null && parcel.departureGarageName!.isNotEmpty) {
            locationSet.add(parcel.departureGarageName!);
          }
          if (parcel.arrivalGarageName != null && parcel.arrivalGarageName!.isNotEmpty) {
            locationSet.add(parcel.arrivalGarageName!);
          }
        }
        setState(() {
          _existingLocations = locationSet.toList()..sort();
          _isLoadingLocations = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement lieux: $e');
      if (mounted) {
        setState(() => _isLoadingLocations = false);
      }
    }
  }

  void _updateDepartureSuggestions(String query) {
    if (query.isEmpty) {
      setState(() => _departureSuggestions = []);
      return;
    }
    setState(() {
      _departureSuggestions = _existingLocations
          .where((loc) => loc.toLowerCase().contains(query.toLowerCase()))
          .take(10)
          .toList();
    });
  }

  void _updateArrivalSuggestions(String query) {
    if (query.isEmpty) {
      setState(() => _arrivalSuggestions = []);
      return;
    }
    setState(() {
      _arrivalSuggestions = _existingLocations
          .where((loc) => loc.toLowerCase().contains(query.toLowerCase()))
          .take(10)
          .toList();
    });
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> _loadDriverInfo() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user != null) {
      setState(() {
        _vehicleModel = user.vehicleModel ?? '';
        _vehiclePlate = user.vehiclePlate ?? '';
        _vehicleColor = user.vehicleColor ?? '';
        _vehicleType = user.vehicleModel ?? '';
      });
    }
  }

  // ==================== GESTION DES MESSAGES VOCAUX ====================

  Future<String?> _getVoiceMessagePath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return '${directory.path}/voice_ad_$timestamp.m4a';
    } catch (e) {
      debugPrint('Erreur chemin audio: $e');
      return null;
    }
  }

  Future<void> _startRecording() async {
    try {
      final isRecording = await _audioRecorder.isRecording();
      if (isRecording) return;

      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission microphone refusée'),
              backgroundColor: Colors.orange,
            ),
          );
        }
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
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration++;
          });
        }
      });

      await _audioRecorder.start(
        path: path,
        encoder: AudioEncoder.aacLc,
        samplingRate: 44100,
      );
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'enregistrement: $e');
      _recordingTimer?.cancel();
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final isRecording = await _audioRecorder.isRecording();
      if (isRecording) {
        _recordingTimer?.cancel();
        final path = await _audioRecorder.stop();

        if (path != null && mounted) {
          final voiceMessage = VoiceMessage(
            path: path,
            duration: _recordingDuration,
            createdAt: DateTime.now(),
          );
          setState(() {
            _voiceMessages.add(voiceMessage);
            _isRecording = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Message vocal enregistré (${_formatDuration(_recordingDuration)})',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          setState(() {
            _isRecording = false;
          });
        }
      } else {
        setState(() {
          _isRecording = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'arrêt: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _playVoiceMessage(String path) async {
    try {
      if (_currentlyPlayingPath == path) {
        await _audioPlayer.stop();
        setState(() {
          _currentlyPlayingPath = null;
        });
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(path));
        setState(() {
          _currentlyPlayingPath = path;
        });

        _audioPlayer.onPlayerComplete.listen((event) {
          if (mounted) {
            setState(() {
              _currentlyPlayingPath = null;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur lors de la lecture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la lecture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeVoiceMessage(int index) {
    final voiceMessage = _voiceMessages[index];
    try {
      final file = File(voiceMessage.path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      debugPrint('Erreur suppression fichier audio: $e');
    }
    setState(() {
      _voiceMessages.removeAt(index);
    });
  }

  // ==================== FIN GESTION VOCALE ====================

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: primaryBlue,
            colorScheme: ColorScheme.light(primary: primaryBlue),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _departureDateController.text =
            '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: primaryBlue,
            colorScheme: ColorScheme.light(primary: primaryBlue),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _departureTimeController.text = picked.format(context);
      });
    }
  }

  Future<void> _createAd() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une date de départ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une heure de départ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authProvider);
      final user = authState.user;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      final departureDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // Upload des messages vocaux
      List<String> uploadedAudioUrls = [];
      if (_voiceMessages.isNotEmpty) {
        debugPrint('🎤 Upload de ${_voiceMessages.length} message(s) vocal(aux)...');
        for (int i = 0; i < _voiceMessages.length; i++) {
          final voiceMsg = _voiceMessages[i];
          try {
            final audioFile = XFile(voiceMsg.path);
            final url = await _apiService.uploadAudio(audioFile, '');
            if (url != null && url.isNotEmpty) {
              debugPrint('✅ Message vocal ${i + 1} uploadé: $url');
              uploadedAudioUrls.add(url);
            }
          } catch (e) {
            debugPrint('❌ Erreur upload audio ${i + 1}: $e');
          }
        }
      }

      // Construction de la description complète
      final fullDescription = _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : '📦 Voyage de ${_departureController.text} à ${_arrivalController.text}';

      // Construction des notes
      final notes = '''
🛣️ Voyage de ${_departureController.text} à ${_arrivalController.text}
📅 Départ: ${_departureDateController.text} à ${_departureTimeController.text}
📦 Capacité max: ${_maxWeightController.text.isNotEmpty ? "${_maxWeightController.text} kg" : 'Non spécifiée'}
📏 Dimensions max: ${_getDimensionsText()}
${_notesController.text.isNotEmpty ? '\n📝 Notes: ${_notesController.text}' : ''}
'''.trim();

      // Préparer les données du colis
      final parcelData = {
        // Expéditeur = Chauffeur
        'senderId': user.id,
        'senderName': user.fullName,
        'senderPhone': user.phone,
        'senderEmail': user.email,
        // Destinataire = Client (à déterminer)
        'receiverName': 'À déterminer',
        'receiverPhone': '',
        'receiverEmail': '',
        'receiverAddress': _arrivalController.text,
        // Description du voyage
        'description': fullDescription,
        // Capacité de chargement
        'weight': double.tryParse(_maxWeightController.text) ?? 0,
        'length': double.tryParse(_maxLengthController.text),
        'width': double.tryParse(_maxWidthController.text),
        'height': double.tryParse(_maxHeightController.text),
        // Type de colis accepté
        'type': _parcelType.value,
        // Statut
        'status': 'free',
        // Trajet
        'departureGarageId': '',
        'departureGarageName': _departureController.text,
        'arrivalGarageId': '',
        'arrivalGarageName': _arrivalController.text,
        // Prix (sera négocié)
        'price': double.tryParse(_basePriceController.text) ?? 0,
        'proposedPrice': double.tryParse(_pricePerKgController.text) ?? 0,
        // Options
        'isUrgent': _isUrgent,
        'isInsured': _isInsured,
        // Paiement
        'paymentMethod': _paymentMethod.value,
        'paymentPhoneNumber': '',
        // Mode libre service
        'isFreeForBidding': true,
        // Chauffeur assigné
        'driverId': user.id,
        'driverName': user.fullName,
        'driverPhone': user.phone,
        // Date de départ
        'departureDate': departureDateTime.toIso8601String(),
        // Notes
        'notes': notes,
        // Métadonnées supplémentaires
        'vehicleModel': _vehicleModel,
        'vehiclePlate': _vehiclePlate,
        'vehicleColor': _vehicleColor,
        'vehicleType': _vehicleType,
        // Messages vocaux
        'audioUrls': uploadedAudioUrls,
      };

      final result = await ref.read(parcelProvider.notifier).createParcel(parcelData);

      if (result != null && mounted) {
        // Nettoyer les fichiers audio temporaires
        for (final msg in _voiceMessages) {
          try {
            final file = File(msg.path);
            if (file.existsSync()) {
              file.deleteSync();
            }
          } catch (_) {}
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Annonce de voyage créée avec succès !'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getDimensionsText() {
    final parts = <String>[];
    if (_maxLengthController.text.isNotEmpty) parts.add('L: ${_maxLengthController.text}');
    if (_maxWidthController.text.isNotEmpty) parts.add('l: ${_maxWidthController.text}');
    if (_maxHeightController.text.isNotEmpty) parts.add('h: ${_maxHeightController.text}');
    return parts.isEmpty ? 'Non spécifiées' : parts.join(' × ');
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      // PAS D'APP BAR ICI - elle est dans le DriverDashboard parent
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête
                    _buildHeader(),
                    const SizedBox(height: 16),

                    // Informations du voyage
                    _buildTripSection(),
                    const SizedBox(height: 16),

                    // Détails du véhicule et capacité
                    _buildVehicleSection(),
                    const SizedBox(height: 16),

                    // Message vocal
                    _buildVoiceSection(),
                    const SizedBox(height: 16),

                    // Notes
                    _buildNotesSection(),
                    const SizedBox(height: 16),

                    // Résumé
                    _buildSummarySection(),
                    const SizedBox(height: 24),

                    // Bouton publier
                    _buildPublishButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_shipping,
              color: primaryBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Annonce de voyage',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                Text(
                  'Proposez un trajet pour transporter des colis',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📍 Trajet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Lieu de départ avec autocomplétion
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _departureController,
                decoration: InputDecoration(
                  labelText: 'Lieu de départ *',
                  hintText: 'Ex: Dakar, Plateau',
                  prefixIcon: const Icon(Icons.departure_board, color: Colors.grey),
                  suffixIcon: _isLoadingLocations
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
                onChanged: _updateDepartureSuggestions,
              ),
              if (_departureSuggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: _departureSuggestions.length,
                    itemBuilder: (context, index) {
                      final location = _departureSuggestions[index];
                      return ListTile(
                        title: Text(
                          location,
                          style: const TextStyle(fontSize: 14),
                        ),
                        leading: const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        onTap: () {
                          setState(() {
                            _departureController.text = location;
                            _departureSuggestions = [];
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Lieu d'arrivée avec autocomplétion
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _arrivalController,
                decoration: InputDecoration(
                  labelText: 'Lieu d\'arrivée *',
                  hintText: 'Ex: Dakar, Grand Dakar',
                  prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
                onChanged: _updateArrivalSuggestions,
              ),
              if (_arrivalSuggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: _arrivalSuggestions.length,
                    itemBuilder: (context, index) {
                      final location = _arrivalSuggestions[index];
                      return ListTile(
                        title: Text(
                          location,
                          style: const TextStyle(fontSize: 14),
                        ),
                        leading: const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        onTap: () {
                          setState(() {
                            _arrivalController.text = location;
                            _arrivalSuggestions = [];
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectDate(context),
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: _departureDateController,
                      decoration: InputDecoration(
                        labelText: 'Date de départ *',
                        hintText: 'JJ/MM/AAAA',
                        prefixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectTime(context),
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: _departureTimeController,
                      decoration: InputDecoration(
                        labelText: 'Heure de départ *',
                        hintText: 'HH:MM',
                        prefixIcon: const Icon(Icons.access_time, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📦 Capacité de chargement',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _maxWeightController,
            decoration: InputDecoration(
              labelText: 'Poids max (kg) *',
              hintText: 'Ex: 50',
              prefixIcon: const Icon(Icons.fitness_center, color: Colors.grey),
              suffixText: 'kg',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryBlue, width: 1.5),
              ),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Champ requis';
              if (double.tryParse(value) == null) return 'Valeur invalide';
              if (double.parse(value) <= 0) return 'Le poids doit être supérieur à 0';
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _maxLengthController,
                  decoration: InputDecoration(
                    labelText: 'Longueur max (cm)',
                    hintText: 'Ex: 100',
                    prefixIcon: const Icon(Icons.straighten, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _maxWidthController,
                  decoration: InputDecoration(
                    labelText: 'Largeur max (cm)',
                    hintText: 'Ex: 60',
                    prefixIcon: const Icon(Icons.straighten, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primaryBlue, width: 1.5),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _maxHeightController,
            decoration: InputDecoration(
              labelText: 'Hauteur max (cm)',
              hintText: 'Ex: 40',
              prefixIcon: const Icon(Icons.height, color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryBlue, width: 1.5),
              ),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ParcelType>(
            value: _parcelType,
            decoration: InputDecoration(
              labelText: 'Type de colis accepté',
              prefixIcon: const Icon(Icons.category, color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryBlue, width: 1.5),
              ),
            ),
            items: ParcelType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.value),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _parcelType = value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎤 Message vocal (optionnel)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.mic, color: primaryBlue),
                      const SizedBox(width: 8),
                      const Text(
                        'Ajoutez un message vocal',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      if (_voiceMessages.isNotEmpty)
                        Text(
                          '${_voiceMessages.length} message(s)',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                if (_voiceMessages.isNotEmpty)
                  ..._voiceMessages.asMap().entries.map((entry) {
                    final index = entry.key;
                    final voiceMsg = entry.value;
                    return _buildVoiceMessageTile(voiceMsg, index);
                  }),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _isRecording
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Enregistrement... ${_formatDuration(_recordingDuration)}',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 12),
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: _startRecording,
                                icon: const Icon(Icons.mic, size: 20),
                                label: const Text('Enregistrer un message vocal'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                      ),
                      if (_isRecording) const SizedBox(width: 12),
                      if (_isRecording)
                        ElevatedButton(
                          onPressed: _stopRecording,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Arrêter'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceMessageTile(VoiceMessage message, int index) {
    final isPlaying = _currentlyPlayingPath == message.path;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isPlaying ? Icons.stop : Icons.play_arrow,
              color: primaryBlue,
            ),
            onPressed: () => _playVoiceMessage(message.path),
            iconSize: 20,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message vocal ${_formatDuration(message.duration)}',
                  style: TextStyle(fontSize: 12, color: textPrimary),
                ),
                Text(
                  '${_formatDateTime(message.createdAt)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => _removeVoiceMessage(index),
            color: Colors.grey.shade600,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📝 Informations complémentaires',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'Ajoutez des informations supplémentaires (conditions, restrictions, etc.)...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primaryBlue, width: 1.5),
              ),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    // Récupération des valeurs en temps réel
    final departure = _departureController.text;
    final arrival = _arrivalController.text;
    final date = _departureDateController.text;
    final time = _departureTimeController.text;
    final weight = _maxWeightController.text;
    final hasData = departure.isNotEmpty || arrival.isNotEmpty || date.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: primaryBlue),
              const SizedBox(width: 8),
              const Text(
                'Résumé de l\'annonce',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (departure.isNotEmpty && arrival.isNotEmpty)
            Text(
              '📍 $departure → $arrival',
              style: TextStyle(fontSize: 13, color: textPrimary),
            )
          else
            Text(
              '📍 Trajet non défini',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            ),
          if (date.isNotEmpty && time.isNotEmpty)
            Text(
              '📅 $date à $time',
              style: TextStyle(fontSize: 13, color: textPrimary),
            )
          else if (date.isNotEmpty)
            Text(
              '📅 $date',
              style: TextStyle(fontSize: 13, color: textPrimary),
            )
          else
            Text(
              '📅 Date non définie',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            ),
          if (weight.isNotEmpty)
            Text(
              '📦 Capacité: ${weight} kg',
              style: TextStyle(fontSize: 13, color: textPrimary),
            )
          else
            Text(
              '📦 Capacité: Non définie',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
            ),
          Text(
            '📏 Dims: ${_getDimensionsText()}',
            style: TextStyle(fontSize: 13, color: textPrimary),
          ),
          Text(
            '📦 Type: ${_parcelType.value}',
            style: TextStyle(fontSize: 13, color: textPrimary),
          ),
          if (_notesController.text.isNotEmpty)
            Text(
              '📝 ${_notesController.text}',
              style: TextStyle(fontSize: 13, color: textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (_voiceMessages.isNotEmpty)
            Text(
              '🎤 ${_voiceMessages.length} message(s) vocal(aux)',
              style: TextStyle(fontSize: 13, color: primaryBlue),
            ),
          if (!hasData && _voiceMessages.isEmpty && _notesController.text.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Remplissez les champs ci-dessus pour voir l\'aperçu',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPublishButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _createAd,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: const Text(
          'Publier l\'annonce',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ==================== DRIVER DASHBOARD ====================

class DriverDashboard extends ConsumerStatefulWidget {
  const DriverDashboard({super.key});

  @override
  ConsumerState<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends ConsumerState<DriverDashboard> {
  int _selectedIndex = 0;
  int _unreadNotificationsCount = 0;

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color backgroundColor = Color(0xFFF0F4F8);

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadNotificationsCount();
  }

  void _loadData() {
    Future.microtask(() {
      ref.read(parcelProvider.notifier).loadDriverParcels();
      ref.read(parcelProvider.notifier).loadFreeParcels();
    });
  }

  void _loadNotificationsCount() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = 2;
        });
      }
    });
  }

  void _onNotificationsTap() {
    setState(() {
      _selectedIndex = 4;
    });
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationsScreen(
          onNotificationsRead: () {
            _loadNotificationsCount();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final parcelState = ref.watch(parcelProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 28),
            const SizedBox(width: 10),
            const Text(
              'PRO COLIS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: _onNotificationsTap,
                color: Colors.white,
              ),
              if (_unreadNotificationsCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_unreadNotificationsCount > 99 ? '99+' : _unreadNotificationsCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _getScreen(_selectedIndex, user, parcelState),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            selectedItemColor: primaryBlue,
            unselectedItemColor: Colors.grey,
            backgroundColor: Colors.white,
            elevation: 0,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.local_shipping),
                label: 'Mes colis',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.storefront_rounded),
                label: 'Annonces',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.add_box),
                label: 'Envoyer',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications_rounded),
                    if (_unreadNotificationsCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${_unreadNotificationsCount > 9 ? '9+' : _unreadNotificationsCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                label: 'Notifications',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getScreen(int index, User? user, ParcelState parcelState) {
    switch (index) {
      case 0:
        return _MyParcelsScreen(
          parcelState: parcelState,
          onRefresh: _loadData,
          user: user,
          onNotificationsTap: _onNotificationsTap,
          unreadNotificationsCount: _unreadNotificationsCount,
        );
      case 1:
        return const DriverAdvertisementsScreen();
      case 2:
        return const DriverCreateAdScreen();
      case 3:
        return NotificationsScreen(
          onNotificationsRead: () {
            setState(() {
              _unreadNotificationsCount = 0;
            });
          },
        );
      case 4:
        return const ProfileScreen();
      default:
        return _MyParcelsScreen(
          parcelState: parcelState,
          onRefresh: _loadData,
          user: user,
          onNotificationsTap: _onNotificationsTap,
          unreadNotificationsCount: _unreadNotificationsCount,
        );
    }
  }
}

// ==================== ÉCRAN ANNONCES POUR CHAUFFEUR (SANS APP BAR) ====================

class DriverAdvertisementsScreen extends ConsumerStatefulWidget {
  const DriverAdvertisementsScreen({super.key});

  @override
  ConsumerState<DriverAdvertisementsScreen> createState() =>
      _DriverAdvertisementsScreenState();
}

class _DriverAdvertisementsScreenState
    extends ConsumerState<DriverAdvertisementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'all';
  bool _isLoading = false;

  List<Parcel> _clientRequests = [];
  List<Parcel> _myAds = [];

  final ApiService _apiService = ApiService();

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color backgroundColor = Color(0xFFF0F4F8);
  static const Color textPrimary = Color(0xFF1A2332);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAdvertisements();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdvertisements() async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await Future.microtask(() async {
        await ref.read(parcelProvider.notifier).loadFreeParcels();
      });

      final freeParcels = ref.read(parcelProvider).freeParcels;

      _clientRequests = freeParcels.where((p) =>
          p.senderId != user.id &&
          p.senderPhone != user.phone &&
          !_isDriver(p)).toList();

      _myAds = freeParcels.where((p) =>
          p.senderId == user.id || p.senderPhone == user.phone).toList();

      debugPrint('✅ Demandes clients: ${_clientRequests.length}, Mes annonces: ${_myAds.length}');
    } catch (e) {
      debugPrint('❌ Erreur chargement annonces: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isDriver(Parcel parcel) {
    return parcel.driverId != null ||
        parcel.driverName != null ||
        parcel.senderName.contains('Chauffeur') ||
        parcel.senderName.contains('Driver') ||
        parcel.senderName.contains('Chauffeuse');
  }

  List<Parcel> get _filteredAdvertisements {
    List<Parcel> ads = _tabController.index == 0
        ? _clientRequests
        : _myAds;

    switch (_selectedFilter) {
      case 'active':
        return ads.where((p) => p.status == ParcelStatus.free || p.status == ParcelStatus.pending).toList();
      case 'with_bids':
        return ads.where((p) => p.hasBids).toList();
      case 'confirmed':
        return ads.where((p) => p.status == ParcelStatus.confirmed).toList();
      case 'delivered':
        return ads.where((p) => p.status == ParcelStatus.delivered).toList();
      default:
        return ads;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      // PAS D'APP BAR ICI - elle est dans le DriverDashboard parent
      body: Column(
        children: [
          // Header avec titre et refresh
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Annonces',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadAdvertisements,
                  color: primaryBlue,
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: primaryBlue,
              ),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              onTap: (index) => setState(() {}),
              tabs: const [
                Tab(text: '👥 Demandes clients'),
                Tab(text: '📦 Mes annonces de voyage'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        isExpanded: true,
                        icon: Icon(
                          Icons.filter_list,
                          size: 18,
                          color: Colors.grey.shade600,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: textPrimary,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('📋 Toutes')),
                          DropdownMenuItem(value: 'active', child: Text('🔄 Actives')),
                          DropdownMenuItem(value: 'with_bids', child: Text('💰 Avec offres')),
                          DropdownMenuItem(value: 'confirmed', child: Text('✅ Confirmées')),
                          DropdownMenuItem(value: 'delivered', child: Text('🎉 Livrées')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedFilter = value!;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: _createNewAd,
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              tooltip: 'Nouvelle annonce de voyage',
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
        ),
      );
    }

    final advertisements = _filteredAdvertisements;

    if (advertisements.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadAdvertisements,
      color: primaryBlue,
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: advertisements.length,
        itemBuilder: (context, index) {
          final parcel = advertisements[index];
          final isMine = _tabController.index == 1;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildParcelCard(parcel, isMine),
          );
        },
      ),
    );
  }

  Widget _buildParcelCard(Parcel parcel, bool isMine) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildParcelContent(parcel),
          if (isMine) ...[
            const Divider(height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildActionButtons(parcel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParcelContent(Parcel parcel) {
    final hasBids = parcel.bids.isNotEmpty;
    final hasAudio = parcel.audioUrls.isNotEmpty;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FreeParcelDetailsScreen(parcel: parcel),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gavel, size: 12, color: Colors.purple[700]),
                      const SizedBox(width: 4),
                      Text(
                        'À marchander',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (hasBids)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${parcel.bids.length} offre(s)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (hasAudio)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic, size: 12, color: Colors.purple[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Audio',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.purple[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              parcel.trackingNumber,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'De: ${parcel.departureGarageName}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Column(
                children: [
                  Container(width: 2, height: 12, color: Colors.grey.shade300),
                  Icon(Icons.arrow_downward, size: 10, color: Colors.grey.shade400),
                  Container(width: 2, height: 12, color: Colors.grey.shade300),
                ],
              ),
            ),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'À: ${parcel.arrivalGarageName ?? "Non spécifié"}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.description, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    parcel.description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (parcel.notes != null && parcel.notes!.contains('Capacité max:'))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fitness_center, size: 12, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          _extractFromNotes(parcel.notes!, 'Capacité max'),
                          style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ),
                if (parcel.notes != null && parcel.notes!.contains('Départ:'))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text(
                          _extractFromNotes(parcel.notes!, 'Départ'),
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                        ),
                      ],
                    ),
                  ),
                if (parcel.isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flash_on, size: 12, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Urgent',
                          style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                        ),
                      ],
                    ),
                  ),
                if (parcel.isInsured)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield, size: 12, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Assuré',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                        ),
                      ],
                    ),
                  ),
                if (parcel.audioUrls.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic, size: 12, color: Colors.purple.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Message vocal',
                          style: TextStyle(fontSize: 11, color: Colors.purple.shade700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _extractFromNotes(String notes, String key) {
    final lines = notes.split('\n');
    for (final line in lines) {
      if (line.contains(key)) {
        final parts = line.split(':');
        if (parts.length > 1) {
          return parts[1].trim();
        }
      }
    }
    return '';
  }

  Widget _buildActionButtons(Parcel parcel) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: parcel.hasBids ? () => _showBidsDialog(parcel) : null,
            icon: Icon(
              Icons.visibility_outlined,
              size: 18,
              color: parcel.hasBids ? primaryBlue : Colors.grey.shade400,
            ),
            label: Text(
              'Voir les offres',
              style: TextStyle(
                color: parcel.hasBids ? primaryBlue : Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: parcel.hasBids ? primaryBlue : Colors.grey.shade300,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (parcel.isPending || parcel.isFree)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _editAd(parcel),
              icon: const Icon(
                Icons.edit_outlined,
                size: 18,
                color: Colors.grey,
              ),
              label: Text(
                'Modifier',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        const SizedBox(width: 8),
        if (parcel.isPending || parcel.isFree)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _deleteAd(parcel),
              icon: const Icon(
                Icons.delete_outlined,
                size: 18,
                color: Colors.red,
              ),
              label: Text(
                'Supprimer',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final isClientRequests = _tabController.index == 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isClientRequests
                    ? Icons.people_rounded
                    : Icons.local_shipping,
                size: 64,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isClientRequests
                  ? 'Aucune demande de client'
                  : 'Aucune annonce de voyage',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isClientRequests
                  ? 'Les clients n\'ont pas encore fait de demandes'
                  : 'Créez votre première annonce de voyage',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isClientRequests) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _createNewAd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Créer une annonce',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _createNewAd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DriverCreateAdScreen(),
      ),
    ).then((result) {
      if (result == true) {
        _loadAdvertisements();
      }
    });
  }

  void _editAd(Parcel parcel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParcelDetailScreen(parcel: parcel),
      ),
    ).then((result) {
      if (result == true) {
        _loadAdvertisements();
      }
    });
  }

  Future<void> _deleteAd(Parcel parcel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Supprimer l\'annonce',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Voulez-vous vraiment supprimer l\'annonce "${parcel.description}" ?\n\n'
          '⚠️ Toutes les offres associées seront également supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final result = await _apiService.cancelParcel(parcel.id);

        if (result['success'] == true) {
          await _loadAdvertisements();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Annonce supprimée avec succès'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        } else {
          throw Exception(result['message'] ?? 'Erreur lors de la suppression');
        }
      } catch (e) {
        debugPrint('❌ Erreur lors de la suppression: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showBidsDialog(Parcel parcel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _BidsBottomSheet(parcel: parcel),
    );
  }
}

// ==================== BOTTOM SHEET DES OFFRES ====================

class _BidsBottomSheet extends StatefulWidget {
  final Parcel parcel;

  const _BidsBottomSheet({required this.parcel});

  @override
  State<_BidsBottomSheet> createState() => _BidsBottomSheetState();
}

class _BidsBottomSheetState extends State<_BidsBottomSheet> {
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color textPrimary = Color(0xFF1A2332);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.gavel_rounded, color: primaryBlue),
              const SizedBox(width: 8),
              const Text(
                'Offres reçues',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.parcel.bids.length} offre${widget.parcel.bids.length > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.parcel.bids.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final bid = widget.parcel.bids[index];
                return _buildBidTile(bid);
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(
                  color: Colors.grey.shade300,
                ),
              ),
              child: const Text('Fermer'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBidTile(Bid bid) {
    final isSelected = widget.parcel.selectedBidId == bid.id;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: Colors.green, width: 1.5)
            : Border.all(color: Colors.transparent),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: primaryBlue.withValues(alpha: 0.1),
            child: Text(
              bid.driverName.isNotEmpty ? bid.driverName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bid.driverName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '✅ Acceptée',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '💰 ${bid.price.toStringAsFixed(0)} FCFA',
                  style: const TextStyle(
                    fontSize: 15,
                    color: primaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (bid.message != null && bid.message!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      bid.message!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '${bid.formattedDate}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bid.status.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: bid.status.color.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              bid.status.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: bid.status.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ÉCRAN MES COLIS (SANS APP BAR - SEULEMENT LE HEADER) ====================

class _MyParcelsScreen extends StatefulWidget {
  final ParcelState parcelState;
  final VoidCallback onRefresh;
  final User? user;
  final VoidCallback onNotificationsTap;
  final int unreadNotificationsCount;

  const _MyParcelsScreen({
    required this.parcelState,
    required this.onRefresh,
    this.user,
    required this.onNotificationsTap,
    this.unreadNotificationsCount = 0,
  });

  @override
  State<_MyParcelsScreen> createState() => _MyParcelsScreenState();
}

class _MyParcelsScreenState extends State<_MyParcelsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  User? _freshUser;

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color textPrimary = Color(0xFF1A2332);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadFreshUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFreshUser() async {
    try {
      final user = await _apiService.getCurrentUser();
      if (mounted) {
        setState(() {
          _freshUser = user;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement user: $e');
    }
  }

  List<Parcel> get _pendingParcels {
    return widget.parcelState.parcels
        .where((p) => p.status == ParcelStatus.pending || p.status == ParcelStatus.confirmed)
        .toList();
  }

  List<Parcel> get _activeDeliveries {
    return widget.parcelState.parcels
        .where((p) =>
            p.status == ParcelStatus.pickedUp ||
            p.status == ParcelStatus.inTransit ||
            p.status == ParcelStatus.arrived ||
            p.status == ParcelStatus.outForDelivery)
        .toList();
  }

  List<Parcel> get _completedParcels {
    return widget.parcelState.parcels.where((p) => p.isDelivered).toList();
  }

  List<Parcel> get _myParcels {
    return widget.parcelState.parcels.toList();
  }

  String _getFullImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/uploads/')) {
      return 'https://procolis-backend.onrender.com$url';
    }
    return url;
  }

  String _getDriverStatusText(String? status) {
    if (status == null || status.isEmpty) {
      return '🟢 Disponible';
    }
    switch (status.toLowerCase()) {
      case 'available':
        return '🟢 Disponible';
      case 'busy':
        return '🔴 En livraison';
      case 'offline':
        return '⚪ Hors ligne';
      default:
        return '🟢 Disponible';
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayUser = _freshUser ?? widget.user;
    final userName = displayUser?.fullName.split(' ').first ?? "Chauffeur";
    final profilePhoto = displayUser?.profilePhoto;
    final fullImageUrl = _getFullImageUrl(profilePhoto);
    final driverStatus = displayUser?.driverStatus ?? 'available';

    return Column(
      children: [
        // Header avec gradient - PAS UNE APP BAR
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryBlue, Color(0xFF3B82F6)],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        ).then((_) {
                          _loadFreshUser();
                        });
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: fullImageUrl.isNotEmpty
                              ? Image.network(
                                  fullImageUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour $userName',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          SizedBox(height: 2),
                          Text(
                            _getDriverStatusText(driverStatus.toString()),
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const ScoreDisplayWidget(),
                    SizedBox(width: 8),
                    // PAS DE NOTIFICATION ICI - elle est dans l'AppBar du DriverDashboard
                  ],
                ),
                SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatItem(
                        Icons.pending,
                        'Attente',
                        _pendingParcels.length,
                        Colors.orange,
                      ),
                      SizedBox(width: 8),
                      _buildStatItem(
                        Icons.local_shipping,
                        'En cours',
                        _activeDeliveries.length,
                        Colors.blue,
                      ),
                      SizedBox(width: 8),
                      _buildStatItem(
                        Icons.check_circle,
                        'Livrés',
                        _completedParcels.length,
                        Colors.green,
                      ),
                      SizedBox(width: 8),
                      _buildStatItem(
                        Icons.attach_money,
                        'Gains',
                        _calculateTotalEarnings(),
                        Colors.amber,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // TabBar et liste
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            indicatorColor: primaryBlue,
            labelColor: textPrimary,
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'Tous'),
              Tab(text: 'Attente'),
              Tab(text: 'En cours'),
              Tab(text: 'Livrés'),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadFreshUser();
              widget.onRefresh();
            },
            color: primaryBlue,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildParcelList(_myParcels),
                _buildParcelList(_pendingParcels),
                _buildParcelList(_activeDeliveries),
                _buildParcelList(_completedParcels),
              ],
            ),
          ),
        ),
      ],
    );
  }

  int _calculateTotalEarnings() {
    return _completedParcels.fold(
        0, (sum, parcel) => sum + (parcel.price?.toInt() ?? 0));
  }

  Widget _buildStatItem(IconData icon, String label, int count, Color color) {
    return Container(
      width: 80,
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(height: 2),
          Text(
            count.toString(),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildParcelList(List<Parcel> parcels) {
    if (widget.parcelState.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
        ),
      );
    }

    if (parcels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            SizedBox(height: 16),
            Text(
              'Aucun colis',
              style: TextStyle(
                color: Colors.grey.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Les colis apparaîtront ici',
              style: TextStyle(
                color: Colors.grey.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(12),
      itemCount: parcels.length,
      itemBuilder: (context, index) {
        final parcel = parcels[index];
        return _ParcelCard(
          parcel: parcel,
          onRefresh: () {
            _loadFreshUser();
            widget.onRefresh();
          },
        );
      },
    );
  }
}

// ==================== CARTE PARCEL ====================

class _ParcelCard extends StatefulWidget {
  final Parcel parcel;
  final VoidCallback onRefresh;

  const _ParcelCard({required this.parcel, required this.onRefresh});

  @override
  State<_ParcelCard> createState() => _ParcelCardState();
}

class _ParcelCardState extends State<_ParcelCard> {
  bool _isUpdating = false;

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color textPrimary = Color(0xFF1A2332);

  Color _getStatusColor(ParcelStatus status) {
    switch (status) {
      case ParcelStatus.pending:
        return Colors.orange;
      case ParcelStatus.free:
        return Colors.purple;
      case ParcelStatus.confirmed:
        return Colors.blue;
      case ParcelStatus.pickedUp:
        return Colors.purple;
      case ParcelStatus.inTransit:
        return Colors.indigo;
      case ParcelStatus.arrived:
        return Colors.teal;
      case ParcelStatus.outForDelivery:
        return Colors.lightBlue;
      case ParcelStatus.delivered:
        return Colors.green;
      case ParcelStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusIcon(ParcelStatus status) {
    switch (status) {
      case ParcelStatus.pending:
        return '⏳';
      case ParcelStatus.free:
        return '🔓';
      case ParcelStatus.confirmed:
        return '✅';
      case ParcelStatus.pickedUp:
        return '📦';
      case ParcelStatus.inTransit:
        return '🚚';
      case ParcelStatus.arrived:
        return '📍';
      case ParcelStatus.outForDelivery:
        return '🚛';
      case ParcelStatus.delivered:
        return '🎉';
      case ParcelStatus.cancelled:
        return '❌';
    }
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return "Aujourd'hui";
    } else if (targetDate == yesterday) {
      return 'Hier';
    } else {
      final difference = today.difference(targetDate).inDays;
      if (difference < 7) {
        return 'Il y a $difference jours';
      } else if (difference < 30) {
        final weeks = (difference / 7).floor();
        return 'Il y a $weeks semaine${weeks > 1 ? 's' : ''}';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatRelativeDate(date)} à ${_formatTime(date)}';
  }

  Future<void> _acceptDelivery() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Accepter la livraison'),
        content: Text(
            'Voulez-vous accepter la livraison du colis ${widget.parcel.trackingNumber} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Accepter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateStatus('picked_up');
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    final apiService = ApiService();
    try {
      await apiService.updateParcelStatus(widget.parcel.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut mis à jour'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _showDeliveryConfirmation() async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirmation de livraison'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Confirmez-vous la livraison du colis ?'),
            SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                hintText: 'Notes (optionnel)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateStatus('delivered');
    }
    notesController.dispose();
  }

  void _navigateToDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParcelDetailScreen(parcel: widget.parcel),
      ),
    ).then((_) {
      widget.onRefresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _navigateToDetail,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          _getStatusIcon(parcel.status),
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            parcel.trackingNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getStatusColor(parcel.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      parcel.status.label,
                      style: TextStyle(
                        fontSize: 10,
                        color: _getStatusColor(parcel.status),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 14, color: Colors.grey),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      parcel.receiverName,
                      style: TextStyle(fontSize: 13, color: textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      parcel.arrivalGarageName ??
                          parcel.receiverAddress ??
                          'Adresse non précisée',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Divider(color: Colors.grey.withValues(alpha: 0.2)),
              SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      parcel.formattedPrice,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: primaryBlue,
                      ),
                    ),
                  ),
                  Spacer(),
                  if (parcel.isUrgent)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.flash_on, size: 12, color: Colors.red),
                          SizedBox(width: 4),
                          Text(
                            'URGENT',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                  SizedBox(width: 6),
                  Text(
                    _formatDateTime(parcel.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              SizedBox(height: 12),
              if (!_isUpdating)
                _buildActionButtons()
              else
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final parcel = widget.parcel;

    if (parcel.status == ParcelStatus.pending ||
        parcel.status == ParcelStatus.confirmed) {
      return _buildActionButton(
        icon: Icons.check_circle,
        label: 'Accepter',
        color: Colors.green,
        onTap: _acceptDelivery,
      );
    } else if (parcel.status == ParcelStatus.pickedUp) {
      return _buildActionButton(
        icon: Icons.directions_car,
        label: 'Démarrer',
        color: Colors.blue,
        onTap: () => _updateStatus('in_transit'),
      );
    } else if (parcel.status == ParcelStatus.inTransit) {
      return _buildActionButton(
        icon: Icons.location_on,
        label: 'Arrivé garage',
        color: Colors.orange,
        onTap: () => _updateStatus('arrived'),
      );
    } else if (parcel.status == ParcelStatus.arrived) {
      return _buildActionButton(
        icon: Icons.delivery_dining,
        label: 'Partir livraison',
        color: Colors.purple,
        onTap: () => _updateStatus('out_for_delivery'),
      );
    } else if (parcel.status == ParcelStatus.outForDelivery) {
      return _buildActionButton(
        icon: Icons.check_circle,
        label: 'Livrer',
        color: Colors.green,
        onTap: _showDeliveryConfirmation,
      );
    }

    return SizedBox.shrink();
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: TextStyle(fontSize: 13),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}