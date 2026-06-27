// mobile/lib/screens/parcel/new_parcel_screen.dart
// Ignorer les warnings
// ignore_for_file: unused_import, unused_field, unused_element, unused_local_variable, deprecated_member_use, unnecessary_string_interpolations

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:contacts_service_plus/contacts_service_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:procolis/providers/score_provider.dart';
import 'package:record/record.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import '../../models/garage.dart';
import '../../models/parcel.dart';
import '../../models/payment.dart';
import '../../models/user.dart';
import '../../models/voice_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/phone_contact_picker.dart';
import 'free_parcels_screen.dart';
import 'parcel_detail_screen.dart';

// Extension pour ajouter label à PaymentMethod
extension PaymentMethodExtension on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Espèces';
      case PaymentMethod.orangeMoney:
        return 'Orange Money';
      case PaymentMethod.wave:
        return 'Wave';
      case PaymentMethod.freeMoney:
        return 'Free Money';
      case PaymentMethod.card:
        return 'Carte bancaire';
    }
  }
}

class NewParcelScreen extends ConsumerStatefulWidget {
  const NewParcelScreen({super.key});

  @override
  ConsumerState<NewParcelScreen> createState() => _NewParcelScreenState();
}

class _NewParcelScreenState extends ConsumerState<NewParcelScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Mode de saisie pour expéditeur (false = sélection existant, true = nouveau client)
  bool _isNewSender = false;

  // Mode de saisie pour destinataire (false = sélection existant, true = nouveau client)
  bool _isNewReceiver = false;

  // SÉLECTION DU CHAUFFEUR
  List<User> _availableDrivers = [];
  bool _isLoadingDrivers = false;
  String? _selectedDriverId;
  final TextEditingController _driverSearchController = TextEditingController();
  String _driverSearchQuery = '';

  List<Garage> _garages = [];

  // Expéditeur
  final _senderNameController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _senderEmailController = TextEditingController();

  // Expéditeur - Sélection client existant (pour chauffeurs/admins)
  String? _selectedSenderClientId;
  final TextEditingController _senderSearchController = TextEditingController();
  String _senderSearchQuery = '';

  // Destinataire
  final _receiverNameController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  final _receiverEmailController = TextEditingController();
  final _receiverAddressController = TextEditingController();

  // Destinataire - Sélection client existant
  List<User> _availableClients = [];
  bool _isLoadingClients = false;
  String? _selectedReceiverClientId;
  final TextEditingController _clientSearchController = TextEditingController();
  String _clientSearchQuery = '';

  // Colis
  final _descriptionController = TextEditingController();
  final _weightController = TextEditingController();
  final _priceController = TextEditingController();
  ParcelType _selectedType = ParcelType.package;

  // Lieux
  String? _selectedDepartureGarageId;
  String? _selectedArrivalGarageId;

  // Options
  bool _isLoading = false;
  bool _urgentDelivery = false;
  bool _insurance = false;

  // Paiement
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  final TextEditingController _phoneNumberController = TextEditingController();

  // Médias
  final List<XFile> _photos = [];
  final List<XFile> _videos = [];
  final ImagePicker _picker = ImagePicker();

  // Messages vocaux
  final _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<VoiceMessage> _voiceMessages = [];
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  String? _currentlyPlayingPath;

  // Contrôleurs vidéo
  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, bool> _videoInitialized = {};

  // État de compression
  bool _isCompressing = false;
  String _compressionStatus = '';

  @override
  void initState() {
    super.initState();
    _loadGarages();
    _loadAllDrivers();
    _loadAllClients();
    _loadCurrentUserInfo();
    _requestPermissions();
    if (!kIsWeb) {
      VideoCompress.setLogLevel(0);
    }
  }

  @override
  void dispose() {
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    _senderEmailController.dispose();
    _senderSearchController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _receiverEmailController.dispose();
    _receiverAddressController.dispose();
    _descriptionController.dispose();
    _weightController.dispose();
    _priceController.dispose();
    _phoneNumberController.dispose();
    _driverSearchController.dispose();
    _clientSearchController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    if (!kIsWeb) {
      VideoCompress.deleteAllCache();
    }
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    if (!kIsWeb) {
      await Permission.contacts.request();
    }
  }

  // Charger les informations du client connecté
  Future<void> _loadCurrentUserInfo() async {
    final authState = ref.read(authProvider);
    final currentUser = authState.user;

    if (currentUser != null && currentUser.role == UserRole.client) {
      setState(() {
        _senderNameController.text = currentUser.fullName;
        _senderPhoneController.text = currentUser.phone;
        _senderEmailController.text = currentUser.email;
      });
    }
  }

  Future<void> _loadGarages() async {
    if (!mounted) return;
    try {
      final garages = await _apiService.getAllGarages();
      if (mounted) {
        setState(() {
          _garages = garages;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement garages: $e');
    }
  }

  Future<void> _loadAllDrivers() async {
    setState(() {
      _isLoadingDrivers = true;
    });

    try {
      final drivers = await _apiService.getAllDrivers();
      if (mounted) {
        setState(() {
          _availableDrivers = drivers;
          _isLoadingDrivers = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement chauffeurs: $e');
      if (mounted) {
        setState(() {
          _isLoadingDrivers = false;
        });
        try {
          final drivers = await _apiService.searchDriversPublic(query: '');
          if (mounted) {
            setState(() {
              _availableDrivers = drivers;
            });
          }
        } catch (e2) {
          debugPrint('❌ Erreur fallback: $e2');
        }
      }
    }
  }

  Future<void> _loadAllClients() async {
    setState(() {
      _isLoadingClients = true;
    });

    try {
      final allUsers = await _apiService.getAllClients();
      final clients = allUsers.where((user) => user.role == UserRole.client).toList();
      if (mounted) {
        setState(() {
          _availableClients = clients;
          _isLoadingClients = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement clients: $e');
      if (mounted) {
        setState(() {
          _availableClients = [];
          _isLoadingClients = false;
        });
      }
    }
  }

  List<User> get _filteredDrivers {
    if (_driverSearchQuery.isEmpty) return _availableDrivers;

    return _availableDrivers.where((driver) {
      final searchLower = _driverSearchQuery.toLowerCase();
      return driver.fullName.toLowerCase().contains(searchLower) ||
          driver.email.toLowerCase().contains(searchLower) ||
          driver.phone.contains(searchLower);
    }).toList();
  }

  List<User> get _filteredClients {
    if (_clientSearchQuery.isEmpty) return _availableClients;

    return _availableClients.where((client) {
      final searchLower = _clientSearchQuery.toLowerCase();
      return client.fullName.toLowerCase().contains(searchLower) ||
          client.email.toLowerCase().contains(searchLower) ||
          client.phone.contains(searchLower);
    }).toList();
  }

  List<User> get _filteredSenders {
    if (_senderSearchQuery.isEmpty) return _availableClients;

    return _availableClients.where((client) {
      final searchLower = _senderSearchQuery.toLowerCase();
      return client.fullName.toLowerCase().contains(searchLower) ||
          client.email.toLowerCase().contains(searchLower) ||
          client.phone.contains(searchLower);
    }).toList();
  }

  void _onSenderClientSelected(User client) {
    setState(() {
      _selectedSenderClientId = client.id;
      _senderNameController.text = client.fullName;
      _senderPhoneController.text = client.phone;
      _senderEmailController.text = client.email;
    });
  }

  void _clearSenderForm() {
    setState(() {
      _selectedSenderClientId = null;
      _senderNameController.clear();
      _senderPhoneController.clear();
      _senderEmailController.clear();
    });
  }

  void _onReceiverClientSelected(User client) {
    setState(() {
      _selectedReceiverClientId = client.id;
      _receiverNameController.text = client.fullName;
      _receiverPhoneController.text = client.phone;
      _receiverEmailController.text = client.email;
      _receiverAddressController.text = client.address ?? '';
    });
  }

  void _clearReceiverForm() {
    setState(() {
      _selectedReceiverClientId = null;
      _receiverNameController.clear();
      _receiverPhoneController.clear();
      _receiverEmailController.clear();
      _receiverAddressController.clear();
    });
  }

  // ==================== GESTION DES MESSAGES VOCAUX ====================

  Future<String?> _getVoiceMessagePath() async {
    if (kIsWeb) {
      return '';
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return '${directory.path}/voice_$timestamp.m4a';
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
            SnackBar(
              content: const Text('Permission microphone refusée'),
              backgroundColor: AppTheme.warningColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

      if (kIsWeb) {
        await _audioRecorder.start(
          path: '',
          encoder: AudioEncoder.aacLc,
          samplingRate: 44100,
        );
      } else {
        await _audioRecorder.start(
          path: path,
          encoder: AudioEncoder.aacLc,
          samplingRate: 44100,
        );
      }
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
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                content: Text('Message vocal enregistré (${_formatDuration(_recordingDuration)})'),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  String _formatDateTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // ==================== GESTION DES MÉDIAS ====================

  Future<void> _pickPhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (photo != null && mounted) {
      setState(() => _photos.add(photo));
    }
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (photo != null && mounted) {
      setState(() => _photos.add(photo));
    }
  }

  Future<void> _pickVideo() async {
    if (!mounted) return;
    XFile? video;
    try {
      video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        if (kIsWeb) {
          setState(() {
            _videos.add(video!);
          });
          _initializeVideoController(video);
        } else {
          setState(() {
            _isCompressing = true;
            _compressionStatus = 'Compression de la vidéo...';
          });

          final compressedVideo = await _compressVideo(video);

          if (compressedVideo != null && mounted) {
            setState(() {
              _videos.add(compressedVideo);
              _isCompressing = false;
              _compressionStatus = '';
            });
            _initializeVideoController(compressedVideo);
          } else if (mounted) {
            setState(() {
              _videos.add(video!);
              _isCompressing = false;
              _compressionStatus = '';
            });
            _initializeVideoController(video);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCompressing = false);
      }
      debugPrint('Erreur: $e');
      if (video != null && mounted) {
        setState(() => _videos.add(video!));
        _initializeVideoController(video);
      }
    }
  }

  Future<void> _recordVideo() async {
    if (!mounted) return;
    XFile? video;
    try {
      video = await _picker.pickVideo(source: ImageSource.camera);
      if (video != null) {
        if (kIsWeb) {
          setState(() {
            _videos.add(video!);
          });
          _initializeVideoController(video);
        } else {
          setState(() {
            _isCompressing = true;
            _compressionStatus = 'Compression de la vidéo...';
          });

          final compressedVideo = await _compressVideo(video);

          if (compressedVideo != null && mounted) {
            setState(() {
              _videos.add(compressedVideo);
              _isCompressing = false;
              _compressionStatus = '';
            });
            _initializeVideoController(compressedVideo);
          } else if (mounted) {
            setState(() {
              _videos.add(video!);
              _isCompressing = false;
              _compressionStatus = '';
            });
            _initializeVideoController(video);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCompressing = false);
      }
      debugPrint('Erreur: $e');
      if (video != null && mounted) {
        setState(() => _videos.add(video!));
        _initializeVideoController(video);
      }
    }
  }

  Future<XFile?> _compressVideo(XFile video) async {
    if (kIsWeb) return video;

    try {
      final originalSize = await video.length();
      debugPrint('📹 Compression vidéo - Taille originale: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');

      if (originalSize < 2 * 1024 * 1024) {
        debugPrint('📹 Vidéo déjà petite, pas de compression nécessaire');
        return video;
      }

      final mediaInfo = await VideoCompress.getMediaInfo(video.path);
      final duration = mediaInfo.duration ?? 0;
      debugPrint('📹 Durée vidéo: ${duration}s');

      VideoQuality quality;
      if (duration > 60) {
        quality = VideoQuality.LowQuality;
      } else if (duration > 30) {
        quality = VideoQuality.LowQuality;
      } else {
        quality = VideoQuality.MediumQuality;
      }

      final info = await VideoCompress.compressVideo(
        video.path,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 20,
      );

      if (info != null && info.path != null) {
        final compressedFile = XFile(info.path!);
        final compressedSize = await compressedFile.length();
        debugPrint('📹 Vidéo compressée: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');

        if (compressedSize > 15 * 1024 * 1024) {
          debugPrint('⚠️ Vidéo trop volumineuse même après compression');
          return null;
        }

        return compressedFile;
      }
      return null;
    } catch (e) {
      debugPrint('Erreur compression vidéo: $e');
      return null;
    }
  }

  void _initializeVideoController(XFile video) async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _videoInitialized[video.path] = true;
        });
      }
      return;
    }

    final controller = VideoPlayerController.file(File(video.path));
    await controller.initialize();
    if (mounted) {
      setState(() {
        _videoControllers[video.path] = controller;
        _videoInitialized[video.path] = true;
      });
    }
  }

  void _removePhoto(int index) {
    if (mounted) {
      setState(() => _photos.removeAt(index));
    }
  }

  void _removeVideo(int index) {
    final videoPath = _videos[index].path;
    if (mounted) {
      setState(() => _videos.removeAt(index));
    }
    if (!kIsWeb) {
      _videoControllers[videoPath]?.dispose();
      _videoControllers.remove(videoPath);
      _videoInitialized.remove(videoPath);
    }
  }

  // ==================== GESTION DES POINTS ====================

  bool _hasEnoughPoints() {
    final scoreState = ref.read(scoreProvider);
    final score = scoreState.score;
    
    if (score == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final authState = ref.read(authProvider);
        final user = authState.user;
        if (user != null) {
          ref.read(scoreProvider.notifier).loadScore(user.id);
        }
      });
      return false;
    }
    
    return score.points >= 1;
  }

  void _showInsufficientPointsDialog() {
    final scoreState = ref.read(scoreProvider);
    final currentPoints = scoreState.score?.points ?? 0;
    final missingPoints = 1 - currentPoints;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor, size: 28),
            const SizedBox(width: 12),
            const Text('Points insuffisants'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vous n\'avez pas assez de points pour créer un colis.',
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Votre solde :'),
                  Text(
                    '$currentPoints point${currentPoints > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.lightBlue,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Points requis :'),
                  const Text(
                    '1 point',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
            if (missingPoints > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Points manquants :'),
                    Text(
                      '$missingPoints point${missingPoints > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              '💡 Astuce : Vous pouvez acheter des points pour continuer.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showPurchasePointsDialog();
            },
            icon: const Icon(Icons.shopping_cart, size: 18),
            label: const Text('Acheter des points'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  void _showPurchasePointsDialog() {
    final TextEditingController amountController = TextEditingController();
    const pricePerPoint = 100;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.shopping_cart, color: AppTheme.primaryBlue, size: 28),
            const SizedBox(width: 12),
            const Text('Acheter des points'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.lightBlue,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: AppTheme.primaryBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '1 point = $pricePerPoint FCFA',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Nombre de points',
                hintText: 'Ex: 10',
                prefixIcon: const Icon(Icons.stars),
                suffixText: 'pts',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primaryBlue, width: 1.5),
                ),
              ),
              onChanged: (value) {
                // Mettre à jour le prix total
              },
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, child) {
                final amount = int.tryParse(amountController.text) ?? 0;
                final totalPrice = amount * pricePerPoint;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total :',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${totalPrice.toStringAsFixed(0)} FCFA',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          Consumer(
            builder: (context, ref, child) {
              final amount = int.tryParse(amountController.text) ?? 0;
              final isValid = amount > 0 && amount <= 1000;
              
              return ElevatedButton(
                onPressed: isValid
                    ? () {
                        Navigator.pop(context);
                        _purchasePoints(amount);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                child: const Text('Acheter'),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _purchasePoints(int amount) async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);

    try {
      final authState = ref.read(authProvider);
      final user = authState.user;

      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      final success = await ref.read(scoreProvider.notifier).creditPoints(
        user.id,
        amount,
        'Achat de $amount points',
      );

      if (!mounted) return;

      if (success) {
        await ref.read(scoreProvider.notifier).loadScore(user.id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $amount points ajoutés avec succès !'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        final errorState = ref.read(scoreProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorState.error ?? 'Erreur lors de l\'achat de points'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
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

  void _showCurrentBalance() {
    final scoreState = ref.read(scoreProvider);
    final points = scoreState.score?.points ?? 0;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.stars, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Text(
              'Solde: $points point${points > 1 ? 's' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==================== CRÉATION DU COLIS ====================

  Future<void> _createParcel() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDepartureGarageId == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez sélectionner un garage de départ'),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // VÉRIFICATION DES POINTS
    final authState = ref.read(authProvider);
    final currentUser = authState.user;
    final isClient = currentUser?.role == UserRole.client;

    if (isClient) {
      final scoreState = ref.read(scoreProvider);
      if (scoreState.score == null && currentUser != null) {
        await ref.read(scoreProvider.notifier).loadScore(currentUser.id);
      }

      if (!_hasEnoughPoints()) {
        _showInsufficientPointsDialog();
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final departureGarage = _garages.firstWhere((g) => g.id == _selectedDepartureGarageId);
      final arrivalGarage = _selectedArrivalGarageId != null
          ? _garages.firstWhere((g) => g.id == _selectedArrivalGarageId)
          : departureGarage;

      final shouldBeFreeForBidding = isClient && _selectedDriverId == null;
      
      String? driverId;
      String? driverName;
      String? driverPhone;

      if (isClient && _selectedDriverId != null) {
        final selectedDriver = _availableDrivers.firstWhere((d) => d.id == _selectedDriverId);
        driverId = selectedDriver.id;
        driverName = selectedDriver.fullName;
        driverPhone = selectedDriver.phone;
      } else if (!isClient && currentUser != null) {
        driverId = currentUser.id;
        driverName = currentUser.fullName;
        driverPhone = currentUser.phone;
      }

      final parcelData = {
        'senderName': _senderNameController.text.trim(),
        'senderPhone': _senderPhoneController.text.trim(),
        'receiverName': _receiverNameController.text.trim(),
        'receiverPhone': _receiverPhoneController.text.trim(),
        'description': _descriptionController.text.trim(),
        'weight': double.parse(_weightController.text),
        'type': _selectedType.value,
        'departureGarageId': _selectedDepartureGarageId,
        'departureGarageName': departureGarage.name,
        'price': double.tryParse(_priceController.text) ?? 0,
        'isUrgent': _urgentDelivery,
        'isInsured': _insurance,
        'paymentMethod': _selectedPaymentMethod.value,
        'paymentPhoneNumber': _phoneNumberController.text.trim(),
        'isFreeForBidding': shouldBeFreeForBidding,
        'status': shouldBeFreeForBidding ? 'free' : 'pending',
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
      };

      if (_senderEmailController.text.trim().isNotEmpty) {
        parcelData['senderEmail'] = _senderEmailController.text.trim();
      }
      if (_receiverEmailController.text.trim().isNotEmpty) {
        parcelData['receiverEmail'] = _receiverEmailController.text.trim();
      }
      if (_receiverAddressController.text.trim().isNotEmpty) {
        parcelData['receiverAddress'] = _receiverAddressController.text.trim();
      }
      if (_selectedArrivalGarageId != null) {
        parcelData['arrivalGarageId'] = _selectedArrivalGarageId;
        parcelData['arrivalGarageName'] = arrivalGarage.name;
      }

      debugPrint('📦 Création du colis...');
      debugPrint('📦 Libre service: $shouldBeFreeForBidding');
      debugPrint('📦 Chauffeur assigné: ${driverName ?? "Aucun"}');

      final result = await ref.read(parcelProvider.notifier).createParcel(parcelData);

      if (result != null && mounted) {
        final parcelId = result.id;
        debugPrint('✅ Colis créé avec ID: $parcelId');

        if (isClient && currentUser != null) {
          final debited = await ref.read(scoreProvider.notifier).debitPoints(
            currentUser.id,
            1,
            parcelId,
            'Création du colis #${result.trackingNumber}',
          );

          if (!debited && mounted) {
            await _apiService.cancelParcel(parcelId, reason: 'Erreur de débit de points');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Erreur lors du débit des points. Colis annulé.'),
                backgroundColor: AppTheme.errorColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
            setState(() => _isLoading = false);
            return;
          }
          
          await ref.read(scoreProvider.notifier).loadScore(currentUser.id);
        }

        // Upload des médias...
        final List<String> uploadedPhotoUrls = [];
        final List<String> uploadedVideoUrls = [];
        final List<String> uploadedAudioUrls = [];

        if (_photos.isNotEmpty) {
          debugPrint('📸 Upload de ${_photos.length} photo(s)...');
          for (int i = 0; i < _photos.length; i++) {
            final photo = _photos[i];
            if (mounted) {
              setState(() {
                _compressionStatus = 'Upload photo ${i + 1}/${_photos.length}...';
                _isCompressing = true;
              });
            }

            try {
              final url = await _apiService.uploadParcelPhoto(photo, parcelId);
              if (url != null && mounted) {
                debugPrint('✅ Photo ${i + 1} uploadée');
                uploadedPhotoUrls.add(url);
              }
            } catch (e) {
              debugPrint('❌ Erreur upload photo ${i + 1}: $e');
            }
          }
        }

        if (_videos.isNotEmpty) {
          debugPrint('🎬 Upload de ${_videos.length} vidéo(s)...');
          for (int i = 0; i < _videos.length; i++) {
            final video = _videos[i];
            if (mounted) {
              setState(() {
                _compressionStatus = 'Upload vidéo ${i + 1}/${_videos.length}...';
                _isCompressing = true;
              });
            }

            try {
              final url = await _apiService.uploadParcelVideo(video, parcelId);
              if (url != null && mounted) {
                debugPrint('✅ Vidéo ${i + 1} uploadée');
                uploadedVideoUrls.add(url);
              }
            } catch (e) {
              debugPrint('❌ Erreur upload vidéo ${i + 1}: $e');
            }
          }
        }

        if (_voiceMessages.isNotEmpty) {
          debugPrint('🎤 Upload de ${_voiceMessages.length} message(s) vocal(aux)...');
          for (int i = 0; i < _voiceMessages.length; i++) {
            final voiceMsg = _voiceMessages[i];
            if (mounted) {
              setState(() {
                _compressionStatus = 'Upload message vocal ${i + 1}/${_voiceMessages.length}...';
                _isCompressing = true;
              });
            }

            try {
              final audioFile = XFile(voiceMsg.path);
              final url = await _apiService.uploadAudio(audioFile, parcelId);
              if (url != null && mounted) {
                debugPrint('✅ Message vocal ${i + 1} uploadé: $url');
                uploadedAudioUrls.add(url);
              }
            } catch (e) {
              debugPrint('❌ Erreur upload audio ${i + 1}: $e');
            }
          }
        }

        if (uploadedPhotoUrls.isNotEmpty || uploadedVideoUrls.isNotEmpty || uploadedAudioUrls.isNotEmpty) {
          try {
            final updateData = <String, dynamic>{};
            if (uploadedPhotoUrls.isNotEmpty) {
              updateData['photoUrls'] = uploadedPhotoUrls;
            }
            if (uploadedVideoUrls.isNotEmpty) {
              updateData['videoUrls'] = uploadedVideoUrls;
            }
            if (uploadedAudioUrls.isNotEmpty) {
              updateData['audioUrls'] = uploadedAudioUrls;
            }
            await _apiService.updateParcelMedia(parcelId, updateData);
            debugPrint('✅ Colis mis à jour avec succès');
          } catch (e) {
            debugPrint('⚠️ Erreur mise à jour médias: $e');
          }
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
            _isCompressing = false;
            _compressionStatus = '';
          });
          _showSuccessDialog(result);
        }
      } else if (mounted) {
        setState(() {
          _isLoading = false;
          _isCompressing = false;
        });
        final errorState = ref.read(parcelProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorState.error ?? 'Erreur lors de la création'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur création colis: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCompressing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showSuccessDialog(Parcel parcel) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successColor, size: 28),
            const SizedBox(width: 12),
            const Text('Colis créé avec succès'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📦 N°: ${parcel.trackingNumber}'),
            const SizedBox(height: 8),
            if (parcel.isFreeForBidding) ...[
              const Text(
                '🔓 Mode: Libre service',
                style: TextStyle(color: AppTheme.primaryBlue),
              ),
              const SizedBox(height: 8),
              const Text(
                '💡 Les chauffeurs pourront faire des offres',
                style: TextStyle(color: AppTheme.primaryBlue, fontSize: 12),
              ),
            ] else ...[
              Text('💰 ${parcel.formattedPrice}'),
            ],
            const SizedBox(height: 8),
            Text('👤 Expéditeur: ${_senderNameController.text.trim()}'),
            Text('👤 Destinataire: ${_receiverNameController.text.trim()}'),
            if (_selectedDriverId != null) ...[
              const SizedBox(height: 8),
              Text('👨‍✈️ Chauffeur assigné: ${_availableDrivers.firstWhere((d) => d.id == _selectedDriverId).fullName}'),
            ],
            if (_voiceMessages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.mic, size: 14, color: AppTheme.primaryBlue),
                  const SizedBox(width: 4),
                  Text(
                    'Message(s) vocal(aux) inclus',
                    style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            child: const Text('Nouveau colis'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                if (parcel.isFreeForBidding) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const FreeParcelsScreen()),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => ParcelDetailScreen(parcel: parcel)),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: Text(parcel.isFreeForBidding ? 'Voir libre service' : 'Voir le colis'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    final authState = ref.read(authProvider);
    final currentUser = authState.user;
    final isClient = currentUser?.role == UserRole.client;

    if (!isClient) {
      _clearSenderForm();
      _isNewSender = false;
    } else if (currentUser != null) {
      _senderNameController.text = currentUser.fullName;
      _senderPhoneController.text = currentUser.phone;
      _senderEmailController.text = currentUser.email;
    }

    _clearReceiverForm();
    _isNewReceiver = false;
    _descriptionController.clear();
    _weightController.clear();
    _priceController.clear();
    _phoneNumberController.clear();
    _driverSearchController.clear();
    _clientSearchController.clear();
    _senderSearchController.clear();
    _driverSearchQuery = '';
    _clientSearchQuery = '';
    _senderSearchQuery = '';
    if (mounted) {
      setState(() {
        _selectedType = ParcelType.package;
        _selectedDepartureGarageId = null;
        _selectedArrivalGarageId = null;
        _selectedPaymentMethod = PaymentMethod.cash;
        _urgentDelivery = false;
        _insurance = false;
        _selectedDriverId = null;
        _selectedReceiverClientId = null;
        _selectedSenderClientId = null;
        _photos.clear();
        _videos.clear();
        _voiceMessages.clear();
        _currentlyPlayingPath = null;
      });
    }
    if (!kIsWeb) {
      for (var controller in _videoControllers.values) {
        controller.dispose();
      }
      _videoControllers.clear();
      _videoInitialized.clear();
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isClient = authState.user?.role == UserRole.client;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Nouveau colis',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Destinataire avec sélecteur de contacts
                  _buildReceiverSection(),
                  const SizedBox(height: 16),

                  // Section Informations colis
                  _buildInfoSection(),
                  const SizedBox(height: 16),

                  // Section Trajet
                  _buildRouteSection(),
                  const SizedBox(height: 16),

                  // SECTION SÉLECTION DU CHAUFFEUR
                  if (isClient && _availableDrivers.isNotEmpty) ...[
                    _buildDriverSelectionSection(),
                    const SizedBox(height: 16),
                  ],

                  // Section Médias
                  _buildMediaSection(),
                  const SizedBox(height: 16),

                  // Bouton de création
                  CustomButton(
                    text: _selectedDriverId == null && isClient
                        ? 'Mettre en libre service'
                        : 'Enregistrer le colis',
                    onPressed: _createParcel,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          if (_isCompressing && !kIsWeb)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  color: AppTheme.cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _compressionStatus.isNotEmpty
                              ? _compressionStatus
                              : 'Compression en cours...',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // SECTION SÉLECTION DU CHAUFFEUR
  Widget _buildDriverSelectionSection() {
    return _buildCard(
      icon: Icons.delivery_dining,
      title: 'Choisir un chauffeur (optionnel)',
      color: Colors.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _driverSearchController,
            decoration: InputDecoration(
              hintText: 'Rechercher un chauffeur...',
              prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondary),
              suffixIcon: _driverSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        setState(() {
                          _driverSearchController.clear();
                          _driverSearchQuery = '';
                        });
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 1.5),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _driverSearchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          if (_isLoadingDrivers)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  height: 40,
                  width: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                  ),
                ),
              ),
            )
          else if (_filteredDrivers.isEmpty && _driverSearchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Aucun résultat',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
            )
          else if (_filteredDrivers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Aucun chauffeur disponible',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ),
            )
          else
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _filteredDrivers.length,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemBuilder: (context, index) {
                  final driver = _filteredDrivers[index];
                  final isSelected = _selectedDriverId == driver.id;
                  return _buildCompactDriverCard(driver, isSelected);
                },
              ),
            ),
          if (_selectedDriverId != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.successColor, width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.successColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_filteredDrivers.firstWhere((d) => d.id == _selectedDriverId).fullName}',
                      style: const TextStyle(color: AppTheme.successColor, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDriverId = null;
                      });
                    },
                    child: const Icon(Icons.close, color: AppTheme.successColor, size: 16),
                  ),
                ],
              ),
            ),
          ],
          if (_selectedDriverId == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppTheme.primaryBlue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '💡 Aucun chauffeur sélectionné ? Le colis sera automatiquement mis en libre service. Les chauffeurs pourront alors faire des offres.',
                        style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactDriverCard(User driver, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDriverId = isSelected ? null : driver.id;
        });
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.lightBlue : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: driver.profilePhoto != null && driver.profilePhoto!.isNotEmpty
                    ? CachedNetworkImageProvider(driver.profilePhoto!)
                    : null,
                child: (driver.profilePhoto == null || driver.profilePhoto!.isEmpty)
                    ? Text(
                        driver.initials,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  driver.fullName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 2),
              if (driver.rating != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 8, color: Colors.amber),
                    const SizedBox(width: 1),
                    Text(
                      driver.rating!.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              if (driver.vehiclePlate != null && driver.vehiclePlate!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_car, size: 7, color: Colors.grey.shade500),
                        const SizedBox(width: 1),
                        Flexible(
                          child: Text(
                            driver.vehiclePlate!,
                            style: TextStyle(fontSize: 7, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // SECTION DESTINATAIRE - CORRIGÉE
  Widget _buildReceiverSection() {
    return _buildCard(
      icon: Icons.person,
      title: 'Destinataire',
      color: AppTheme.primaryBlue,
      child: Column(
        children: [
          // Boutons de sélection
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 500) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: _buildReceiverButton(
                            text: '👥 Client',
                            isSelected: !_isNewReceiver,
                            onTap: () {
                              setState(() {
                                _isNewReceiver = false;
                                _clearReceiverForm();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: _buildReceiverButton(
                            text: '✏️ Nouveau',
                            isSelected: _isNewReceiver,
                            onTap: () {
                              setState(() {
                                _isNewReceiver = true;
                                _clearReceiverForm();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: _buildReceiverButton(
                            text: '📱 Contacts',
                            isSelected: false,
                            onTap: _showPhoneContactPicker,
                            isContactButton: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildReceiverButton(
                        text: '👥 Client',
                        isSelected: !_isNewReceiver,
                        onTap: () {
                          setState(() {
                            _isNewReceiver = false;
                            _clearReceiverForm();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: _buildReceiverButton(
                        text: '✏️ Nouveau',
                        isSelected: _isNewReceiver,
                        onTap: () {
                          setState(() {
                            _isNewReceiver = true;
                            _clearReceiverForm();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: _buildReceiverButton(
                        text: '📱 Contacts',
                        isSelected: false,
                        onTap: _showPhoneContactPicker,
                        isContactButton: true,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),
          if (!_isNewReceiver) _buildClientSelectionForReceiver(),
          if (_isNewReceiver) _buildNewReceiverForm(),
        ],
      ),
    );
  }

  Widget _buildReceiverButton({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
    bool isContactButton = false,
  }) {
    return Expanded(
      flex: 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isContactButton
                ? AppTheme.lightBlue
                : isSelected
                    ? AppTheme.primaryBlue
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isContactButton
                    ? AppTheme.primaryBlue
                    : isSelected
                        ? Colors.white
                        : AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  // Afficher le sélecteur de contacts
  void _showPhoneContactPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sélectionner un contact',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Picker
            Expanded(
              child: PhoneContactPicker(
                onContactSelected: (phone, name) {
                  setState(() {
                    _receiverNameController.text = name;
                    _receiverPhoneController.text = phone;
                    _isNewReceiver = true;
                    _selectedReceiverClientId = null;
                  });
                  Navigator.pop(context);
                },
                selectedPhone: _receiverPhoneController.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewReceiverForm() {
    return Column(
      children: [
        CustomTextField(
          controller: _receiverNameController,
          label: 'Nom complet',
          prefixIcon: Icons.person,
          validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _receiverPhoneController,
          label: 'Téléphone',
          prefixIcon: Icons.phone,
          keyboardType: TextInputType.phone,
          validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _receiverEmailController,
          label: 'Email (optionnel)',
          prefixIcon: Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _receiverAddressController,
          label: 'Adresse (optionnel)',
          prefixIcon: Icons.location_on,
        ),
      ],
    );
  }

  Widget _buildClientSelectionForReceiver() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _clientSearchController,
          decoration: InputDecoration(
            hintText: 'Rechercher un client...',
            prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondary),
            suffixIcon: _clientSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      setState(() {
                        _clientSearchController.clear();
                        _clientSearchQuery = '';
                      });
                    },
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryBlue, width: 1.5),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _clientSearchQuery = value;
            });
          },
        ),
        const SizedBox(height: 12),
        if (_isLoadingClients)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
            ),
          )
        else if (_filteredClients.isEmpty && _clientSearchQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Aucun résultat pour "$_clientSearchQuery"',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else if (_filteredClients.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Aucun client disponible',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _filteredClients.length,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemBuilder: (context, index) {
                final client = _filteredClients[index];
                final isSelected = _selectedReceiverClientId == client.id;
                return _buildHorizontalClientCard(client, isSelected);
              },
            ),
          ),
        if (_selectedReceiverClientId != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.successColor, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.successColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Client sélectionné',
                        style: TextStyle(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${_receiverNameController.text} - ${_receiverPhoneController.text}',
                        style: const TextStyle(color: AppTheme.successColor, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _clearReceiverForm,
                  child: const Icon(Icons.close, color: AppTheme.successColor, size: 18),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHorizontalClientCard(User client, bool isSelected) {
    return GestureDetector(
      onTap: () {
        _onReceiverClientSelected(client);
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.lightBlue : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isSelected ? AppTheme.primaryBlue : AppTheme.lightBlue,
                child: Text(
                  client.initials,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  client.fullName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone, size: 10, color: Colors.grey.shade500),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      client.phone,
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // SECTION INFORMATIONS COLIS
  Widget _buildInfoSection() {
    return _buildCard(
      icon: Icons.inventory,
      title: 'Informations colis',
      color: AppTheme.primaryBlue,
      child: Column(
        children: [
          _buildDescriptionWithVoice(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _weightController,
                  label: 'Poids (kg)',
                  prefixIcon: Icons.fitness_center,
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomTextField(
                  controller: _priceController,
                  label: 'Prix (FCFA)',
                  prefixIcon: Icons.money,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ParcelType>(
            value: _selectedType,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Type de colis',
              prefixIcon: const Icon(Icons.category),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 1.5),
              ),
            ),
            items: ParcelType.values.map((type) => DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(_getTypeIcon(type), size: 18),
                      const SizedBox(width: 8),
                      Text(type.label),
                    ],
                  ),
                )).toList(),
            onChanged: (value) {
              if (value != null && mounted) {
                setState(() => _selectedType = value);
              }
            },
          ),
        ],
      ),
    );
  }

  // SECTION TRAJET
  Widget _buildRouteSection() {
    return _buildCard(
      icon: Icons.route,
      title: 'Trajet',
      color: AppTheme.primaryBlue,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedDepartureGarageId,
            hint: const Text('Lieu de départ'),
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Lieu de départ',
              prefixIcon: const Icon(Icons.departure_board),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 1.5),
              ),
            ),
            items: _garages.map((garage) => DropdownMenuItem(
                  value: garage.id,
                  child: Text('${garage.name} - ${garage.city}'),
                )).toList(),
            onChanged: (value) {
              if (mounted) setState(() => _selectedDepartureGarageId = value);
            },
            validator: (v) => v == null ? 'Champ requis' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _selectedArrivalGarageId,
            hint: const Text('Garage d\'arrivée (optionnel)'),
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Lieu d\'arrivée',
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 1.5),
              ),
            ),
            items: [
              const DropdownMenuItem(
                  value: null,
                  child: Text('Aucun (même lieu que le départ)')),
              ..._garages.map((garage) => DropdownMenuItem(
                    value: garage.id,
                    child: Text('${garage.name} - ${garage.city}'),
                  )),
            ],
            onChanged: (value) {
              if (mounted) setState(() => _selectedArrivalGarageId = value);
            },
          ),
        ],
      ),
    );
  }

  // SECTION MÉDIAS
  Widget _buildMediaSection() {
    return _buildCard(
      icon: Icons.photo_library,
      title: 'Photos et vidéos',
      color: AppTheme.primaryBlue,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMediaButton(
                  icon: Icons.photo_library,
                  label: 'Galerie',
                  onTap: _pickPhoto,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMediaButton(
                  icon: Icons.camera_alt,
                  label: 'Appareil',
                  onTap: _takePhoto,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMediaButton(
                  icon: Icons.video_library,
                  label: 'Vidéo',
                  onTap: _pickVideo,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMediaButton(
                  icon: Icons.videocam,
                  label: 'Enregistrer',
                  onTap: _recordVideo,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                itemBuilder: (context, index) =>
                    _buildPhotoThumbnail(_photos[index], index),
              ),
            ),
          ],
          if (_videos.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Vidéos', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _videos.length,
                itemBuilder: (context, index) =>
                    _buildVideoThumbnail(_videos[index], index),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionWithVoice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: _descriptionController,
          label: 'Description',
          prefixIcon: Icons.description,
          maxLines: 3,
          validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
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
                    Icon(Icons.mic, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    const Text(
                      'Message vocal (optionnel)',
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
                                backgroundColor: AppTheme.primaryBlue,
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
              color: AppTheme.primaryBlue,
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
                  style: const TextStyle(fontSize: 12),
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

  Widget _buildCard({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildPhotoThumbnail(XFile photo, int index) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: _getImageProvider(photo.path),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removePhoto(index),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 20, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoThumbnail(XFile video, int index) {
    final isInitialized = _videoInitialized[video.path] ?? false;
    final controller = _videoControllers[video.path];

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black,
          ),
          child: Center(
            child: !kIsWeb && isInitialized && controller != null && controller.value.isInitialized
                ? VideoPlayer(controller)
                : const Icon(Icons.videocam, size: 40, color: Colors.white54),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeVideo(index),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 20, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getTypeIcon(ParcelType type) {
    switch (type) {
      case ParcelType.document:
        return Icons.description;
      case ParcelType.package:
        return Icons.inventory;
      case ParcelType.fragile:
        return Icons.science;
      case ParcelType.perishable:
        return Icons.eco;
      case ParcelType.valuable:
        return Icons.attach_money;
    }
  }

  ImageProvider _getImageProvider(String path) {
    if (kIsWeb) return NetworkImage(path);
    return FileImage(File(path));
  }
}