// mobile/lib/screens/super-admin/parcel_form_screen.dart
// ignore_for_file: deprecated_member_use, unused_field

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:procolis/widgets/app_logo.dart';
import 'package:video_player/video_player.dart';

import '../../models/garage.dart';
import '../../models/parcel.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class ParcelFormScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  final Parcel? parcel;
  
  const ParcelFormScreen({
    super.key,
    required this.isEditing,
    this.parcel,
  });

  @override
  ConsumerState<ParcelFormScreen> createState() => _ParcelFormScreenState();
}

class _ParcelFormScreenState extends ConsumerState<ParcelFormScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Controllers
  final _senderNameController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _receiverNameController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  final _receiverEmailController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _weightController = TextEditingController();
  final _priceController = TextEditingController();
  final _trackingNumberController = TextEditingController();
  
  // Dropdown values
  ParcelType _selectedType = ParcelType.package;
  ParcelStatus _selectedStatus = ParcelStatus.pending;
  String? _selectedDepartureGarageId;
  String? _selectedArrivalGarageId;
  String? _selectedDriverId;
  String? _selectedPaymentMethod;
  
  // Lists
  List<Garage> _garages = [];
  List<User> _drivers = [];
  bool _loadingData = true;
  
  // Médias
  final List<XFile> _photos = [];
  final List<XFile> _videos = [];
  List<String> _existingPhotoUrls = [];
  final ImagePicker _picker = ImagePicker();
  
  // Contrôleurs vidéo
  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, bool> _videoInitialized = {};

  // Thème Bleu/Blanc
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color backgroundColor = Color(0xFFF0F4F8);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF6B7A8F);

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.isEditing && widget.parcel != null) {
      _populateForm();
    }
  }

  @override
  void dispose() {
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _receiverEmailController.dispose();
    _descriptionController.dispose();
    _weightController.dispose();
    _priceController.dispose();
    _trackingNumberController.dispose();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final garages = await _apiService.getAllGaragesSuperAdmin();
      final allUsers = await _apiService.getAllUsersSuperAdmin();
      
      if (mounted) {
        setState(() {
          _garages = garages;
          _drivers = allUsers.where((u) => u.role == UserRole.driver).toList();
          _loadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _populateForm() {
    final parcel = widget.parcel!;
    _senderNameController.text = parcel.senderName;
    _senderPhoneController.text = parcel.senderPhone;
    _receiverNameController.text = parcel.receiverName;
    _receiverPhoneController.text = parcel.receiverPhone;
    _receiverEmailController.text = parcel.receiverEmail ?? '';
    _descriptionController.text = parcel.description;
    _weightController.text = parcel.weight.toString();
    _priceController.text = parcel.price?.toString() ?? '';
    _trackingNumberController.text = parcel.trackingNumber;
    _selectedType = parcel.type;
    _selectedStatus = parcel.status;
    if (parcel.paymentMethod != null) {
      if (parcel.paymentMethod is String) {
        _selectedPaymentMethod = parcel.paymentMethod as String;
      } else {
        _selectedPaymentMethod = parcel.paymentMethod.toString().split('.').last;
      }
    }
    _existingPhotoUrls = List.from(parcel.photoUrls);
  }

  // ==================== GESTION DES PHOTOS ====================
  
  Future<void> _pickPhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (photo != null && mounted) {
        setState(() {
          _photos.add(photo);
        });
      }
    } catch (e) {
      debugPrint('Erreur lors de la sélection de la photo: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (photo != null && mounted) {
        setState(() {
          _photos.add(photo);
        });
      }
    } catch (e) {
      debugPrint('Erreur lors de la prise de photo: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
      );
      if (video != null && mounted) {
        setState(() {
          _videos.add(video);
        });
        _initializeVideoController(video);
      }
    } catch (e) {
      debugPrint('Erreur lors de la sélection de la vidéo: $e');
    }
  }

  Future<void> _recordVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
      );
      if (video != null && mounted) {
        setState(() {
          _videos.add(video);
        });
        _initializeVideoController(video);
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'enregistrement vidéo: $e');
    }
  }

  void _initializeVideoController(XFile video) async {
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
    setState(() {
      _photos.removeAt(index);
    });
  }

  void _removeExistingPhoto(int index) {
    setState(() {
      _existingPhotoUrls.removeAt(index);
    });
  }

  void _removeVideo(int index) {
    final videoPath = _videos[index].path;
    setState(() {
      _videos.removeAt(index);
    });
    _videoControllers[videoPath]?.dispose();
    _videoControllers.remove(videoPath);
    _videoInitialized.remove(videoPath);
  }

  // ==================== CRÉATION DU COLIS ====================
  
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final photoUrls = [..._existingPhotoUrls, ..._photos.map((p) => p.path)];
      
      final data = {
        'senderName': _senderNameController.text.trim(),
        'senderPhone': _senderPhoneController.text.trim(),
        'receiverName': _receiverNameController.text.trim(),
        'receiverPhone': _receiverPhoneController.text.trim(),
        'receiverEmail': _receiverEmailController.text.trim().isEmpty ? null : _receiverEmailController.text.trim(),
        'description': _descriptionController.text.trim(),
        'weight': double.parse(_weightController.text.trim()),
        'type': _selectedType.value,
        'status': _selectedStatus.value,
        'departureGarageId': _selectedDepartureGarageId,
        'arrivalGarageId': _selectedArrivalGarageId,
        'driverId': _selectedDriverId,
        'price': _priceController.text.isNotEmpty ? double.parse(_priceController.text.trim()) : null,
        'paymentMethod': _selectedPaymentMethod,
        'photoUrls': photoUrls,
      };
      
      if (widget.isEditing && widget.parcel != null) {
        await _apiService.advanceParcel(
          widget.parcel!.id,
          _selectedStatus.value,
        );
      } else {
        await _apiService.createParcel(data);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? 'Colis modifié avec succès' : 'Colis créé avec succès'),
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

  // ==================== AFFICHAGE DES MÉDIAS ====================
  
  Widget _buildMediaSection() {
    return _buildSectionCard(
      title: 'Photos et vidéos',
      icon: Icons.photo_library,
      color: Colors.purple,
      child: Column(
        children: [
          // Boutons d'ajout
          Row(
            children: [
              Expanded(
                child: _buildMediaButton(
                  icon: Icons.photo_library,
                  label: 'Galerie photo',
                  onTap: _pickPhoto,
                  color: primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMediaButton(
                  icon: Icons.camera_alt,
                  label: 'Appareil photo',
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
                  label: 'Galerie vidéo',
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
          const SizedBox(height: 16),
          
          // Photos existantes
          if (_existingPhotoUrls.isNotEmpty) ...[
            const Text('Photos existantes', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _existingPhotoUrls.length,
                itemBuilder: (context, index) {
                  return _buildExistingPhotoThumbnail(_existingPhotoUrls[index], index);
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Nouvelles photos
          if (_photos.isNotEmpty) ...[
            const Text('Nouvelles photos', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                itemBuilder: (context, index) {
                  return _buildPhotoThumbnail(_photos[index], index);
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Vidéos
          if (_videos.isNotEmpty) ...[
            const Text('Vidéos', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _videos.length,
                itemBuilder: (context, index) {
                  return _buildVideoThumbnail(_videos[index], index);
                },
              ),
            ),
          ],
        ],
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
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  Widget _buildPhotoThumbnail(XFile photo, int index) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            image: DecorationImage(
              image: FileImage(File(photo.path)),
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
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExistingPhotoThumbnail(String url, int index) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            image: DecorationImage(
              image: NetworkImage(url),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeExistingPhoto(index),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
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
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Colors.black,
          ),
          child: isInitialized && controller != null
              ? Stack(
                  children: [
                    VideoPlayer(controller),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                )
              : const Center(
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
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeVideo(index),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== SECTION CARD ====================
  
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  // ==================== BUILD ====================
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 24, isWhite: false),
            const SizedBox(width: 8),
            Text(
              widget.isEditing ? 'Modifier le colis' : 'Nouveau colis',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0.5,
        shadowColor: Colors.grey.shade200,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loadingData
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              ),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Section Expéditeur
                    _buildSectionCard(
                      title: 'Expéditeur',
                      icon: Icons.person,
                      color: Colors.blue,
                      child: Column(
                        children: [
                          CustomTextField(
                            controller: _senderNameController,
                            label: 'Nom complet *',
                            prefixIcon: Icons.person,
                            hint: 'Ex: Jean Dupont',
                            validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            controller: _senderPhoneController,
                            label: 'Téléphone *',
                            prefixIcon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            hint: 'Ex: 77 123 45 67',
                            validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section Destinataire
                    _buildSectionCard(
                      title: 'Destinataire',
                      icon: Icons.person_outline,
                      color: Colors.green,
                      child: Column(
                        children: [
                          CustomTextField(
                            controller: _receiverNameController,
                            label: 'Nom complet *',
                            prefixIcon: Icons.person,
                            hint: 'Ex: Marie Diop',
                            validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            controller: _receiverPhoneController,
                            label: 'Téléphone *',
                            prefixIcon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            hint: 'Ex: 77 987 65 43',
                            validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            controller: _receiverEmailController,
                            label: 'Email',
                            prefixIcon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                            hint: 'Ex: marie.diop@email.com',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section Détails du colis
                    _buildSectionCard(
                      title: 'Détails du colis',
                      icon: Icons.inventory,
                      color: Colors.orange,
                      child: Column(
                        children: [
                          CustomTextField(
                            controller: _descriptionController,
                            label: 'Description *',
                            prefixIcon: Icons.description,
                            maxLines: 3,
                            hint: 'Description détaillée du colis',
                            validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  controller: _weightController,
                                  label: 'Poids (kg) *',
                                  prefixIcon: Icons.fitness_center,
                                  keyboardType: TextInputType.number,
                                  hint: 'Ex: 5.5',
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
                                  hint: 'Ex: 25000',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<ParcelType>(
                            value: _selectedType,
                            decoration: InputDecoration(
                              labelText: 'Type de colis *',
                              prefixIcon: Icon(Icons.category),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: ParcelType.values.map((type) => DropdownMenuItem(
                              value: type,
                              child: Row(
                                children: [
                                  Icon(type.icon, size: 18, color: primaryBlue),
                                  const SizedBox(width: 8),
                                  Text(type.label),
                                ],
                              ),
                            )).toList(),
                            onChanged: (value) => setState(() => _selectedType = value!),
                            validator: (v) => v == null ? 'Champ requis' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section Transport
                    _buildSectionCard(
                      title: 'Transport',
                      icon: Icons.local_shipping,
                      color: Colors.purple,
                      child: Column(
                        children: [
                          DropdownButtonFormField<String?>(
                            value: _selectedDepartureGarageId,
                            decoration: InputDecoration(
                              labelText: 'Garage de départ *',
                              prefixIcon: Icon(Icons.business),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Sélectionner...')),
                              ..._garages.map((garage) => DropdownMenuItem(
                                value: garage.id,
                                child: Text(garage.name),
                              )),
                            ],
                            onChanged: (value) => setState(() => _selectedDepartureGarageId = value),
                            validator: (v) => v == null ? 'Champ requis' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            value: _selectedArrivalGarageId,
                            decoration: InputDecoration(
                              labelText: 'Garage d\'arrivée *',
                              prefixIcon: Icon(Icons.business),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Sélectionner...')),
                              ..._garages.map((garage) => DropdownMenuItem(
                                value: garage.id,
                                child: Text(garage.name),
                              )),
                            ],
                            onChanged: (value) => setState(() => _selectedArrivalGarageId = value),
                            validator: (v) => v == null ? 'Champ requis' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            value: _selectedDriverId,
                            decoration: InputDecoration(
                              labelText: 'Chauffeur assigné',
                              prefixIcon: Icon(Icons.delivery_dining),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Aucun chauffeur')),
                              ..._drivers.map((driver) => DropdownMenuItem(
                                value: driver.id,
                                child: Text(driver.fullName),
                              )),
                            ],
                            onChanged: (value) => setState(() => _selectedDriverId = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section Paiement
                    _buildSectionCard(
                      title: 'Paiement',
                      icon: Icons.payment,
                      color: Colors.teal,
                      child: Column(
                        children: [
                          DropdownButtonFormField<String?>(
                            value: _selectedPaymentMethod,
                            decoration: InputDecoration(
                              labelText: 'Mode de paiement',
                              prefixIcon: Icon(Icons.payment),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Sélectionner...')),
                              DropdownMenuItem(value: 'cash', child: Text('Espèces')),
                              DropdownMenuItem(value: 'wave', child: Text('Wave')),
                              DropdownMenuItem(value: 'orange_money', child: Text('Orange Money')),
                              DropdownMenuItem(value: 'free_money', child: Text('Free Money')),
                            ],
                            onChanged: (value) => setState(() => _selectedPaymentMethod = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section Médias
                    _buildMediaSection(),
                    const SizedBox(height: 16),

                    // Numéro de suivi
                    if (!widget.isEditing) ...[
                      Container(
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
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: primaryBlue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(Icons.numbers, size: 20, color: primaryBlue),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Numéro de suivi',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              CustomTextField(
                                controller: _trackingNumberController,
                                label: 'Numéro de suivi',
                                prefixIcon: Icons.numbers,
                                readOnly: true,
                                hint: 'Généré automatiquement',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Bouton
                    CustomButton(
                      text: widget.isEditing ? 'Modifier le colis' : 'Créer le colis',
                      onPressed: _save,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}