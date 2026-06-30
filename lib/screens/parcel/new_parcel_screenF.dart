// import 'dart:io';

// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:video_player/video_player.dart';

// import '../../models/garage.dart';
// import '../../models/parcel.dart';
// import '../../models/payment.dart';
// import '../../providers/auth_provider.dart';
// import '../../providers/parcel_provider.dart';
// import '../../services/api_service.dart';
// import '../../widgets/custom_button.dart';
// import '../../widgets/custom_text_field.dart';
// import 'parcel_detail_screen.dart';

// class NewParcelScreen extends ConsumerStatefulWidget {
//   const NewParcelScreen({super.key});

//   @override
//   ConsumerState<NewParcelScreen> createState() => _NewParcelScreenState();
// }

// class _NewParcelScreenState extends ConsumerState<NewParcelScreen> {
//   final ApiService _apiService = ApiService();
//   final _formKey = GlobalKey<FormState>();
  
//   List<Garage> _garages = [];
//   bool _isLoadingGarages = true;
  
//   // Expéditeur
//   final _senderNameController = TextEditingController();
//   final _senderPhoneController = TextEditingController();
//   final _senderEmailController = TextEditingController();
  
//   // Destinataire
//   final _receiverNameController = TextEditingController();
//   final _receiverPhoneController = TextEditingController();
//   final _receiverEmailController = TextEditingController();
//   final _receiverAddressController = TextEditingController();
  
//   // Colis
//   final _descriptionController = TextEditingController();
//   final _weightController = TextEditingController();
//   final _priceController = TextEditingController();
//   ParcelType _selectedType = ParcelType.package;
  
//   // Lieux
//   String? _selectedDepartureGarageId;
//   String? _selectedArrivalGarageId;
  
//   // Options
//   bool _isLoading = false;
//   bool _urgentDelivery = false;
//   bool _insurance = false;
  
//   // Paiement
//   PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
//   final TextEditingController _phoneNumberController = TextEditingController();
  
//   // Médias (stockés localement avant upload)
//   final List<XFile> _photos = [];
//   final List<XFile> _videos = [];
//   final ImagePicker _picker = ImagePicker();
  
//   // Contrôleurs vidéo
//   final Map<String, VideoPlayerController> _videoControllers = {};
//   final Map<String, bool> _videoInitialized = {};

//   @override
//   void initState() {
//     super.initState();
//     _loadGarages();
//   }

//   @override
//   void dispose() {
//     _senderNameController.dispose();
//     _senderPhoneController.dispose();
//     _senderEmailController.dispose();
//     _receiverNameController.dispose();
//     _receiverPhoneController.dispose();
//     _receiverEmailController.dispose();
//     _receiverAddressController.dispose();
//     _descriptionController.dispose();
//     _weightController.dispose();
//     _priceController.dispose();
//     _phoneNumberController.dispose();
//     for (var controller in _videoControllers.values) {
//       controller.dispose();
//     }
//     super.dispose();
//   }

//   Future<void> _loadGarages() async {
//     setState(() => _isLoadingGarages = true);
//     try {
//       final garages = await _apiService.getAllGarages();
//       setState(() {
//         _garages = garages;
//         _isLoadingGarages = false;
//       });
//     } catch (e) {
//       setState(() => _isLoadingGarages = false);
//       debugPrint('❌ Erreur chargement garages: $e');
//     }
//   }

//   // ==================== GESTION DES MÉDIAS ====================
  
//   Future<void> _pickPhoto() async {
//     final XFile? photo = await _picker.pickImage(
//       source: ImageSource.gallery,
//       imageQuality: 80,
//     );
//     if (photo != null) setState(() => _photos.add(photo));
//   }

//   Future<void> _takePhoto() async {
//     final XFile? photo = await _picker.pickImage(
//       source: ImageSource.camera,
//       imageQuality: 80,
//     );
//     if (photo != null) setState(() => _photos.add(photo));
//   }

//   Future<void> _pickVideo() async {
//     final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
//     if (video != null) {
//       setState(() => _videos.add(video));
//       if (!kIsWeb) _initializeVideoController(video);
//     }
//   }

//   Future<void> _recordVideo() async {
//     final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
//     if (video != null) {
//       setState(() => _videos.add(video));
//       if (!kIsWeb) _initializeVideoController(video);
//     }
//   }

//   void _initializeVideoController(XFile video) async {
//     if (kIsWeb) return;
//     final controller = VideoPlayerController.file(File(video.path));
//     await controller.initialize();
//     if (mounted) {
//       setState(() {
//         _videoControllers[video.path] = controller;
//         _videoInitialized[video.path] = true;
//       });
//     }
//   }

//   void _removePhoto(int index) => setState(() => _photos.removeAt(index));
  
//   void _removeVideo(int index) {
//     final videoPath = _videos[index].path;
//     setState(() => _videos.removeAt(index));
//     if (!kIsWeb) {
//       _videoControllers[videoPath]?.dispose();
//       _videoControllers.remove(videoPath);
//       _videoInitialized.remove(videoPath);
//     }
//   }

//   // ==================== CRÉATION DU COLIS (ORDRE CORRECT) ====================
  
//   Future<void> _createParcel() async {
//     if (!_formKey.currentState!.validate()) return;
    
//     if (_selectedDepartureGarageId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Veuillez sélectionner un garage de départ'), backgroundColor: Colors.orange),
//       );
//       return;
//     }
    
//     if ((_selectedPaymentMethod == PaymentMethod.wave ||
//          _selectedPaymentMethod == PaymentMethod.orangeMoney ||
//          _selectedPaymentMethod == PaymentMethod.freeMoney) &&
//         _phoneNumberController.text.trim().isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Veuillez entrer le numéro du client'), backgroundColor: Colors.orange),
//       );
//       return;
//     }
    
//     setState(() => _isLoading = true);
    
//     try {
//       final departureGarage = _garages.firstWhere((g) => g.id == _selectedDepartureGarageId);
//       final arrivalGarage = _selectedArrivalGarageId != null 
//           ? _garages.firstWhere((g) => g.id == _selectedArrivalGarageId)
//           : departureGarage;
      
//       final totalPrice = _calculateEstimatedPrice();
//       final authState = ref.read(authProvider);
//       final currentDriver = authState.user;
      
//       // ✅ ÉTAPE 1: Créer le colis SANS les médias
//       final parcelData = {
//         'senderName': _senderNameController.text.trim(),
//         'senderPhone': _senderPhoneController.text.trim(),
//         'receiverName': _receiverNameController.text.trim(),
//         'receiverPhone': _receiverPhoneController.text.trim(),
//         'description': _descriptionController.text.trim(),
//         'weight': double.parse(_weightController.text),
//         'type': _selectedType.value,
//         'departureGarageId': _selectedDepartureGarageId,
//         'departureGarageName': departureGarage.name,
//         'price': double.tryParse(_priceController.text) ?? 0,
//         'isUrgent': _urgentDelivery,
//         'isInsured': _insurance,
//         'paymentMethod': _selectedPaymentMethod.value,
//         'paymentPhoneNumber': _phoneNumberController.text.trim(),
//         'driverId': currentDriver?.id,
//         'driverName': currentDriver?.fullName,
//         'driverPhone': currentDriver?.phone,
//       };
      
//       // Ajouter les champs optionnels
//       if (_senderEmailController.text.trim().isNotEmpty) {
//         parcelData['senderEmail'] = _senderEmailController.text.trim();
//       }
//       if (_receiverEmailController.text.trim().isNotEmpty) {
//         parcelData['receiverEmail'] = _receiverEmailController.text.trim();
//       }
//       if (_receiverAddressController.text.trim().isNotEmpty) {
//         parcelData['receiverAddress'] = _receiverAddressController.text.trim();
//       }
//       if (_selectedArrivalGarageId != null) {
//         parcelData['arrivalGarageId'] = _selectedArrivalGarageId;
//         parcelData['arrivalGarageName'] = arrivalGarage.name;
//       }
//       if (totalPrice > 0) {
//         parcelData['totalAmount'] = totalPrice;
//       }
      
//       print('📦 ÉTAPE 1: Création du colis sans médias');
//       final result = await ref.read(parcelProvider.notifier).createParcel(parcelData);
      
//       if (result != null && mounted) {
//         final parcelId = result.id;
        
//         // ✅ ÉTAPE 2: Uploader les photos avec le VRAI ID
//         if (_photos.isNotEmpty) {
//           print('📸 ÉTAPE 2: Upload de ${_photos.length} photos');
//           for (var photo in _photos) {
//             final url = await _apiService.uploadParcelPhoto(photo, parcelId);
//             if (url != null) {
//               print('✅ Photo uploadée: $url');
//             }
//           }
//         }
        
//         // ✅ ÉTAPE 3: Uploader les vidéos avec le VRAI ID
//         if (_videos.isNotEmpty) {
//           print('🎥 ÉTAPE 3: Upload de ${_videos.length} vidéos');
//           for (var video in _videos) {
//             final url = await _apiService.uploadParcelVideo(video, parcelId);
//             if (url != null) {
//               print('✅ Vidéo uploadée: $url');
//             }
//           }
//         }
        
//         setState(() => _isLoading = false);
//         _showSuccessDialog(result, totalPrice);
//       } else if (mounted) {
//         setState(() => _isLoading = false);
//         final errorState = ref.read(parcelProvider);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text(errorState.error ?? 'Erreur lors de la création'), backgroundColor: Colors.red),
//         );
//       }
//     } catch (e) {
//       print('❌ Erreur création colis: $e');
//       if (mounted) {
//         setState(() => _isLoading = false);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
//         );
//       }
//     }
//   }

//   double _calculateEstimatedPrice() {
//     double total = 0;
//     if (_priceController.text.isNotEmpty) {
//       total += double.tryParse(_priceController.text) ?? 0;
//     }
//     if (_urgentDelivery) total += 500;
//     if (_insurance && _priceController.text.isNotEmpty) {
//       total += (double.tryParse(_priceController.text) ?? 0) * 0.02;
//     }
//     return total;
//   }

//   void _showSuccessDialog(Parcel parcel, double amount) {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         title: Row(
//           children: const [
//             Icon(Icons.check_circle, color: Colors.green, size: 28),
//             SizedBox(width: 12),
//             Text('Colis créé avec succès'),
//           ],
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('📦 ${parcel.trackingNumber}'),
//             const SizedBox(height: 8),
//             Text('💰 ${amount.toStringAsFixed(0)} FCFA'),
//             const SizedBox(height: 8),
//             Text('👤 Client: ${_senderNameController.text.trim()}'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _resetForm();
//             },
//             child: const Text('Nouveau colis'),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               Navigator.pushReplacement(
//                 context,
//                 MaterialPageRoute(builder: (context) => ParcelDetailScreen(parcel: parcel)),
//               );
//             },
//             style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B6E3A)),
//             child: const Text('Voir le colis'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _resetForm() {
//     _senderNameController.clear();
//     _senderPhoneController.clear();
//     _senderEmailController.clear();
//     _receiverNameController.clear();
//     _receiverPhoneController.clear();
//     _receiverEmailController.clear();
//     _receiverAddressController.clear();
//     _descriptionController.clear();
//     _weightController.clear();
//     _priceController.clear();
//     _phoneNumberController.clear();
//     setState(() {
//       _selectedType = ParcelType.package;
//       _selectedDepartureGarageId = null;
//       _selectedArrivalGarageId = null;
//       _selectedPaymentMethod = PaymentMethod.cash;
//       _urgentDelivery = false;
//       _insurance = false;
//       _photos.clear();
//       _videos.clear();
//     });
//     if (!kIsWeb) {
//       for (var controller in _videoControllers.values) controller.dispose();
//       _videoControllers.clear();
//       _videoInitialized.clear();
//     }
//   }

//   // ==================== BUILD ====================

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Nouveau colis'),
//         backgroundColor: const Color.fromARGB(255, 5, 243, 243),
//         foregroundColor: Colors.white,
//       ),
//       body: _isLoadingGarages
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(16),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _buildSection(
//                       icon: Icons.person_outline,
//                       title: 'Client (Expéditeur)',
//                       color: Colors.blue,
//                       child: Column(
//                         children: [
//                           CustomTextField(
//                             controller: _senderNameController,
//                             label: 'Nom complet du client',
//                             prefixIcon: Icons.person,
//                             validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
//                           ),
//                           const SizedBox(height: 12),
//                           CustomTextField(
//                             controller: _senderPhoneController,
//                             label: 'Téléphone du client',
//                             prefixIcon: Icons.phone,
//                             keyboardType: TextInputType.phone,
//                             validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
//                           ),
//                           const SizedBox(height: 12),
//                           CustomTextField(
//                             controller: _senderEmailController,
//                             label: 'Email du client (optionnel)',
//                             prefixIcon: Icons.email,
//                             keyboardType: TextInputType.emailAddress,
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 16),
                    
//                     _buildSection(
//                       icon: Icons.person,
//                       title: 'Destinataire',
//                       color: Colors.blue,
//                       child: Column(
//                         children: [
//                           CustomTextField(
//                             controller: _receiverNameController,
//                             label: 'Nom complet',
//                             prefixIcon: Icons.person,
//                             validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
//                           ),
//                           const SizedBox(height: 12),
//                           CustomTextField(
//                             controller: _receiverPhoneController,
//                             label: 'Téléphone',
//                             prefixIcon: Icons.phone,
//                             keyboardType: TextInputType.phone,
//                             validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
//                           ),
//                           const SizedBox(height: 12),
//                           CustomTextField(
//                             controller: _receiverEmailController,
//                             label: 'Email (optionnel)',
//                             prefixIcon: Icons.email,
//                             keyboardType: TextInputType.emailAddress,
//                           ),
//                           const SizedBox(height: 12),
//                           CustomTextField(
//                             controller: _receiverAddressController,
//                             label: 'Adresse (optionnel)',
//                             prefixIcon: Icons.location_on,
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 16),
                    
//                     _buildSection(
//                       icon: Icons.inventory,
//                       title: 'Informations colis',
//                       color: Colors.green,
//                       child: Column(
//                         children: [
//                           CustomTextField(
//                             controller: _descriptionController,
//                             label: 'Description',
//                             prefixIcon: Icons.description,
//                             maxLines: 3,
//                             validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
//                           ),
//                           const SizedBox(height: 12),
//                           Row(
//                             children: [
//                               Expanded(
//                                 child: CustomTextField(
//                                   controller: _weightController,
//                                   label: 'Poids (kg)',
//                                   prefixIcon: Icons.fitness_center,
//                                   keyboardType: TextInputType.number,
//                                   validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
//                                 ),
//                               ),
//                               const SizedBox(width: 12),
//                               Expanded(
//                                 child: CustomTextField(
//                                   controller: _priceController,
//                                   label: 'Prix (FCFA)',
//                                   prefixIcon: Icons.money,
//                                   keyboardType: TextInputType.number,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 12),
//                           DropdownButtonFormField<ParcelType>(
//                             value: _selectedType,
//                             decoration: const InputDecoration(
//                               labelText: 'Type de colis',
//                               prefixIcon: Icon(Icons.category),
//                               border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
//                             ),
//                             items: ParcelType.values.map((type) => DropdownMenuItem(
//                               value: type,
//                               child: Row(
//                                 children: [
//                                   Icon(_getTypeIcon(type), size: 18),
//                                   const SizedBox(width: 8),
//                                   Text(type.label),
//                                 ],
//                               ),
//                             )).toList(),
//                             onChanged: (value) => setState(() => _selectedType = value!),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 16),
                    
//                     _buildSection(
//                       icon: Icons.route,
//                       title: 'Trajet',
//                       color: Colors.orange,
//                       child: Column(
//                         children: [
//                           DropdownButtonFormField<String>(
//                             value: _selectedDepartureGarageId,
//                             hint: const Text('Garage de départ'),
//                             decoration: const InputDecoration(
//                               labelText: 'Garage départ',
//                               prefixIcon: Icon(Icons.departure_board),
//                               border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
//                             ),
//                             items: _garages.map((garage) => DropdownMenuItem(
//                               value: garage.id,
//                               child: Text('${garage.name} - ${garage.city}'),
//                             )).toList(),
//                             onChanged: (value) => setState(() => _selectedDepartureGarageId = value),
//                             validator: (v) => v == null ? 'Champ requis' : null,
//                           ),
//                           const SizedBox(height: 12),
//                           DropdownButtonFormField<String?>(
//                             value: _selectedArrivalGarageId,
//                             hint: const Text('Garage d\'arrivée (optionnel)'),
//                             decoration: const InputDecoration(
//                               labelText: 'Garage arrivée',
//                               prefixIcon: Icon(Icons.location_on),
//                               border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
//                             ),
//                             items: [
//                               const DropdownMenuItem(value: null, child: Text('Aucun (même garage)')),
//                               ..._garages.map((garage) => DropdownMenuItem(
//                                 value: garage.id,
//                                 child: Text('${garage.name} - ${garage.city}'),
//                               )),
//                             ],
//                             onChanged: (value) => setState(() => _selectedArrivalGarageId = value),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 16),
                    
//                     _buildMediaSection(),
//                     const SizedBox(height: 16),
                    
//                     _buildSection(
//                       icon: Icons.settings,
//                       title: 'Options',
//                       color: Colors.purple,
//                       child: Column(
//                         children: [
//                           SwitchListTile(
//                             title: const Text('Livraison urgente'),
//                             subtitle: const Text('Priorité + 500 FCFA'),
//                             value: _urgentDelivery,
//                             onChanged: (value) => setState(() => _urgentDelivery = value),
//                             activeTrackColor: const Color(0xFF0B6E3A).withAlpha(128),
//                             activeThumbColor: const Color(0xFF0B6E3A),
//                             contentPadding: EdgeInsets.zero,
//                           ),
//                           SwitchListTile(
//                             title: const Text('Assurance colis'),
//                             subtitle: const Text('Protection jusqu\'à 50 000 FCFA (2%)'),
//                             value: _insurance,
//                             onChanged: (value) => setState(() => _insurance = value),
//                             activeTrackColor: const Color(0xFF0B6E3A).withAlpha(128),
//                             activeThumbColor: const Color(0xFF0B6E3A),
//                             contentPadding: EdgeInsets.zero,
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 16),
                    
//                     _buildPaymentSection(),
//                     const SizedBox(height: 32),
                    
//                     CustomButton(
//                       text: 'Enregistrer le colis',
//                       onPressed: _createParcel,
//                       isLoading: _isLoading,
//                     ),
//                     const SizedBox(height: 16),
                    
//                     Container(
//                       padding: const EdgeInsets.all(12),
//                       decoration: BoxDecoration(
//                         color: Colors.green.withAlpha(25),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Row(
//                         children: [
//                           const Icon(Icons.info, color: Colors.green),
//                           const SizedBox(width: 12),
//                           const Expanded(
//                             child: Text(
//                               'Vous êtes identifié comme chauffeur. Le colis vous sera automatiquement assigné.',
//                               style: TextStyle(fontSize: 12, color: Colors.green),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 80),
//                   ],
//                 ),
//               ),
//             ),
//     );
//   }

//   Widget _buildSection({
//     required IconData icon,
//     required String title,
//     required Color color,
//     required Widget child,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: color.withAlpha(25),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(icon, color: color),
//               const SizedBox(width: 8),
//               Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
//             ],
//           ),
//           const SizedBox(height: 12),
//           child,
//         ],
//       ),
//     );
//   }

//   Widget _buildMediaSection() {
//     return _buildSection(
//       icon: Icons.photo_library,
//       title: 'Photos et vidéos',
//       color: Colors.teal,
//       child: Column(
//         children: [
//           Row(
//             children: [
//               Expanded(child: _buildMediaButton(icon: Icons.photo_library, label: 'Galerie', onTap: _pickPhoto, color: Colors.blue)),
//               const SizedBox(width: 12),
//               Expanded(child: _buildMediaButton(icon: Icons.camera_alt, label: 'Appareil', onTap: _takePhoto, color: Colors.green)),
//             ],
//           ),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               Expanded(child: _buildMediaButton(icon: Icons.video_library, label: 'Vidéo', onTap: _pickVideo, color: Colors.orange)),
//               const SizedBox(width: 12),
//               Expanded(child: _buildMediaButton(icon: Icons.videocam, label: 'Enregistrer', onTap: _recordVideo, color: Colors.red)),
//             ],
//           ),
//           if (_photos.isNotEmpty) ...[
//             const SizedBox(height: 16),
//             const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold)),
//             const SizedBox(height: 8),
//             SizedBox(
//               height: 100,
//               child: ListView.builder(
//                 scrollDirection: Axis.horizontal,
//                 itemCount: _photos.length,
//                 itemBuilder: (context, index) => _buildPhotoThumbnail(_photos[index], index),
//               ),
//             ),
//           ],
//           if (_videos.isNotEmpty) ...[
//             const SizedBox(height: 12),
//             const Text('Vidéos', style: TextStyle(fontWeight: FontWeight.bold)),
//             const SizedBox(height: 8),
//             SizedBox(
//               height: 100,
//               child: ListView.builder(
//                 scrollDirection: Axis.horizontal,
//                 itemCount: _videos.length,
//                 itemBuilder: (context, index) => _buildVideoThumbnail(_videos[index], index),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildMediaButton({required IconData icon, required String label, required VoidCallback onTap, required Color color}) {
//     return OutlinedButton.icon(
//       onPressed: onTap,
//       icon: Icon(icon, size: 18, color: color),
//       label: Text(label, style: TextStyle(color: color)),
//       style: OutlinedButton.styleFrom(
//         side: BorderSide(color: color),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//       ),
//     );
//   }

//   Widget _buildPhotoThumbnail(XFile photo, int index) {
//     return Stack(
//       children: [
//         Container(
//           margin: const EdgeInsets.only(right: 8),
//           width: 100,
//           height: 100,
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(8),
//             image: DecorationImage(
//               image: _getImageProvider(photo.path),
//               fit: BoxFit.cover,
//             ),
//           ),
//         ),
//         Positioned(
//           top: 4,
//           right: 4,
//           child: GestureDetector(
//             onTap: () => _removePhoto(index),
//             child: Container(
//               decoration: BoxDecoration(color: Colors.black.withAlpha(150), shape: BoxShape.circle),
//               child: const Icon(Icons.close, size: 20, color: Colors.white),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildVideoThumbnail(XFile video, int index) {
//     final isInitialized = _videoInitialized[video.path] ?? false;
//     final controller = _videoControllers[video.path];
    
//     return Stack(
//       children: [
//         Container(
//           margin: const EdgeInsets.only(right: 8),
//           width: 100,
//           height: 100,
//           decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.black),
//           child: Center(
//             child: !kIsWeb && isInitialized && controller != null
//                 ? VideoPlayer(controller)
//                 : const Icon(Icons.videocam, size: 40, color: Colors.white54),
//           ),
//         ),
//         Positioned(
//           top: 4,
//           right: 4,
//           child: GestureDetector(
//             onTap: () => _removeVideo(index),
//             child: Container(
//               decoration: BoxDecoration(color: Colors.black.withAlpha(150), shape: BoxShape.circle),
//               child: const Icon(Icons.close, size: 20, color: Colors.white),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildPaymentSection() {
//     return _buildSection(
//       icon: Icons.payment,
//       title: 'Paiement',
//       color: Colors.deepPurple,
//       child: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(color: Colors.deepPurple.withAlpha(25), borderRadius: BorderRadius.circular(12)),
//             child: Column(
//               children: [
//                 Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Prix du colis:'), Text('${_priceController.text.isEmpty ? '0' : _priceController.text} FCFA')]),
//                 if (_urgentDelivery) const SizedBox(height: 4),
//                 if (_urgentDelivery) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('Frais urgent:'), Text('500 FCFA')]),
//                 if (_insurance) const SizedBox(height: 4),
//                 if (_insurance) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('Assurance:'), Text('2% du montant')]),
//                 const Divider(height: 16),
//                 Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
//                   const Text('Total à payer:', style: TextStyle(fontWeight: FontWeight.bold)),
//                   Text('${_calculateEstimatedPrice().toStringAsFixed(0)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0B6E3A))),
//                 ]),
//               ],
//             ),
//           ),
//           const SizedBox(height: 16),
//           const Text('Mode de paiement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
//           const SizedBox(height: 8),
//           SingleChildScrollView(
//             scrollDirection: Axis.horizontal,
//             child: Row(
//               children: PaymentMethod.values.map((method) {
//                 final isSelected = _selectedPaymentMethod == method;
//                 return Padding(
//                   padding: const EdgeInsets.only(right: 8),
//                   child: ChoiceChip(
//                     label: Row(mainAxisSize: MainAxisSize.min, children: [
//                       Icon(_getPaymentIcon(method), size: 16, color: isSelected ? Colors.white : _getPaymentColor(method)),
//                       const SizedBox(width: 6),
//                       Text(method.label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
//                     ]),
//                     selected: isSelected,
//                     onSelected: (selected) => setState(() => _selectedPaymentMethod = method),
//                     selectedColor: _getPaymentColor(method),
//                     backgroundColor: Colors.grey.shade100,
//                   ),
//                 );
//               }).toList(),
//             ),
//           ),
//           if (_selectedPaymentMethod == PaymentMethod.wave ||
//               _selectedPaymentMethod == PaymentMethod.orangeMoney ||
//               _selectedPaymentMethod == PaymentMethod.freeMoney)
//             Padding(
//               padding: const EdgeInsets.only(top: 16),
//               child: CustomTextField(
//                 controller: _phoneNumberController,
//                 label: 'Numéro de téléphone du client',
//                 prefixIcon: Icons.phone_android,
//                 keyboardType: TextInputType.phone,
//                 hint: 'Ex: 77 123 45 67',
//                 validator: (v) => v == null || v.isEmpty ? 'Numéro requis' : null,
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   IconData _getPaymentIcon(PaymentMethod method) {
//     switch (method) {
//       case PaymentMethod.cash: return Icons.money;
//       case PaymentMethod.wave: return Icons.waves;
//       case PaymentMethod.orangeMoney: return Icons.phone_android;
//       case PaymentMethod.freeMoney: return Icons.smartphone;
//       case PaymentMethod.card: return Icons.credit_card;
//     }
//   }

//   Color _getPaymentColor(PaymentMethod method) {
//     switch (method) {
//       case PaymentMethod.cash: return Colors.green;
//       case PaymentMethod.wave: return Colors.blue;
//       case PaymentMethod.orangeMoney: return Colors.deepOrange;
//       case PaymentMethod.freeMoney: return Colors.purple;
//       case PaymentMethod.card: return Colors.indigo;
//     }
//   }

//   IconData _getTypeIcon(ParcelType type) {
//     switch (type) {
//       case ParcelType.document: return Icons.description;
//       case ParcelType.package: return Icons.inventory;
//       case ParcelType.fragile: return Icons.science;
//       case ParcelType.perishable: return Icons.eco;
//       case ParcelType.valuable: return Icons.attach_money;
//     }
//   }

//   ImageProvider _getImageProvider(String path) {
//     if (kIsWeb) return NetworkImage(path);
//     return FileImage(File(path));
//   }
// }

// mobile/lib/screens/parcel/new_parcel_screen.dart
// Modifiez les méthodes de gestion des vidéos

// ignore_for_file: unused_import, unused_field, unused_element, file_names

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import '../../models/garage.dart';
import '../../models/parcel.dart';
import '../../models/payment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parcel_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'parcel_detail_screen.dart';

class NewParcelScreenF extends ConsumerStatefulWidget {
  const NewParcelScreenF({super.key});

  @override
  ConsumerState<NewParcelScreenF> createState() => _NewParcelScreenState();
}

class _NewParcelScreenState extends ConsumerState<NewParcelScreenF> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  List<Garage> _garages = [];
  
  // Expéditeur
  final _senderNameController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _senderEmailController = TextEditingController();
  
  // Destinataire
  final _receiverNameController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  final _receiverEmailController = TextEditingController();
  final _receiverAddressController = TextEditingController();
  
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
  
  // Contrôleurs vidéo
  final Map<String, VideoPlayerController> _videoControllers = {};
  final Map<String, bool> _videoInitialized = {};
  
  // État de compression (seulement pour mobile)
  bool _isCompressing = false;
  String _compressionStatus = '';

  @override
  void initState() {
    super.initState();
    _loadGarages();
    // Ne pas initialiser VideoCompress sur le Web
    if (!kIsWeb) {
      VideoCompress.setLogLevel(0);
    }
  }

  @override
  void dispose() {
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    _senderEmailController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _receiverEmailController.dispose();
    _receiverAddressController.dispose();
    _descriptionController.dispose();
    _weightController.dispose();
    _priceController.dispose();
    _phoneNumberController.dispose();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    if (!kIsWeb) {
      VideoCompress.deleteAllCache();
    }
    super.dispose();
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

  // ✅ Version qui fonctionne sur Web et Mobile
  Future<void> _pickVideo() async {
    if (!mounted) return;
    XFile? video;
    try {
      video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        if (kIsWeb) {
          // Sur Web : ajouter directement sans compression
          setState(() {
            _videos.add(video!);
          });
          _initializeVideoController(video);
        } else {
          // Sur Mobile : compresser d'abord
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
            // Fallback: utiliser la vidéo originale
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
      // Fallback
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

  // Compression uniquement pour Mobile
  Future<XFile?> _compressVideo(XFile video) async {
  if (kIsWeb) return video; // Pas de compression sur Web
  
  try {
    // Obtenir la taille originale
    final originalSize = await video.length();
    debugPrint('📹 Compression vidéo - Taille originale: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');
    
    // Si la vidéo est déjà petite, pas besoin de compression
    if (originalSize < 2 * 1024 * 1024) { // Moins de 2MB
      debugPrint('📹 Vidéo déjà petite, pas de compression nécessaire');
      return video;
    }
    
    // Récupérer la durée de la vidéo pour adapter la compression
    final mediaInfo = await VideoCompress.getMediaInfo(video.path);
    final duration = mediaInfo.duration ?? 0;
    debugPrint('📹 Durée vidéo: ${duration}s');
    
    // Choisir la qualité selon la durée
    VideoQuality quality;
    if (duration > 60) {
      // Vidéo très longue (>1 minute)
      quality = VideoQuality.LowQuality;
    } else if (duration > 30) {
      // Vidéo moyenne (30-60 secondes)
      quality = VideoQuality.LowQuality;
    } else {
      // Vidéo courte (<30 secondes)
      quality = VideoQuality.MediumQuality;
    }
    
    // Options de compression (sans bitrate)
    final info = await VideoCompress.compressVideo(
      video.path,
      quality: quality,                        // Qualité adaptative
      deleteOrigin: false,
      includeAudio: true,
      frameRate: 20,                           // 20 fps pour réduire la taille
    );
    
    if (info != null && info.path != null) {
      final compressedFile = XFile(info.path!);
      final compressedSize = await compressedFile.length();
      final compressedSizeMB = compressedSize / 1024 / 1024;
      debugPrint('📹 Vidéo compressée: ${compressedSizeMB.toStringAsFixed(2)} MB');
      
      // Calculer le ratio de compression
      final ratio = (compressedSize / originalSize * 100).toStringAsFixed(1);
      debugPrint('📹 Ratio de compression: $ratio%');
      
      // Si la compression n'a pas réduit assez, refuser l'upload
      if (compressedSize > 15 * 1024 * 1024) { // Plus de 15MB après compression
        debugPrint('⚠️ Vidéo trop volumineuse même après compression (${compressedSizeMB.toStringAsFixed(2)} MB)');
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
      // Sur Web, utiliser NetworkImage ou ne pas initialiser
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
      const SnackBar(content: Text('Veuillez sélectionner un garage de départ'), backgroundColor: Colors.orange),
    );
    return;
  }
  
  if (!mounted) return;
  setState(() => _isLoading = true);
  
  try {
    final departureGarage = _garages.firstWhere((g) => g.id == _selectedDepartureGarageId);
    final arrivalGarage = _selectedArrivalGarageId != null 
        ? _garages.firstWhere((g) => g.id == _selectedArrivalGarageId)
        : departureGarage;
    
    final totalPrice = _calculateEstimatedPrice();
    final authState = ref.read(authProvider);
    final currentDriver = authState.user;
    
    // ÉTAPE 1: Créer le colis SANS les médias
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
      'driverId': currentDriver?.id,
      'driverName': currentDriver?.fullName,
      'driverPhone': currentDriver?.phone,
    };
    
    // Ajouter les champs optionnels
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
    if (totalPrice > 0) {
      parcelData['totalAmount'] = totalPrice;
    }
    
    debugPrint('📦 ÉTAPE 1: Création du colis...');
    final result = await ref.read(parcelProvider.notifier).createParcel(parcelData);
    
    if (result != null && mounted) {
      final parcelId = result.id;
      debugPrint('✅ Colis créé avec ID: $parcelId');
      
      final List<String> uploadedPhotoUrls = [];
      final List<String> uploadedVideoUrls = [];
      
      // ÉTAPE 2: Uploader les photos
      if (_photos.isNotEmpty) {
        debugPrint('📸 ÉTAPE 2: Upload de ${_photos.length} photo(s)...');
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
              debugPrint('✅ Photo ${i + 1} uploadée: $url');
              uploadedPhotoUrls.add(url);
            } else {
              debugPrint('❌ Échec upload photo ${i + 1}');
            }
          } catch (e) {
            debugPrint('❌ Erreur upload photo ${i + 1}: $e');
          }
        }
      }
      
      // ÉTAPE 3: Uploader les vidéos
      if (_videos.isNotEmpty) {
        debugPrint('🎬 ÉTAPE 3: Upload de ${_videos.length} vidéo(s)...');
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
              debugPrint('✅ Vidéo ${i + 1} uploadée: $url');
              uploadedVideoUrls.add(url);
            } else {
              debugPrint('❌ Échec upload vidéo ${i + 1}');
            }
          } catch (e) {
            debugPrint('❌ Erreur upload vidéo ${i + 1}: $e');
          }
        }
      }
      
      debugPrint('📊 Résultat: ${uploadedPhotoUrls.length} photos, ${uploadedVideoUrls.length} vidéos');
      
      // ÉTAPE 4: Mettre à jour le colis avec les URLs des médias
      if (uploadedPhotoUrls.isNotEmpty || uploadedVideoUrls.isNotEmpty) {
        if (mounted) {
          setState(() {
            _compressionStatus = 'Mise à jour du colis...';
            _isCompressing = true;
          });
        }
        
        try {
          final updateData = <String, dynamic>{};
          if (uploadedPhotoUrls.isNotEmpty) {
            updateData['photoUrls'] = uploadedPhotoUrls;
          }
          if (uploadedVideoUrls.isNotEmpty) {
            updateData['videoUrls'] = uploadedVideoUrls;
          }
          
          debugPrint('📤 ÉTAPE 4: Mise à jour du colis avec médias');
          await _apiService.updateParcelMedia(parcelId, updateData);
          debugPrint('✅ Colis mis à jour avec succès');
        } catch (e) {
          debugPrint('⚠️ Erreur mise à jour médias: $e');
          // Continuer même si la mise à jour échoue, le colis est déjà créé
        }
      } else {
        debugPrint('ℹ️ Aucun média à mettre à jour');
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCompressing = false;
          _compressionStatus = '';
        });
        _showSuccessDialog(result, totalPrice);
      }
    } else if (mounted) {
      setState(() {
        _isLoading = false;
        _isCompressing = false;
      });
      final errorState = ref.read(parcelProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorState.error ?? 'Erreur lors de la création'), backgroundColor: Colors.red),
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

  double _calculateEstimatedPrice() {
    double total = 0;
    if (_priceController.text.isNotEmpty) {
      total += double.tryParse(_priceController.text) ?? 0;
    }
    // if (_urgentDelivery) total += 500;
    // if (_insurance && _priceController.text.isNotEmpty) {
    //   total += (double.tryParse(_priceController.text) ?? 0) * 0.02;
    // }
    return total;
  }

  void _showSuccessDialog(Parcel parcel, double amount) {
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
            Text('📦 ${parcel.trackingNumber}'),
            const SizedBox(height: 8),
            Text('💰 ${amount.toStringAsFixed(0)} FCFA'),
            const SizedBox(height: 8),
            Text('👤 Client: ${_senderNameController.text.trim()}'),
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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => ParcelDetailScreen(parcel: parcel)),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color.fromARGB(255, 241, 242, 246)),
            child: const Text('Voir le colis'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    _senderNameController.clear();
    _senderPhoneController.clear();
    _senderEmailController.clear();
    _receiverNameController.clear();
    _receiverPhoneController.clear();
    _receiverEmailController.clear();
    _receiverAddressController.clear();
    _descriptionController.clear();
    _weightController.clear();
    _priceController.clear();
    _phoneNumberController.clear();
    if (mounted) {
      setState(() {
        _selectedType = ParcelType.package;
        _selectedDepartureGarageId = null;
        _selectedArrivalGarageId = null;
        _selectedPaymentMethod = PaymentMethod.cash;
        _urgentDelivery = false;
        _insurance = false;
        _photos.clear();
        _videos.clear();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouveau colis'),
        backgroundColor: const Color.fromARGB(255, 5, 243, 243),
        foregroundColor: Colors.white,
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
                  // Section Expéditeur
                  _buildSection(
                    icon: Icons.person_outline,
                    title: 'Client (Expéditeur)',
                    color: Colors.blue,
                    child: Column(
                      children: [
                        CustomTextField(
                          controller: _senderNameController,
                          label: 'Nom complet du client',
                          prefixIcon: Icons.person,
                          validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _senderPhoneController,
                          label: 'Téléphone du client',
                          prefixIcon: Icons.phone,
                          keyboardType: TextInputType.phone,
                          validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          controller: _senderEmailController,
                          label: 'Email du client (optionnel)',
                          prefixIcon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Section Destinataire
                  _buildSection(
                    icon: Icons.person,
                    title: 'Destinataire',
                    color: Colors.blue,
                    child: Column(
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
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Section Informations colis
                  _buildSection(
                    icon: Icons.inventory,
                    title: 'Informations colis',
                    color: Colors.green,
                    child: Column(
                      children: [
                        CustomTextField(
                          controller: _descriptionController,
                          label: 'Description',
                          prefixIcon: Icons.description,
                          maxLines: 3,
                          validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                        ),
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
                          initialValue: _selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Type de colis',
                            prefixIcon: Icon(Icons.category),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
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
                  ),
                  const SizedBox(height: 16),
                  
                  // Section Trajet
                  _buildSection(
                    icon: Icons.route,
                    title: 'Trajet',
                    color: Colors.orange,
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedDepartureGarageId,
                          hint: const Text('Lieu de départ'),
                          decoration: const InputDecoration(
                            labelText: 'Lieu de départ',
                            prefixIcon: Icon(Icons.departure_board),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                          ),
                          items: _garages.map((garage) => DropdownMenuItem(
                            value: garage.id,
                            child: Text('${garage.name} - ${garage.city}'),
                          )).toList(),
                          onChanged: (value) {
                            if (mounted) {
                              setState(() => _selectedDepartureGarageId = value);
                            }
                          },
                          validator: (v) => v == null ? 'Champ requis' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          initialValue: _selectedArrivalGarageId,
                          hint: const Text('Garage d\'arrivée (optionnel)'),
                          decoration: const InputDecoration(
                            labelText: 'Garage arrivée',
                            prefixIcon: Icon(Icons.location_on),
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Aucun (même lieu que le départ)')),
                            ..._garages.map((garage) => DropdownMenuItem(
                              value: garage.id,
                              child: Text('${garage.name} - ${garage.city}'),
                            )),
                          ],
                          onChanged: (value) {
                            if (mounted) {
                              setState(() => _selectedArrivalGarageId = value);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Section Médias
                  _buildMediaSection(),
                  const SizedBox(height: 16),
                  
                  // SECTION OPTIONS - COMMENTÉE (Assurance et livraison urgente masquées)
                  // _buildSection(
                  //   icon: Icons.settings,
                  //   title: 'Options',
                  //   color: Colors.purple,
                  //   child: Column(
                  //     children: [
                  //       SwitchListTile(
                  //         title: const Text('Livraison urgente'),
                  //         subtitle: const Text('Priorité + 500 FCFA'),
                  //         value: _urgentDelivery,
                  //         onChanged: (value) {
                  //           if (mounted) {
                  //             setState(() => _urgentDelivery = value);
                  //           }
                  //         },
                  //         activeTrackColor: const Color(0xFF0B6E3A).withAlpha(128),
                  //         activeThumbColor: const Color(0xFF0B6E3A),
                  //         contentPadding: EdgeInsets.zero,
                  //       ),
                  //       SwitchListTile(
                  //         title: const Text('Assurance colis'),
                  //         subtitle: const Text('Protection jusqu\'à 50 000 FCFA (2%)'),
                  //         value: _insurance,
                  //         onChanged: (value) {
                  //           if (mounted) {
                  //             setState(() => _insurance = value);
                  //           }
                  //         },
                  //         activeTrackColor: const Color(0xFF0B6E3A).withAlpha(128),
                  //         activeThumbColor: const Color(0xFF0B6E3A),
                  //         contentPadding: EdgeInsets.zero,
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  // const SizedBox(height: 16),
                  
                  // SECTION PAIEMENT - COMMENTÉE
                  // _buildPaymentSection(),
                  // const SizedBox(height: 32),
                  
                  // Bouton de création
                  CustomButton(
                    text: 'Enregistrer le colis',
                    onPressed: _createParcel,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 16),
                  
                  // Info chauffeur
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info, color: Colors.green),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Vous êtes identifié comme chauffeur. Le colis vous sera automatiquement assigné.',
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          
          // Overlay de compression (seulement pour mobile)
          if (_isCompressing && !kIsWeb)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Compression de la vidéo...',
                          style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMediaSection() {
    return _buildSection(
      icon: Icons.photo_library,
      title: 'Photos et vidéos',
      color: Colors.teal,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildMediaButton(icon: Icons.photo_library, label: 'Galerie', onTap: _pickPhoto, color: Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildMediaButton(icon: Icons.camera_alt, label: 'Appareil', onTap: _takePhoto, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMediaButton(icon: Icons.video_library, label: 'Vidéo', onTap: _pickVideo, color: Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildMediaButton(icon: Icons.videocam, label: 'Enregistrer', onTap: _recordVideo, color: Colors.red)),
            ],
          ),
          if (_photos.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                itemBuilder: (context, index) => _buildPhotoThumbnail(_photos[index], index),
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
                itemBuilder: (context, index) => _buildVideoThumbnail(_videos[index], index),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaButton({required IconData icon, required String label, required VoidCallback onTap, required Color color}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            borderRadius: BorderRadius.circular(8),
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
              decoration: BoxDecoration(color: Colors.black.withAlpha(150), shape: BoxShape.circle),
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
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.black),
          child: Center(
            child: !kIsWeb && isInitialized && controller != null
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
              decoration: BoxDecoration(color: Colors.black.withAlpha(150), shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 20, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // Section Paiement commentée
  // Widget _buildPaymentSection() {
  //   final double estimatedPrice = _calculateEstimatedPrice();
  //   
  //   return _buildSection(
  //     icon: Icons.payment,
  //     title: 'Paiement',
  //     color: Colors.deepPurple,
  //     child: Column(
  //       children: [
  //         Container(
  //           padding: const EdgeInsets.all(12),
  //           decoration: BoxDecoration(
  //             color: Colors.deepPurple.withAlpha(25),
  //             borderRadius: BorderRadius.circular(12),
  //           ),
  //           child: Column(
  //             children: [
  //               Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   const Text('Prix du colis:'),
  //                   Text('${_priceController.text.isEmpty ? '0' : _priceController.text} FCFA'),
  //                 ],
  //               ),
  //               if (_urgentDelivery) ...[
  //                 const SizedBox(height: 4),
  //                 Row(
  //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                   children: const [Text('Frais urgent:'), Text('500 FCFA')],
  //                 ),
  //               ],
  //               if (_insurance) ...[
  //                 const SizedBox(height: 4),
  //                 Row(
  //                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                   children: const [Text('Assurance:'), Text('2% du montant')],
  //                 ),
  //               ],
  //               const Divider(height: 16),
  //               Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   const Text('Total à payer:', style: TextStyle(fontWeight: FontWeight.bold)),
  //                   Text(
  //                     '${estimatedPrice.toStringAsFixed(0)} FCFA',
  //                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0B6E3A)),
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //         
  //         const Text('Mode de paiement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
  //         const SizedBox(height: 8),
  //         
  //         SingleChildScrollView(
  //           scrollDirection: Axis.horizontal,
  //           child: Row(
  //             children: PaymentMethod.values.map((method) {
  //               final isSelected = _selectedPaymentMethod == method;
  //               return Padding(
  //                 padding: const EdgeInsets.only(right: 8),
  //                 child: ChoiceChip(
  //                   label: Row(
  //                     mainAxisSize: MainAxisSize.min,
  //                     children: [
  //                       Icon(_getPaymentIcon(method), size: 16, color: isSelected ? Colors.white : _getPaymentColor(method)),
  //                       const SizedBox(width: 6),
  //                       Text(method.label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
  //                     ],
  //                   ),
  //                   selected: isSelected,
  //                   onSelected: (selected) {
  //                     if (selected && mounted) {
  //                       setState(() => _selectedPaymentMethod = method);
  //                     }
  //                   },
  //                   selectedColor: _getPaymentColor(method),
  //                   backgroundColor: Colors.grey.shade100,
  //                 ),
  //               );
  //             }).toList(),
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //         
  //         if (_selectedPaymentMethod == PaymentMethod.wave ||
  //             _selectedPaymentMethod == PaymentMethod.orangeMoney ||
  //             _selectedPaymentMethod == PaymentMethod.freeMoney)
  //           CustomTextField(
  //             controller: _phoneNumberController,
  //             label: 'Numéro de téléphone du client',
  //             prefixIcon: Icons.phone_android,
  //             keyboardType: TextInputType.phone,
  //             hint: 'Ex: 77 123 45 67',
  //             validator: (v) {
  //               if (v == null || v.isEmpty) return 'Numéro requis';
  //               if (v.length < 9) return 'Numéro invalide';
  //               return null;
  //             },
  //           ),
  //       ],
  //     ),
  //   );
  // }

  IconData _getPaymentIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash: return Icons.money;
      case PaymentMethod.wave: return Icons.waves;
      case PaymentMethod.orangeMoney: return Icons.phone_android;
      case PaymentMethod.freeMoney: return Icons.smartphone;
      case PaymentMethod.card: return Icons.credit_card;
    }
  }

  Color _getPaymentColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash: return Colors.green;
      case PaymentMethod.wave: return Colors.blue;
      case PaymentMethod.orangeMoney: return Colors.deepOrange;
      case PaymentMethod.freeMoney: return Colors.purple;
      case PaymentMethod.card: return Colors.indigo;
    }
  }

  IconData _getTypeIcon(ParcelType type) {
    switch (type) {
      case ParcelType.document: return Icons.description;
      case ParcelType.package: return Icons.inventory;
      case ParcelType.fragile: return Icons.science;
      case ParcelType.perishable: return Icons.eco;
      case ParcelType.valuable: return Icons.attach_money;
    }
  }

  ImageProvider _getImageProvider(String path) {
    if (kIsWeb) return NetworkImage(path);
    return FileImage(File(path));
  }
}