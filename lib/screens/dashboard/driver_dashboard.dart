// mobile/lib/screens/dashboard/driver_dashboard.dart
// ignore_for_file: unused_import, deprecated_member_use, prefer_const_constructors, unused_element_parameter

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:procolis/models/parcel.dart';
import 'package:procolis/models/payment.dart';
import 'package:procolis/models/user.dart';
import 'package:procolis/models/voice_message.dart';
import 'package:procolis/screens/dashboard/notifications/notifications_screen.dart';
import 'package:procolis/services/api_service.dart';
import 'package:procolis/services/commission_service.dart';
import 'package:procolis/services/notification_service.dart';
import 'package:procolis/theme/app_theme.dart';
import 'package:record/record.dart';

import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/pc_components.dart';
import '../../widgets/procolis_design_system.dart';
import '../driver/create_annonce_sheet.dart';
import '../driver/revenus_screen.dart';
import '../driver/mes_annonces_screen.dart';
import '../driver/parametres_screen.dart';
import '../driver/points_screen.dart';
import '../driver/garage_screen.dart';
import '../driver/historique_screen.dart';
import '../driver/vehicle_documents_screen.dart';
import '../shared/messages_screen.dart';
import '../parcel/free_parcels_screen.dart';
import '../parcel/confirm_delivery_screen.dart';
import '../parcel/parcel_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../settings/settings_screen.dart';

// ==================== ÉCRAN DE CRÉATION D'ANNONCE POUR CHAUFFEUR ====================

class DriverCreateAdScreen extends ConsumerStatefulWidget {
  const DriverCreateAdScreen({super.key});

  @override
  ConsumerState<DriverCreateAdScreen> createState() =>
      _DriverCreateAdScreenState();
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
          if (parcel.departureGarageName.isNotEmpty) {
            locationSet.add(parcel.departureGarageName);
          }
          if (parcel.arrivalGarageName != null &&
              parcel.arrivalGarageName!.isNotEmpty) {
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
        debugPrint(
            '🎤 Upload de ${_voiceMessages.length} message(s) vocal(aux)...');
        for (int i = 0; i < _voiceMessages.length; i++) {
          final voiceMsg = _voiceMessages[i];
          try {
            final audioFile = XFile(voiceMsg.path);
            final url = await _apiService.uploadFile(file: audioFile, mediaType: 'audio');
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
'''
          .trim();

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

      final result =
          await ref.read(parcelProvider.notifier).createParcel(parcelData);

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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    if (_maxLengthController.text.isNotEmpty)
      parts.add('L: ${_maxLengthController.text}');
    if (_maxWidthController.text.isNotEmpty)
      parts.add('l: ${_maxWidthController.text}');
    if (_maxHeightController.text.isNotEmpty)
      parts.add('h: ${_maxHeightController.text}');
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
            color: Colors.black.withOpacity( 0.04),
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
              color: primaryBlue.withOpacity( 0.1),
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
            color: Colors.black.withOpacity( 0.04),
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
                  prefixIcon:
                      const Icon(Icons.departure_board, color: Colors.grey),
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
                    borderSide:
                        const BorderSide(color: primaryBlue, width: 1.5),
                  ),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Champ requis' : null,
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
                        color: Colors.black.withOpacity( 0.1),
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
                        leading: const Icon(Icons.location_on,
                            size: 16, color: Colors.grey),
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
                    borderSide:
                        const BorderSide(color: primaryBlue, width: 1.5),
                  ),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Champ requis' : null,
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
                        color: Colors.black.withOpacity( 0.1),
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
                        leading: const Icon(Icons.location_on,
                            size: 16, color: Colors.grey),
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
                        prefixIcon: const Icon(Icons.calendar_today,
                            color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: primaryBlue, width: 1.5),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Champ requis'
                          : null,
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
                        prefixIcon:
                            const Icon(Icons.access_time, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: primaryBlue, width: 1.5),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Champ requis'
                          : null,
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
            color: Colors.black.withOpacity( 0.04),
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
              if (double.parse(value) <= 0)
                return 'Le poids doit être supérieur à 0';
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
                    prefixIcon:
                        const Icon(Icons.straighten, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: primaryBlue, width: 1.5),
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
                    prefixIcon:
                        const Icon(Icons.straighten, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: primaryBlue, width: 1.5),
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
            color: Colors.black.withOpacity( 0.04),
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
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.red.shade200),
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
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 12),
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation(Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: _startRecording,
                                icon: const Icon(Icons.mic, size: 20),
                                label:
                                    const Text('Enregistrer un message vocal'),
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
            color: Colors.black.withOpacity( 0.04),
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
              hintText:
                  'Ajoutez des informations supplémentaires (conditions, restrictions, etc.)...',
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
    final hasData =
        departure.isNotEmpty || arrival.isNotEmpty || date.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryBlue.withOpacity( 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBlue.withOpacity( 0.2)),
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
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic),
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
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic),
            ),
          if (weight.isNotEmpty)
            Text(
              '📦 Capacité: ${weight} kg',
              style: TextStyle(fontSize: 13, color: textPrimary),
            )
          else
            Text(
              '📦 Capacité: Non définie',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic),
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
          if (!hasData &&
              _voiceMessages.isEmpty &&
              _notesController.text.isEmpty)
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
  int _unreadMessagesCount = 0;
  bool _isUpdatingStatus = false;
  final ApiService _dashApi = ApiService();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadNotificationsCount();
    _loadMessagesUnread();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      _loadNotificationsCount();
      _loadMessagesUnread();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _loadData() {
    Future.microtask(() {
      ref.read(parcelProvider.notifier).loadDriverParcels();
      ref.read(parcelProvider.notifier).loadFreeParcels();
    });
  }

  Future<void> _loadNotificationsCount() async {
    try {
      final c = await _dashApi.getUnreadNotificationsCount();
      if (mounted) setState(() => _unreadNotificationsCount = c);
    } catch (_) {}
  }

  /// Messages non-lus (conversations où je suis destinataire) + notification
  /// locale à la réception d'un nouveau message.
  Future<void> _loadMessagesUnread() async {
    final myId = ref.read(authProvider).user?.id;
    if (myId == null) return;
    try {
      final convs = await _dashApi.getConversations();
      int count = 0;
      Map<String, dynamic>? latest;
      for (final conv in convs) {
        final receiver = conv['receiver'] as Map<String, dynamic>?;
        final isRead = conv['isRead'] == true;
        if (receiver?['id']?.toString() == myId && !isRead) {
          count++;
          latest ??= conv;
        }
      }
      if (!mounted) return;
      final increased = count > _unreadMessagesCount;
      setState(() => _unreadMessagesCount = count);
      if (increased && latest != null) {
        final sender =
            latest['sender']?['fullName']?.toString() ?? 'Nouveau message';
        final body = latest['body']?.toString() ?? '';
        NotificationService.showNotification(
          id: 'procolis-drv-msg'.hashCode,
          title: '💬 $sender',
          body: body.isNotEmpty ? body : 'Vous avez reçu un nouveau message',
        );
      }
    } catch (_) {}
  }

  void _onNotificationsTap() {
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

  void _openPublishTrip() {
    showCreateAnnonceSheet(context).then((created) {
      if (created == true) {
        _loadData();
        setState(() => _selectedIndex = 1);
      }
    });
  }

  Future<void> _toggleAvailability() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final newStatus = user.isDriverAvailable ? 'offline' : 'available';
    setState(() => _isUpdatingStatus = true);
    await ref.read(authProvider.notifier).updateDriverStatus(newStatus);
    if (mounted) setState(() => _isUpdatingStatus = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final parcelState = ref.watch(parcelProvider);

    // Synchronise l'onglet avec la barre de navigation persistante (AppBottomNav)
    ref.listen<int>(dashboardTabProvider, (prev, next) {
      if (next != _selectedIndex && next >= 0 && next < 5) {
        setState(() => _selectedIndex = next);
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _getScreen(_selectedIndex, user, parcelState),
      bottomNavigationBar: ProcolisTabBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          ref.read(dashboardTabProvider.notifier).state = index;
        },
        items: [
          const ProcolisTabItem(
            icon: Icons.dashboard_rounded,
            label: 'Tableau',
          ),
          ProcolisTabItem(
            icon: Icons.sell_rounded,
            label: 'À prendre',
            badge: parcelState.freeParcels.length,
          ),
          ProcolisTabItem(
            icon: Icons.local_shipping_rounded,
            label: 'Missions',
            badge: parcelState.parcels.length,
          ),
          const ProcolisTabItem(
            icon: Icons.campaign_rounded,
            label: 'Annonces',
          ),
          const ProcolisTabItem(
            icon: Icons.person_rounded,
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _getScreen(int index, User? user, ParcelState parcelState) {
    switch (index) {
      case 0:
        return _DriverTableauScreen(
          parcelState: parcelState,
          user: user,
          onNotificationsTap: _onNotificationsTap,
          unreadNotificationsCount: _unreadNotificationsCount,
          unreadMessagesCount: _unreadMessagesCount,
          onViewMissions: () => setState(() => _selectedIndex = 2),
          onViewPool: () => setState(() => _selectedIndex = 1),
          onPublishTrip: _openPublishTrip,
          isUpdatingStatus: _isUpdatingStatus,
          onToggleAvailability: _toggleAvailability,
        );
      case 1:
        return _DriverPoolTabScreen(
          parcelState: parcelState,
          onRefresh: _loadData,
          onPublishTrip: _openPublishTrip,
        );
      case 2:
        return _DriverMissionsTabScreen(
          parcelState: parcelState,
          onRefresh: _loadData,
        );
      case 3:
        return const DriverMesAnnoncesScreen(embedded: true);
      case 4:
        return _DriverProfileTabScreen(
          user: user,
          activeMissionsCount: parcelState.parcels
              .where((parcel) =>
                  parcel.status == ParcelStatus.confirmed ||
                  parcel.status.isInProgress)
              .length,
        );
      default:
        return _DriverMissionsTabScreen(
          parcelState: parcelState,
          onRefresh: _loadData,
        );
    }
  }
}

/// Action de cycle de vie côté chauffeur : un seul bouton contextuel qui fait
/// avancer la mission (aligné sur le web MissionsScreen). L'étape `deliver`
/// bascule vers le flux OTP (ConfirmDeliveryScreen).
class _DriverStepAction {
  final String step;
  final String label;
  final IconData icon;
  const _DriverStepAction(this.step, this.label, this.icon);
}

_DriverStepAction? _driverNextStep(ParcelStatus status) {
  switch (status) {
    case ParcelStatus.pending:
      return const _DriverStepAction(
          'confirm', 'Confirmer la prise en charge', Icons.check_circle_rounded);
    case ParcelStatus.confirmed:
      return const _DriverStepAction(
          'pickup', 'Marquer ramassé', Icons.inventory_2_rounded);
    case ParcelStatus.pickedUp:
      return const _DriverStepAction(
          'transit', 'Marquer en transit', Icons.local_shipping_rounded);
    case ParcelStatus.inTransit:
      return const _DriverStepAction(
          'arrived', 'Marquer arrivé', Icons.pin_drop_rounded);
    case ParcelStatus.arrived:
      return const _DriverStepAction(
          'out-for-delivery', 'En livraison', Icons.delivery_dining_rounded);
    case ParcelStatus.outForDelivery:
      return const _DriverStepAction(
          'deliver', 'Confirmer livraison', Icons.task_alt_rounded);
    default:
      return null;
  }
}

class _DriverTableauScreen extends StatefulWidget {
  final ParcelState parcelState;
  final User? user;
  final VoidCallback onNotificationsTap;
  final int unreadNotificationsCount;
  final int unreadMessagesCount;
  final VoidCallback onViewMissions;
  final VoidCallback onViewPool;
  final VoidCallback onPublishTrip;
  final bool isUpdatingStatus;
  final Future<void> Function() onToggleAvailability;

  const _DriverTableauScreen({
    required this.parcelState,
    required this.user,
    required this.onNotificationsTap,
    required this.unreadNotificationsCount,
    required this.unreadMessagesCount,
    required this.onViewMissions,
    required this.onViewPool,
    required this.onPublishTrip,
    required this.isUpdatingStatus,
    required this.onToggleAvailability,
  });

  @override
  State<_DriverTableauScreen> createState() => _DriverTableauScreenState();
}

class _DriverTableauScreenState extends State<_DriverTableauScreen> {
  final ApiService _api = ApiService();
  double? _walletBalance;
  List<Map<String, dynamic>> _bidsSent = [];
  List<Map<String, dynamic>> _ads = [];
  double _weekRevenue = 0;
  List<double> _revenueBars = List<double>.filled(7, 0);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final results = await Future.wait([
      _api.getWalletBalance(widget.user?.id ?? ''),
      _api.getDriverBidsSent(),
      _api.getMyAdvertisements(),
      _api.getPaymentHistory(),
    ]);
    if (!mounted) return;
    final payments = results[3] as List<Map<String, dynamic>>;
    final now = DateTime.now();
    final weekStart =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final bars = List<double>.filled(7, 0);
    double weekTotal = 0;
    for (final p in payments) {
      final amount = (p['amount'] ?? 0).toDouble();
      try {
        final date = DateTime.parse(p['createdAt']?.toString() ?? '');
        final dayIndex = date.difference(weekStart).inDays;
        if (dayIndex >= 0 && dayIndex < 7) {
          bars[dayIndex] += amount;
          weekTotal += amount;
        }
      } catch (_) {}
    }
    setState(() {
      _walletBalance = results[0] as double;
      _bidsSent = results[1] as List<Map<String, dynamic>>;
      _ads = results[2] as List<Map<String, dynamic>>;
      _revenueBars = bars;
      _weekRevenue = weekTotal;
    });
  }

  void _openItinerary(Parcel parcel) {
    context.push('/driver/itinerary', extra: {
      'departureName': parcel.departureGarageName,
      'arrivalName': parcel.arrivalGarageName ?? '',
    });
  }

  String _fcfa(num value) {
    return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (match) => '${match[1]} ',
        );
  }

  List<Parcel> get _activeMissions {
    final missions = widget.parcelState.parcels
        .where((parcel) =>
            parcel.status.isInProgress ||
            parcel.status == ParcelStatus.confirmed)
        .toList();
    return missions.isNotEmpty ? missions : widget.parcelState.parcels;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final activeMission =
        _activeMissions.isNotEmpty ? _activeMissions.first : null;
    final availableParcel = widget.parcelState.freeParcels.isNotEmpty
        ? widget.parcelState.freeParcels.first
        : null;
    final deliveries = user?.completedDeliveries ?? user?.totalDeliveries ?? 0;
    final activeCount = _activeMissions.length;
    final wallet =
        _walletBalance != null ? '${_fcfa(_walletBalance!)}' : '—';
    final rating =
        (user?.rating ?? 4.9).toStringAsFixed(1).replaceAll('.', ',');

    return Column(
      children: [
        _buildHero(user),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 96),
            children: [
              GridView.count(
                crossAxisCount: 2,
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.24,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverPointsScreen())),
                    child: PcStatBox(
                      icon: Icons.account_balance_wallet_rounded,
                      value: '$wallet FCFA',
                      label: 'Portefeuille',
                      tone: PcTone.amber,
                    ),
                  ),
                  PcStatBox(
                    icon: Icons.local_shipping_rounded,
                    value: '$activeCount',
                    label: 'Missions actives',
                    tone: PcTone.primary,
                  ),
                  PcStatBox(
                    icon: Icons.task_alt_rounded,
                    value: '$deliveries',
                    label: 'Livraisons',
                    tone: PcTone.green,
                  ),
                  PcStatBox(
                    icon: Icons.star_rounded,
                    value: rating,
                    label: 'Note moyenne',
                    tone: PcTone.amber,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverPointsScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.amberGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_circle_rounded, color: AppTheme.amberOnFg, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Recharger mon portefeuille', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.amberOnFg)),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppTheme.amberOnFg),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _PublishTripShortcut(onTap: widget.onPublishTrip),
              const SizedBox(height: 28),
              PcSectionHeader(
                'Mission en cours',
                action: 'Voir tout',
                onAction: widget.onViewMissions,
              ),
              if (activeMission != null)
                _DriverRouteCard(
                  parcel: activeMission,
                  primaryActionLabel: 'Continuer la livraison',
                  primaryActionIcon: Icons.arrow_forward_rounded,
                  onPrimaryAction: widget.onViewMissions,
                  customFooter: Row(
                    children: [
                      Expanded(
                        child: PcButton(
                          'Itinéraire',
                          icon: Icons.navigation_rounded,
                          variant: PcButtonVariant.secondary,
                          block: true,
                          onPressed: () => _openItinerary(activeMission),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PcButton(
                          'Gérer',
                          icon: Icons.checklist_rounded,
                          block: true,
                          onPressed: widget.onViewMissions,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const PcEmptyState(
                  icon: Icons.local_shipping_rounded,
                  title: 'Aucune mission en cours',
                  message: 'Les missions acceptées apparaîtront ici.',
                  tone: PcTone.primary,
                ),
              const SizedBox(height: 28),
              PcSectionHeader(
                'Colis à prendre',
                action: 'Tout voir',
                onAction: widget.onViewPool,
              ),
              if (availableParcel != null)
                _DriverRouteCard(
                  parcel: availableParcel,
                  footerText: '240 km',
                  primaryActionLabel: 'Faire une offre',
                  primaryActionIcon: Icons.gavel_rounded,
                  onPrimaryAction: widget.onViewPool,
                )
              else
                const PcEmptyState(
                  icon: Icons.sell_rounded,
                  title: 'Aucun colis disponible',
                  message: 'Les colis en libre service apparaîtront ici.',
                  tone: PcTone.amber,
                ),
              const SizedBox(height: 28),
              _buildRevenuePanel(),
              const SizedBox(height: 28),
              _buildBidsPanel(),
              const SizedBox(height: 28),
              _buildAdsPanel(),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Revenus · 7 jours (mini graphique, logique de revenus_screen) ----
  Widget _buildRevenuePanel() {
    return PcCard(
      radius: AppTheme.radiusLg,
      shadow: AppTheme.shadowSm(),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Revenus · 7 jours',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DriverRevenusScreen()),
                ),
                child: const Text(
                  'Voir tout',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_fcfa(_weekRevenue)} FCFA',
            style: AppTheme.mono(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _RevenueMiniChart(bars: _revenueBars),
        ],
      ),
    );
  }

  // ---- Mes offres (offres envoyées par le chauffeur) ----
  Widget _buildBidsPanel() {
    final top = _bidsSent.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PcSectionHeader('Mes offres'),
        PcCard(
          padding: EdgeInsets.zero,
          child: top.isEmpty
              ? const PcEmptyState(
                  icon: Icons.gavel_rounded,
                  title: 'Aucune offre envoyée',
                  message: 'Vos offres sur les annonces apparaîtront ici.',
                  tone: PcTone.amber,
                )
              : Column(
                  children: [
                    for (var i = 0; i < top.length; i++) ...[
                      if (i > 0) const PcDivider(),
                      _buildBidRow(top[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildBidRow(Map<String, dynamic> bid) {
    final status = bid['status']?.toString() ?? 'pending';
    final price = (bid['price'] ?? 0).toDouble();
    final parcelId = bid['parcelId']?.toString() ?? '';
    final tracking = bid['parcel']?['trackingNumber']?.toString() ??
        (parcelId.length > 8 ? '${parcelId.substring(0, 8)}…' : parcelId);
    late final String statusLabel;
    late final PcTone statusTone;
    switch (status) {
      case 'accepted':
        statusLabel = 'Acceptée';
        statusTone = PcTone.green;
        break;
      case 'rejected':
        statusLabel = 'Refusée';
        statusTone = PcTone.red;
        break;
      default:
        statusLabel = 'En attente';
        statusTone = PcTone.amber;
    }
    return PcListRow(
      icon: Icons.gavel_rounded,
      iconTone: PcTone.primary,
      title: tracking,
      subtitle: '${_fcfa(price)} FCFA proposés',
      trailing: PcBadge(statusLabel, tone: statusTone),
    );
  }

  // ---- Mes annonces (trajets publiés par le chauffeur) ----
  Widget _buildAdsPanel() {
    final top = _ads.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PcSectionHeader(
          'Mes annonces',
          action: 'Voir tout',
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DriverMesAnnoncesScreen()),
          ),
        ),
        PcCard(
          padding: EdgeInsets.zero,
          child: top.isEmpty
              ? const PcEmptyState(
                  icon: Icons.campaign_rounded,
                  title: 'Aucune annonce',
                  message: 'Publiez un trajet pour recevoir des colis.',
                  tone: PcTone.primary,
                )
              : Column(
                  children: [
                    for (var i = 0; i < top.length; i++) ...[
                      if (i > 0) const PcDivider(),
                      _buildAdRow(top[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildAdRow(Map<String, dynamic> ad) {
    final departure = ad['departureCity']?.toString() ?? '—';
    final arrival = ad['arrivalCity']?.toString() ?? '—';
    final proposedPrice = ad['proposedPrice'];
    return PcListRow(
      icon: Icons.local_shipping_rounded,
      iconTone: PcTone.primary,
      title: '$departure → $arrival',
      subtitle: 'Trajet publié',
      trailing: proposedPrice != null
          ? Text(
              '${_fcfa((proposedPrice as num).toDouble())} FCFA',
              style: AppTheme.mono(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.teal600,
              ),
            )
          : null,
    );
  }

  Widget _buildHero(User? user) {
    final available = user?.isDriverAvailable ?? false;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 31,
                        backgroundColor: const Color(0xFFC9F3EE),
                        child: Text(
                          user?.initials ?? 'PC',
                          style: const TextStyle(
                            color: AppTheme.teal700,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -1,
                        bottom: 3,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: available
                                ? AppTheme.green500
                                : AppTheme.slate400,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chauffeur',
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          user?.fullName ?? 'Chauffeur',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MessagesScreen()),
                    ),
                    color: Colors.white,
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.chat_rounded, size: 26),
                        if (widget.unreadMessagesCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.amber400,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                widget.unreadMessagesCount > 9
                                    ? '9+'
                                    : '${widget.unreadMessagesCount}',
                                style: const TextStyle(
                                    color: Color(0xFF3A2600),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onNotificationsTap,
                    color: Colors.white,
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_rounded, size: 28),
                        if (widget.unreadNotificationsCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.amber400,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppTheme.teal600, width: 2),
                              ),
                              child: Text(
                                widget.unreadNotificationsCount > 99 ? '99+' : '${widget.unreadNotificationsCount}',
                                style: const TextStyle(
                                  color: Color(0xFF3A2600),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity( 0.20),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity( 0.18),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Icon(
                        available ? Icons.bolt_rounded : Icons.bedtime_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            available ? 'Vous êtes en ligne' : 'Hors ligne',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            available
                                ? 'Vous recevez les colis disponibles'
                                : 'Vous ne recevez pas de colis',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    widget.isUpdatingStatus
                        ? const SizedBox(
                            width: 40,
                            height: 24,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              ),
                            ),
                          )
                        : Switch(
                            value: available,
                            activeColor: Colors.white,
                            activeTrackColor: AppTheme.deep500,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: Colors.white24,
                            onChanged: (_) => widget.onToggleAvailability(),
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

class _PublishTripShortcut extends StatelessWidget {
  final VoidCallback onTap;

  const _PublishTripShortcut({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: AppTheme.brandShadow(),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity( 0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Publier un voyage',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Annoncez votre trajet aux clients',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        color: Colors.white70,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverRouteCard extends StatelessWidget {
  final Parcel parcel;
  final String? footerText;
  final Widget? customFooter;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final VoidCallback onPrimaryAction;
  final bool showPrimaryAction;
  final VoidCallback? onTap;

  const _DriverRouteCard({
    required this.parcel,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
    required this.onPrimaryAction,
    this.footerText,
    this.customFooter,
    this.showPrimaryAction = true,
    this.onTap,
  });

  String _formatFcfa(double amount) {
    final rawAmount = amount.toStringAsFixed(0);
    // Sépare les milliers sans dépendre d'une locale système indisponible
    // dans certains environnements Flutter de test.
    return rawAmount.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]} ',
    );
  }

  @override
  Widget build(BuildContext context) {
    final price =
        parcel.price ?? parcel.proposedPrice ?? parcel.negotiatedPrice ?? 0;
    final destination = parcel.arrivalGarageName?.isNotEmpty == true
        ? parcel.arrivalGarageName!
        : 'Arrivée';

    return PcCard(
      onTap: onTap,
      radius: AppTheme.radiusLg,
      shadow: AppTheme.shadowSm(),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded,
                  size: 20, color: AppTheme.slate400),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  parcel.trackingNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.mono(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate700,
                  ),
                ),
              ),
              ProcolisStatusBadge(status: parcel.status),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: _RouteEndpoint(
                  label: 'DÉPART',
                  value: parcel.departureGarageName,
                  alignEnd: false,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(
                  Icons.local_shipping_rounded,
                  color: AppTheme.primary,
                  size: 28,
                ),
              ),
              Expanded(
                child: _RouteEndpoint(
                  label: 'ARRIVÉE',
                  value: destination,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              _RouteMeta(
                icon: Icons.shopping_bag_outlined,
                value:
                    '${parcel.weight.toStringAsFixed(parcel.weight.truncateToDouble() == parcel.weight ? 0 : 1)} kg',
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _RouteMeta(
                  icon: Icons.category_outlined,
                  value: parcel.type.label,
                ),
              ),
              const SizedBox(width: 14),
              const _RouteMeta(icon: Icons.schedule_rounded, value: '~4 h'),
              const SizedBox(width: 18),
              Text(
                '${_formatFcfa(price)}\nFCFA',
                textAlign: TextAlign.left,
                style: AppTheme.mono(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.deep500,
                ),
              ),
            ],
          ),
          if (customFooter != null) ...[
            const SizedBox(height: 18),
            customFooter!,
          ] else if (footerText != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.route_rounded,
                    size: 18, color: AppTheme.slate500),
                const SizedBox(width: 6),
                Text(
                  footerText!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                PcButton(
                  primaryActionLabel,
                  icon: primaryActionIcon,
                  size: PcButtonSize.sm,
                  onPressed: onPrimaryAction,
                ),
              ],
            ),
          ] else if (showPrimaryAction) ...[
            const SizedBox(height: 22),
            PcButton(
              primaryActionLabel,
              iconTrailing: primaryActionIcon,
              block: true,
              size: PcButtonSize.lg,
              onPressed: onPrimaryAction,
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteEndpoint extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _RouteEndpoint({
    required this.label,
    required this.value,
    required this.alignEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.slate400,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RouteMeta extends StatelessWidget {
  final IconData icon;
  final String value;

  const _RouteMeta({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppTheme.slate400),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// Mini graphique à barres 7 jours (dessiné à la main, calé sur revenus_screen).
class _RevenueMiniChart extends StatelessWidget {
  final List<double> bars;

  const _RevenueMiniChart({required this.bars});

  static const List<String> _dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final maxValue = bars.isEmpty ? 0.0 : bars.reduce(max);
    return Column(
      children: [
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(bars.length, (i) {
              final isLast = i == bars.length - 1;
              final fraction = maxValue > 0 ? bars[i] / maxValue : 0.0;
              final opacity = isLast
                  ? 1.0
                  : (0.55 + (i / bars.length) * 0.45).clamp(0.0, 1.0);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 4, right: isLast ? 0 : 4),
                  child: FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor: fraction.clamp(0.04, 1.0),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isLast
                              ? null
                              : const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [AppTheme.teal400, AppTheme.teal600],
                                ),
                          color: isLast ? AppTheme.amber400 : null,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(5)),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(_dayLabels.length, (i) {
            return Expanded(
              child: Text(
                _dayLabels[i],
                textAlign: TextAlign.center,
                style: AppTheme.mono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate400,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ==================== TAB À PRENDRE ====================

class _DriverPoolTabScreen extends StatefulWidget {
  final ParcelState parcelState;
  final VoidCallback onRefresh;
  final VoidCallback onPublishTrip;

  const _DriverPoolTabScreen({
    required this.parcelState,
    required this.onRefresh,
    required this.onPublishTrip,
  });

  @override
  State<_DriverPoolTabScreen> createState() => _DriverPoolTabScreenState();
}

class _DriverPoolTabScreenState extends State<_DriverPoolTabScreen> {
  String _selectedFilter = 'Tous';

  List<String> get _filters => const [
        'Tous',
        'Abidjan →',
        'Express',
        '< 10 kg',
        'Aujourd’hui',
        'Avec offres',
      ];

  List<Parcel> get _filteredParcels {
    final parcels = widget.parcelState.freeParcels;
    switch (_selectedFilter) {
      case 'Abidjan →':
        return parcels
            .where((parcel) =>
                parcel.departureGarageName.toLowerCase().contains('abidjan'))
            .toList();
      case 'Express':
        return parcels.where((parcel) => parcel.isUrgent).toList();
      case '< 10 kg':
        return parcels.where((parcel) => parcel.weight < 10).toList();
      case 'Aujourd’hui':
        final now = DateTime.now();
        return parcels
            .where((parcel) =>
                parcel.createdAt.year == now.year &&
                parcel.createdAt.month == now.month &&
                parcel.createdAt.day == now.day)
            .toList();
      case 'Avec offres':
        return parcels.where((parcel) => parcel.bids.isNotEmpty).toList();
      default:
        return parcels;
    }
  }

  String _poolFooter(Parcel parcel) {
    // Les maquettes exposent une distance statique; tant que l'API ne fournit
    // pas cette donnée, on conserve un fallback visuel stable.
    final offers = parcel.bids.length;
    return '240 km · $offers offre${offers > 1 ? 's' : ''}';
  }

  Future<void> _refresh() async => widget.onRefresh();

  void _openOffer(Parcel parcel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FreeParcelDetailsScreen(parcel: parcel),
      ),
    ).then((_) => widget.onRefresh());
  }

  @override
  Widget build(BuildContext context) {
    final parcels = _filteredParcels;

    return Column(
      children: [
        _DriverTabHeader(
          title: 'Colis à prendre',
          subtitle:
              '${widget.parcelState.freeParcels.length} opportunité(s) disponibles',
          icon: Icons.sell_rounded,
          actionIcon: Icons.refresh_rounded,
          onAction: widget.onRefresh,
        ),
        SizedBox(
          height: 52,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _filters[index];
              return _DriverFilterChip(
                label: filter,
                selected: _selectedFilter == filter,
                onTap: () => setState(() => _selectedFilter = filter),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: _PublishTripShortcut(onTap: widget.onPublishTrip),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: _refresh,
            child: widget.parcelState.isLoadingFreeParcels
                ? const Center(child: CircularProgressIndicator())
                : parcels.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(24, 90, 24, 120),
                        children: const [
                          PcEmptyState(
                            icon: Icons.inventory_2_rounded,
                            title: 'Aucun colis à prendre',
                            message:
                                'Les demandes clients en libre service apparaîtront ici.',
                            tone: PcTone.amber,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                        itemCount: parcels.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final parcel = parcels[index];
                          return _DriverRouteCard(
                            parcel: parcel,
                            footerText: _poolFooter(parcel),
                            primaryActionLabel: 'Faire une offre',
                            primaryActionIcon: Icons.gavel_rounded,
                            onPrimaryAction: () => _openOffer(parcel),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

// ==================== TAB MISSIONS ====================

class _DriverMissionsTabScreen extends StatefulWidget {
  final ParcelState parcelState;
  final VoidCallback onRefresh;

  const _DriverMissionsTabScreen({
    required this.parcelState,
    required this.onRefresh,
  });

  @override
  State<_DriverMissionsTabScreen> createState() =>
      _DriverMissionsTabScreenState();
}

class _DriverMissionsTabScreenState extends State<_DriverMissionsTabScreen> {
  int _tabIndex = 0;
  final ApiService _api = ApiService();
  String? _advancingId;

  Future<void> _advanceMission(Parcel mission, String step) async {
    setState(() => _advancingId = mission.id);
    try {
      final res = await _api.advanceParcel(mission.id, step);
      if (res['success'] == false) {
        _snack(res['message']?.toString() ?? 'Action impossible');
      } else {
        widget.onRefresh();
      }
    } catch (_) {
      _snack('Action impossible');
    } finally {
      if (mounted) setState(() => _advancingId = null);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<Parcel> get _activeMissions => widget.parcelState.parcels
      .where((parcel) =>
          parcel.status == ParcelStatus.pending ||
          parcel.status == ParcelStatus.confirmed ||
          parcel.status.isInProgress)
      .toList();

  List<Parcel> get _completedMissions => widget.parcelState.parcels
      .where((parcel) => parcel.status == ParcelStatus.delivered)
      .toList();

  List<Parcel> get _visibleMissions =>
      _tabIndex == 0 ? _activeMissions : _completedMissions;

  Future<void> _refresh() async => widget.onRefresh();

  void _openMission(Parcel parcel) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ParcelDetailScreen(parcel: parcel)),
    ).then((_) => widget.onRefresh());
  }

  void _openConfirmDelivery(Parcel parcel) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmDeliveryScreen(parcel: parcel),
      ),
    ).then((updated) {
      if (updated == true) widget.onRefresh();
    });
  }

  Widget _buildMissionFooter(Parcel mission) {
    final commissionEstimate =
        mission.price != null ? CommissionService.calculate(mission.price!) : 0;
    final commissionLabel =
        mission.status.isCompleted ? 'Commission: ${commissionEstimate.toStringAsFixed(0)} FCFA' : 'Commission est.: ${commissionEstimate.toStringAsFixed(0)} FCFA';
    final client =
        mission.senderName.isNotEmpty ? mission.senderName : 'Client Procolis';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              commissionLabel,
              style: AppTheme.mono(
                color: AppTheme.slate500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                'Client · $client',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (_driverNextStep(mission.status) != null) ...[
          const SizedBox(height: 10),
          Builder(builder: (_) {
            final next = _driverNextStep(mission.status)!;
            final loading = _advancingId == mission.id;
            return PcButton(
              next.label,
              icon: next.icon,
              block: true,
              loading: loading,
              onPressed: loading
                  ? null
                  : () => next.step == 'deliver'
                      ? _openConfirmDelivery(mission)
                      : _advanceMission(mission, next.step),
            );
          }),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final missions = _visibleMissions;

    return Column(
      children: [
        _DriverTabHeader(
          title: 'Mes missions',
          subtitle:
              '${_activeMissions.length} active(s) · ${_completedMissions.length} terminée(s)',
          icon: Icons.local_shipping_rounded,
          actionIcon: Icons.refresh_rounded,
          onAction: widget.onRefresh,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.slate200),
            ),
            child: Row(
              children: [
                _DriverSegmentButton(
                  label: 'Actives',
                  count: _activeMissions.length,
                  selected: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                _DriverSegmentButton(
                  label: 'Terminées',
                  count: _completedMissions.length,
                  selected: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: _refresh,
            child: widget.parcelState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : missions.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(24, 90, 24, 120),
                        children: [
                          PcEmptyState(
                            icon: _tabIndex == 0
                                ? Icons.route_rounded
                                : Icons.task_alt_rounded,
                            title: _tabIndex == 0
                                ? 'Aucune mission active'
                                : 'Aucune mission terminée',
                            message: _tabIndex == 0
                                ? 'Acceptez un colis à prendre pour démarrer une mission.'
                                : 'Vos livraisons complétées seront visibles ici.',
                            tone: _tabIndex == 0
                                ? PcTone.primary
                                : PcTone.green,
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                        itemCount: missions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final mission = missions[index];
                          return _DriverRouteCard(
                            parcel: mission,
                            customFooter: _buildMissionFooter(mission),
                            showPrimaryAction: false,
                            primaryActionLabel: 'Voir la mission',
                            primaryActionIcon: Icons.arrow_forward_rounded,
                            onTap: () => _openMission(mission),
                            onPrimaryAction: () => _openMission(mission),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

// ==================== TAB PROFIL CHAUFFEUR ====================

class _DriverProfileTabScreen extends ConsumerWidget {
  final User? user;
  final int activeMissionsCount;

  const _DriverProfileTabScreen({
    required this.user,
    required this.activeMissionsCount,
  });

  int get _deliveries =>
      user?.completedDeliveries ?? user?.totalDeliveries ?? 0;

  double get _walletBalance => user?.walletBalance ?? 0;

  String get _rating =>
      (user?.rating ?? 4.9).toStringAsFixed(1).replaceAll('.', ',');

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  Future<void> _logout(WidgetRef ref) async {
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = user?.fullName ?? 'Chauffeur';
    final status = user?.driverStatus ?? DriverStatus.available;

    return Column(
      children: [
        _DriverTabHeader(
          title: 'Profil',
          subtitle: 'Compte chauffeur et préférences',
          icon: Icons.person_rounded,
          actionIcon: Icons.settings_rounded,
          onAction: () => _openSettings(context),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 104),
            children: [
              ProcolisCard(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: AppTheme.primaryLight,
                          child: Text(
                            user?.initials ?? 'PC',
                            style: const TextStyle(
                              color: AppTheme.teal700,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: 6,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: status.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppTheme.amber500, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          _rating,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          ' · ',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        Text(
                          '$_deliveries livraisons',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded,
                              color: AppTheme.primary, size: 17),
                          SizedBox(width: 6),
                          Text(
                            'Chauffeur vérifié',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _DriverProfileStat(
                      icon: Icons.account_balance_wallet_rounded,
                      value: '${_walletBalance.toStringAsFixed(0)} FCFA',
                      label: 'Solde',
                      tone: AppTheme.amber500,
                      background: AppTheme.amber50,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DriverProfileStat(
                      icon: Icons.local_shipping_rounded,
                      value: '$activeMissionsCount',
                      label: 'En cours',
                      tone: AppTheme.primary,
                      background: AppTheme.primaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ProcolisCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _DriverProfileRow(
                      icon: Icons.garage_rounded,
                      title: 'Ma zone',
                      subtitle: user?.garageName ?? 'Zone non renseignée',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const DriverGarageScreen())),
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.directions_car_rounded,
                      title: 'Véhicule',
                      subtitle:
                          '${user?.vehicleModel ?? 'Véhicule'} · ${user?.vehiclePlate ?? 'Plaque non renseignée'}',
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.description_rounded,
                      title: 'Documents & permis',
                      subtitle: 'À jour',
                      trailing: const Icon(Icons.verified_rounded,
                          color: AppTheme.successColor),
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.payments_rounded,
                      title: 'Revenus',
                      subtitle: 'Gains et historique des paiements',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const DriverRevenusScreen())),
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Portefeuille & crédits',
                      subtitle: 'Solde FCFA et recharge',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const DriverPointsScreen())),
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.campaign_rounded,
                      title: 'Mes annonces',
                      subtitle: 'Gérer mes trajets publiés',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const DriverMesAnnoncesScreen())),
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.badge_rounded,
                      title: 'Documents & véhicule',
                      subtitle: 'Photos et papiers du véhicule',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const VehicleDocumentsScreen())),
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.forum_rounded,
                      title: 'Messages',
                      subtitle: 'Discussions avec les clients',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const MessagesScreen())),
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.history_rounded,
                      title: 'Historique',
                      subtitle: 'Courses terminées et annulées',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const DriverHistoriqueScreen())),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ProcolisCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _DriverProfileRow(
                      icon: Icons.settings_rounded,
                      title: 'Paramètres véhicule & PIN',
                      subtitle: 'Véhicule, sécurité',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const DriverParametresScreen())),
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.help_rounded,
                      title: 'Aide & support',
                      subtitle: 'Centre d’assistance chauffeur',
                    ),
                    const Divider(height: 1),
                    _DriverProfileRow(
                      icon: Icons.logout_rounded,
                      title: 'Se déconnecter',
                      subtitle: 'Quitter la session',
                      destructive: true,
                      trailing: const SizedBox.shrink(),
                      onTap: () => _logout(ref),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'PRO COLIS · Chauffeur',
                  style: AppTheme.mono(
                    fontSize: 12,
                    color: AppTheme.slate400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DriverTabHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _DriverTabHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onAction,
                icon: Icon(actionIcon, color: AppTheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DriverFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.cardColor,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.textSecondary,
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? AppTheme.primary : AppTheme.slate200,
        ),
      ),
    );
  }
}

class _DriverSegmentButton extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _DriverSegmentButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Text(
            '$label ($count)',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverProfileStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color tone;
  final Color background;

  const _DriverProfileStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.tone,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return ProcolisCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, color: tone, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _DriverProfileRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  const _DriverProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppTheme.red500 : AppTheme.textPrimary;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: destructive ? AppTheme.red50 : AppTheme.slate100,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(
            icon,
            color: destructive ? AppTheme.red500 : AppTheme.slate600,
            size: 21,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: trailing ??
            const Icon(Icons.chevron_right_rounded, color: AppTheme.slate400),
      ),
    );
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

      _clientRequests = freeParcels
          .where((p) =>
              p.senderId != user.id &&
              p.senderPhone != user.phone &&
              !_isDriver(p))
          .toList();

      _myAds = freeParcels
          .where((p) => p.senderId == user.id || p.senderPhone == user.phone)
          .toList();

      debugPrint(
          '✅ Demandes clients: ${_clientRequests.length}, Mes annonces: ${_myAds.length}');
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
    List<Parcel> ads = _tabController.index == 0 ? _clientRequests : _myAds;

    switch (_selectedFilter) {
      case 'active':
        return ads
            .where((p) =>
                p.status == ParcelStatus.free ||
                p.status == ParcelStatus.pending)
            .toList();
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
                          DropdownMenuItem(
                              value: 'all', child: Text('📋 Toutes')),
                          DropdownMenuItem(
                              value: 'active', child: Text('🔄 Actives')),
                          DropdownMenuItem(
                              value: 'with_bids',
                              child: Text('💰 Avec offres')),
                          DropdownMenuItem(
                              value: 'confirmed', child: Text('✅ Confirmées')),
                          DropdownMenuItem(
                              value: 'delivered', child: Text('🎉 Livrées')),
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
            color: Colors.black.withOpacity( 0.06),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity( 0.15),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity( 0.15),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity( 0.15),
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
                  Icon(Icons.arrow_downward,
                      size: 10, color: Colors.grey.shade400),
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
                if (parcel.notes != null &&
                    parcel.notes!.contains('Capacité max:'))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fitness_center,
                            size: 12, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          _extractFromNotes(parcel.notes!, 'Capacité max'),
                          style: TextStyle(
                              fontSize: 11, color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ),
                if (parcel.notes != null && parcel.notes!.contains('Départ:'))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today,
                            size: 12, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text(
                          _extractFromNotes(parcel.notes!, 'Départ'),
                          style: TextStyle(
                              fontSize: 11, color: Colors.orange.shade700),
                        ),
                      ],
                    ),
                  ),
                if (parcel.isUrgent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flash_on,
                            size: 12, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Urgent',
                          style: TextStyle(
                              fontSize: 11, color: Colors.red.shade700),
                        ),
                      ],
                    ),
                  ),
                if (parcel.isInsured)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield,
                            size: 12, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Assuré',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blue.shade700),
                        ),
                      ],
                    ),
                  ),
                if (parcel.audioUrls.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.mic,
                            size: 12, color: Colors.purple.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Message vocal',
                          style: TextStyle(
                              fontSize: 11, color: Colors.purple.shade700),
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
                color: primaryBlue.withOpacity( 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isClientRequests ? Icons.people_rounded : Icons.local_shipping,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
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
    showCreateAnnonceSheet(context).then((created) {
      if (created == true) {
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
            ? Colors.green.withOpacity( 0.08)
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
            backgroundColor: primaryBlue.withOpacity( 0.1),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
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
                    Icon(Icons.access_time,
                        size: 12, color: Colors.grey.shade500),
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
              color: bid.status.color.withOpacity( 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: bid.status.color.withOpacity( 0.3),
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
        .where((p) =>
            p.status == ParcelStatus.pending ||
            p.status == ParcelStatus.confirmed)
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
                              color: Colors.black.withOpacity( 0.2),
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
                                      color:
                                          Colors.white.withOpacity( 0.3),
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.white.withOpacity( 0.3),
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
                    Consumer(
                      builder: (context, ref, child) {
                        final walletState = ref.watch(walletProvider);
                        final walletBalance = walletState.balance;
                        return GestureDetector(
                          onTap: () => context.push('/driver/points'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0B6E3A), Color(0xFF0D8C46)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF0B6E3A).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${walletBalance.toStringAsFixed(0)} FCFA',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
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
        color: Colors.white.withOpacity( 0.15),
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
              color: Colors.white.withOpacity( 0.8),
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
              color: Colors.grey.withOpacity( 0.3),
            ),
            SizedBox(height: 16),
            Text(
              'Aucun colis',
              style: TextStyle(
                color: Colors.grey.withOpacity( 0.6),
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Les colis apparaîtront ici',
              style: TextStyle(
                color: Colors.grey.withOpacity( 0.5),
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

  String _statusToStep(String status) {
    switch (status) {
      case 'picked_up': return 'pickup';
      case 'in_transit': return 'transit';
      case 'arrived': return 'arrived';
      case 'out_for_delivery': return 'out-for-delivery';
      case 'confirmed': return 'confirm';
      case 'delivered': return 'deliver';
      default: return status;
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);
    final apiService = ApiService();
    try {
      await apiService.advanceParcel(widget.parcel.id, _statusToStep(newStatus));
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
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmDeliveryScreen(parcel: widget.parcel),
      ),
    );

    if (updated == true && mounted) {
      widget.onRefresh();
    }
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
                      color: _getStatusColor(parcel.status)
                          .withOpacity( 0.15),
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
                  Icon(Icons.location_on_outlined,
                      size: 14, color: Colors.grey),
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
              Divider(color: Colors.grey.withOpacity( 0.2)),
              SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity( 0.1),
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
                        color: Colors.red.withOpacity( 0.1),
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
        label: 'Arrivé zone',
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
        icon: Icons.lock_open_rounded,
        label: 'Confirmer livraison',
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
