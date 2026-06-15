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
import 'package:record/record.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import '../../models/garage.dart';
import '../../models/parcel.dart';
import '../../models/payment.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
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
        // TODO: Handle this case.
        throw UnimplementedError();
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
      final clients =
          allUsers.where((user) => user.role == UserRole.client).toList();
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

  // Charger les contacts du téléphone
  Future<List<Contact>> _getPhoneContacts() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('L\'accès aux contacts n\'est pas disponible sur le Web.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return [];
    }

    final status = await Permission.contacts.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission des contacts refusée'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return [];
    }

    final Iterable<Contact> contacts = await ContactsService.getContacts();
    return contacts.toList();
  }

  // Afficher le dialogue de sélection depuis les contacts pour le destinataire
  Future<void> _showContactsPickerForReceiver() async {
    final contacts = await _getPhoneContacts();

    if (contacts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucun contact trouvé sur votre téléphone'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'Sélectionner un contact (Destinataire)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      final displayName = contact.displayName ?? 'Sans nom';
                      final phoneNumber = contact.phones?.isNotEmpty == true
                          ? contact.phones!.first.value ?? ''
                          : '';
                      final email = contact.emails?.isNotEmpty == true
                          ? contact.emails!.first.value ?? ''
                          : '';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(displayName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (phoneNumber.isNotEmpty) Text('📞 $phoneNumber'),
                            if (email.isNotEmpty)
                              Text('✉️ $email',
                                  style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _receiverNameController.text = displayName;
                            _receiverPhoneController.text = phoneNumber;
                            _receiverEmailController.text = email;
                            _selectedReceiverClientId = null;
                            _isNewReceiver = true;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
                    'Message vocal enregistré (${_formatDuration(_recordingDuration)})'),
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

  String _formatDateTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
      debugPrint(
          '📹 Compression vidéo - Taille originale: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');

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
        debugPrint(
            '📹 Vidéo compressée: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');

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

  // ==================== CRÉATION DU COLIS ====================

  Future<void> _createParcel() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDepartureGarageId == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez sélectionner un garage de départ'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final departureGarage =
          _garages.firstWhere((g) => g.id == _selectedDepartureGarageId);
      final arrivalGarage = _selectedArrivalGarageId != null
          ? _garages.firstWhere((g) => g.id == _selectedArrivalGarageId)
          : departureGarage;

      final authState = ref.read(authProvider);
      final currentUser = authState.user;
      final isClient = currentUser?.role == UserRole.client;

      // 🔧 LOGIQUE MODIFIÉE: Si aucun chauffeur sélectionné et que c'est un client,
      // le colis est automatiquement mis en libre service
      final shouldBeFreeForBidding = isClient && _selectedDriverId == null;
      
      String? driverId;
      String? driverName;
      String? driverPhone;

      if (isClient && _selectedDriverId != null) {
        final selectedDriver =
            _availableDrivers.firstWhere((d) => d.id == _selectedDriverId);
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

      final result =
          await ref.read(parcelProvider.notifier).createParcel(parcelData);

      if (result != null && mounted) {
        final parcelId = result.id;
        debugPrint('✅ Colis créé avec ID: $parcelId');

        final List<String> uploadedPhotoUrls = [];
        final List<String> uploadedVideoUrls = [];
        final List<String> uploadedAudioUrls = [];

        // Upload des photos
        if (_photos.isNotEmpty) {
          debugPrint('📸 Upload de ${_photos.length} photo(s)...');
          for (int i = 0; i < _photos.length; i++) {
            final photo = _photos[i];
            if (mounted) {
              setState(() {
                _compressionStatus =
                    'Upload photo ${i + 1}/${_photos.length}...';
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

        // Upload des vidéos
        if (_videos.isNotEmpty) {
          debugPrint('🎬 Upload de ${_videos.length} vidéo(s)...');
          for (int i = 0; i < _videos.length; i++) {
            final video = _videos[i];
            if (mounted) {
              setState(() {
                _compressionStatus =
                    'Upload vidéo ${i + 1}/${_videos.length}...';
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

        // Upload des messages vocaux
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

        // Mise à jour des médias
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
              backgroundColor: Colors.red),
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
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
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
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Colis créé avec succès'),
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
                style: TextStyle(color: Colors.purple),
              ),
              const SizedBox(height: 8),
              const Text(
                '💡 Les chauffeurs pourront faire des offres',
                style: TextStyle(color: Colors.purple, fontSize: 12),
              ),
            ] else ...[
              Text('💰 ${parcel.formattedPrice}'),
            ],
            const SizedBox(height: 8),
            Text('👤 Expéditeur: ${_senderNameController.text.trim()}'),
            Text('👤 Destinataire: ${_receiverNameController.text.trim()}'),
            if (_selectedDriverId != null) ...[
              const SizedBox(height: 8),
              Text(
                  '👨‍✈️ Chauffeur assigné: ${_availableDrivers.firstWhere((d) => d.id == _selectedDriverId).fullName}'),
            ],
            if (_voiceMessages.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.mic, size: 14, color: Colors.purple),
                  SizedBox(width: 4),
                  Text(
                    'Message(s) vocal(aux) inclus',
                    style: TextStyle(fontSize: 12, color: Colors.purple),
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
                    MaterialPageRoute(
                        builder: (context) => const FreeParcelsScreen()),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            ParcelDetailScreen(parcel: parcel)),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 6, 162, 234)),
            child: Text(
                parcel.isFreeForBidding ? 'Voir libre service' : 'Voir le colis'),
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Nouveau colis',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A2B3C),
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
                  // Section Destinataire
                  _buildReceiverSection(),
                  const SizedBox(height: 16),

                  // Section Informations colis
                  _buildInfoSection(),
                  const SizedBox(height: 16),

                  // Section Trajet
                  _buildRouteSection(),
                  const SizedBox(height: 16),

                  // ✅ SECTION SÉLECTION DU CHAUFFEUR (RÉINTÉGRÉE)
                  if (isClient && _availableDrivers.isNotEmpty) ...[
                    _buildDriverSelectionSection(),
                    const SizedBox(height: 16),
                  ],

                  // Section Options
                  // _buildOptionsSection(),
                  // const SizedBox(height: 16),

                  // // Section Paiement
                  // _buildPaymentSection(),
                  // const SizedBox(height: 16),

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
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _compressionStatus.isNotEmpty
                              ? _compressionStatus
                              : 'Compression en cours...',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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

  // ✅ SECTION SÉLECTION DU CHAUFFEUR (RÉINTÉGRÉE)
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
              prefixIcon: const Icon(Icons.search, size: 18),
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF0B6E3A), width: 1.5),
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
                  child: CircularProgressIndicator(strokeWidth: 2),
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
                color: Colors.green.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green, width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_filteredDrivers.firstWhere((d) => d.id == _selectedDriverId).fullName}',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
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
                    child:
                        const Icon(Icons.close, color: Colors.green, size: 16),
                  ),
                ],
              ),
            ),
          ],
          // Message explicatif sur le libre service
          if (_selectedDriverId == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withAlpha(30)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.purple[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '💡 Aucun chauffeur sélectionné ? Le colis sera automatiquement mis en libre service. Les chauffeurs pourront alors faire des offres.',
                        style: TextStyle(fontSize: 12, color: Colors.purple[700]),
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
          color: isSelected ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.shade200,
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
                backgroundImage: driver.profilePhoto != null &&
                        driver.profilePhoto!.isNotEmpty
                    ? CachedNetworkImageProvider(driver.profilePhoto!)
                    : null,
                child: (driver.profilePhoto == null ||
                        driver.profilePhoto!.isEmpty)
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
                    color: isSelected ? Colors.green.shade700 : Colors.black87,
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
                      style: const TextStyle(
                          fontSize: 8, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              if (driver.vehiclePlate != null && driver.vehiclePlate!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_car,
                            size: 7, color: Colors.grey.shade500),
                        const SizedBox(width: 1),
                        Flexible(
                          child: Text(
                            driver.vehiclePlate!,
                            style: TextStyle(
                                fontSize: 7, color: Colors.grey.shade600),
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

  // SECTION DESTINATAIRE
  Widget _buildReceiverSection() {
    return _buildCard(
      icon: Icons.person,
      title: 'Destinataire',
      color: Colors.blue,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 500) {
                return Column(
                  children: [
                    _buildReceiverButton(
                      text: '👥 Client existant',
                      isSelected: !_isNewReceiver,
                      onTap: () {
                        setState(() {
                          _isNewReceiver = false;
                          _clearReceiverForm();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildReceiverButton(
                      text: '✏️ Nouveau',
                      isSelected: _isNewReceiver,
                      onTap: () {
                        setState(() {
                          _isNewReceiver = true;
                          _clearReceiverForm();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildReceiverButton(
                      text: '📱 Contacts',
                      isSelected: false,
                      onTap: _showContactsPickerForReceiver,
                      isContactButton: true,
                    ),
                  ],
                );
              } else {
                return Row(
                  children: [
                    Expanded(
                      child: _buildReceiverButton(
                        text: '👥 Client existant',
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
                      child: _buildReceiverButton(
                        text: '📱 Contacts',
                        isSelected: false,
                        onTap: _showContactsPickerForReceiver,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isContactButton
              ? Colors.green.withAlpha(30)
              : isSelected
                  ? const Color(0xFF0B6E3A)
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isContactButton
                  ? const Color(0xFF0B6E3A)
                  : isSelected
                      ? Colors.white
                      : Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
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
            prefixIcon: const Icon(Icons.search, size: 18),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Color(0xFF0B6E3A), width: 1.5),
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
            child: Center(child: CircularProgressIndicator()),
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
              color: Colors.green.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Client sélectionné',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${_receiverNameController.text} - ${_receiverPhoneController.text}',
                        style:
                            const TextStyle(color: Colors.green, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _clearReceiverForm,
                  child: const Icon(Icons.close, color: Colors.green, size: 18),
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
          color: isSelected ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.shade200,
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
                backgroundColor:
                    isSelected ? Colors.green : Colors.blue.shade100,
                child: Text(
                  client.initials,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.blue.shade700,
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
                    color: isSelected ? Colors.green.shade700 : Colors.black87,
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
                      style:
                          TextStyle(fontSize: 9, color: Colors.grey.shade600),
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
      color: Colors.green,
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
      color: Colors.orange,
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

  // SECTION OPTIONS
  Widget _buildOptionsSection() {
    return _buildCard(
      icon: Icons.tune,
      title: 'Options',
      color: Colors.purple,
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Livraison urgente'),
            subtitle: const Text('Frais supplémentaires appliqués'),
            value: _urgentDelivery,
            onChanged: (value) {
              setState(() => _urgentDelivery = value);
            },
            activeColor: Colors.red,
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('Assurance colis'),
            subtitle: const Text('Protection contre la perte ou les dommages'),
            value: _insurance,
            onChanged: (value) {
              setState(() => _insurance = value);
            },
            activeColor: Colors.orange,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // SECTION PAIEMENT
  Widget _buildPaymentSection() {
    return _buildCard(
      icon: Icons.payment,
      title: 'Paiement',
      color: Colors.teal,
      child: Column(
        children: [
          DropdownButtonFormField<PaymentMethod>(
            value: _selectedPaymentMethod,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Mode de paiement',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: PaymentMethod.values.map((method) => DropdownMenuItem(
                  value: method,
                  child: Text(method.label),
                )).toList(),
            onChanged: (value) {
              if (value != null && mounted) {
                setState(() => _selectedPaymentMethod = value);
              }
            },
          ),
          const SizedBox(height: 12),
          if (_selectedPaymentMethod != PaymentMethod.cash)
            CustomTextField(
              controller: _phoneNumberController,
              label: 'Numéro de téléphone',
              prefixIcon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
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
      color: Colors.teal,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMediaButton(
                  icon: Icons.photo_library,
                  label: 'Galerie',
                  onTap: _pickPhoto,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMediaButton(
                  icon: Icons.camera_alt,
                  label: 'Appareil',
                  onTap: _takePhoto,
                  color: Colors.green,
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
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMediaButton(
                  icon: Icons.videocam,
                  label: 'Enregistrer',
                  onTap: _recordVideo,
                  color: Colors.red,
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
                    Icon(Icons.mic, color: Colors.red.shade400),
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
                                backgroundColor: Colors.red.shade400,
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
              color: Colors.blue.shade600,
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
        color: Colors.white,
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
                    color: color.withAlpha(25),
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
                    color: Color(0xFF1A2B3C),
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
                color: Colors.black.withAlpha(150),
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
                color: Colors.black.withAlpha(150),
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

// Modèle pour les messages vocaux
class VoiceMessage {
  final String path;
  final int duration;
  final DateTime createdAt;

  VoiceMessage({
    required this.path,
    required this.duration,
    required this.createdAt,
  });
}