import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/parcel.dart';
import '../../../models/user.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/procolis_design_system.dart';

class AdvertisementDetailScreen extends StatefulWidget {
  final Parcel? parcel;
  final String? adId;

  const AdvertisementDetailScreen({
    super.key,
    this.parcel,
    this.adId,
  });

  @override
  State<AdvertisementDetailScreen> createState() =>
      _AdvertisementDetailScreenState();
}

class _AdvertisementDetailScreenState extends State<AdvertisementDetailScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  Map<String, dynamic>? _adData;
  List<Parcel> _userParcels = [];
  Map<String, dynamic>? _myOffer;
  User? _currentUser;

  final _priceController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmittingOffer = false;

  String get _adId => widget.adId ?? widget.parcel?.id ?? '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    User? user;
    Map<String, dynamic>? detail;
    List<Parcel> parcels = [];

    try {
      user = await _apiService.getCurrentUser();
    } catch (_) {}

    if (_adId.isNotEmpty) {
      try {
        detail = await _apiService.getAdvertisementDetail(_adId);
      } catch (_) {}
    }

    try {
      parcels = await _apiService.getMyParcels();
    } catch (_) {}

    Map<String, dynamic>? myOffer;
    if (_adId.isNotEmpty && detail != null) {
      final offers = detail['offers'] as List<dynamic>? ?? [];
      for (final o in offers) {
        final offer = o as Map<String, dynamic>;
        final client = offer['client'] as Map<String, dynamic>?;
        if (client != null && user != null && client['id']?.toString() == user.id) {
          myOffer = offer;
          break;
        }
      }
    }

    if (mounted) {
      setState(() {
        _currentUser = user;
        _adData = detail;
        _userParcels = parcels;
        _myOffer = myOffer;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.parcel?.description ?? _adData?['description']?.toString() ?? 'Annonce',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDriverProfile(),
                    const SizedBox(height: 20),
                    _buildRouteDisplay(),
                    const SizedBox(height: 20),
                    _buildDetailsCard(),
                    if (_myOffer != null) ...[
                      const SizedBox(height: 20),
                      _buildMyOfferCard(),
                    ],
                    if (_myOffer == null && widget.parcel != null) ...[
                      const SizedBox(height: 20),
                      _buildSenderInfo(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBottomBar() {
    if (_myOffer != null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openNegotiationChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
                  label: const Text('Negocier'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: const BorderSide(color: AppTheme.primary),
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: CustomButton(
          text: 'Faire une offre',
          icon: Icons.send_rounded,
          onPressed: _showOfferSheet,
        ),
      ),
    );
  }

  Widget _buildDriverProfile() {
    final driverName = widget.parcel?.driverName ??
        _adData?['driver']?['fullName']?.toString() ??
        _adData?['driverName']?.toString() ??
        'Chauffeur';
    final driverPhone = widget.parcel?.driverPhone ??
        _adData?['driver']?['phone']?.toString() ??
        _adData?['driverPhone']?.toString();
    final garageName = _adData?['driver']?['garageName']?.toString() ??
        _adData?['garageName']?.toString();
    final rating = (_adData?['driver']?['rating'] as num?)?.toDouble() ??
        (_adData?['rating'] as num?)?.toDouble();

    final color = _avatarColor(driverName);
    final initials = _initials(driverName);

    return ProcolisCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: color,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (garageName != null && garageName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    garageName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (driverPhone != null && driverPhone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(driverPhone),
                          backgroundColor: AppTheme.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_rounded, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          driverPhone,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (rating != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...List.generate(5, (i) {
                        if (i < rating.floor()) {
                          return const Icon(Icons.star_rounded, size: 16, color: AppTheme.secondary);
                        } else if (i < rating.ceil() && rating - rating.floor() >= 0.5) {
                          return const Icon(Icons.star_half_rounded, size: 16, color: AppTheme.secondary);
                        } else {
                          return const Icon(Icons.star_border_rounded, size: 16, color: AppTheme.slate300);
                        }
                      }),
                      const SizedBox(width: 6),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteDisplay() {
    final departure = widget.parcel?.departureGarageName ??
        _adData?['departureCity']?.toString() ??
        _adData?['departureGarageName']?.toString() ??
        'Depart';
    final arrival = widget.parcel?.arrivalGarageName ??
        _adData?['arrivalCity']?.toString() ??
        _adData?['arrivalGarageName']?.toString() ??
        'Arrivee';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity( 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.primary.withOpacity( 0.12),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              departure,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity( 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Text(
              arrival,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    final price = widget.parcel?.proposedPrice ??
        (_adData?['proposedPrice'] as num?)?.toDouble();
    final weight = widget.parcel?.weight != null && widget.parcel!.weight > 0
        ? widget.parcel!.weight
        : ((_adData?['availableWeight'] as num?)?.toDouble() ?? 0);
    final departureDate = widget.parcel?.pickupDate ??
        (_adData?['departureDate'] != null
            ? DateTime.tryParse(_adData!['departureDate'].toString())
            : null);
    final createdAt = widget.parcel?.createdAt ??
        (_adData?['createdAt'] != null
            ? DateTime.tryParse(_adData!['createdAt'].toString())
            : null);
    final description = widget.parcel?.description ??
        _adData?['description']?.toString();
    final audioUrls = widget.parcel?.audioUrls ?? <String>[];
    final adAudioUrl = _adData?['audioUrl']?.toString();

    return ProcolisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          if (departureDate != null) ...[
            _detailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Date de depart',
              value: DateFormat('dd MMMM yyyy', 'fr').format(departureDate),
            ),
            const SizedBox(height: 10),
          ],
          if (weight > 0) ...[
            _detailRow(
              icon: Icons.monitor_weight_outlined,
              label: 'Poids disponible',
              value: '${weight.toStringAsFixed(1)} kg',
            ),
            const SizedBox(height: 10),
          ],
          if (price != null && price > 0) ...[
            _detailRow(
              icon: Icons.sell_outlined,
              label: 'Prix propose',
              value: '${_formatMoney(price)} FCFA',
              valueStyle: AppTheme.mono(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppTheme.teal600,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (createdAt != null) ...[
            _detailRow(
              icon: Icons.schedule_rounded,
              label: 'Date de publication',
              value: _formatRelativeTime(createdAt),
            ),
            const SizedBox(height: 10),
          ],
          if (description != null && description.isNotEmpty) ...[
            const Divider(height: 1, color: AppTheme.slate200),
            const SizedBox(height: 12),
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppTheme.slate700,
                ),
              ),
            ),
          ],
          if (adAudioUrl != null && adAudioUrl.isNotEmpty) ...[
            const Divider(height: 1, color: AppTheme.slate200),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.headphones_rounded, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                const Text(
                  'Audio joint',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 36,
                  child: ElevatedButton.tonalIcon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Lecture audio...'),
                          backgroundColor: AppTheme.primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Ecouter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.teal50,
                      foregroundColor: AppTheme.teal700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
    TextStyle? valueStyle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.slate400),
        const SizedBox(width: 10),
        Text(
          '$label  ',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          textAlign: TextAlign.right,
          style: valueStyle ??
              const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
        ),
      ],
    );
  }

  Widget _buildMyOfferCard() {
    if (_myOffer == null) return const SizedBox.shrink();

    final price = (_myOffer!['price'] as num?)?.toDouble() ?? 0;
    final message = _myOffer!['message']?.toString();
    final status = _myOffer!['status']?.toString() ?? 'pending';
    final isAccepted = status == 'accepted';
    final isRejected = status == 'rejected';
    final isPending = status == 'pending';

    Color statusColor;
    String statusText;
    IconData statusIcon;
    if (isAccepted) {
      statusColor = AppTheme.successColor;
      statusText = 'Offre acceptee';
      statusIcon = Icons.check_circle_rounded;
    } else if (isRejected) {
      statusColor = AppTheme.errorColor;
      statusText = 'Offre rejetee';
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = AppTheme.warningColor;
      statusText = 'En attente';
      statusIcon = Icons.hourglass_empty_rounded;
    }

    return ProcolisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity( 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Votre offre',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity( 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_formatMoney(price)} FCFA',
                style: AppTheme.mono(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.teal600,
                ),
              ),
            ],
          ),
          if (message != null && message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppTheme.slate700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openDiscussion,
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: const Text('Voir la discussion'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.slate200),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderInfo() {
    if (widget.parcel == null) return const SizedBox.shrink();

    return ProcolisCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expediteur',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _detailRow(
            icon: Icons.person_outline_rounded,
            label: 'Nom',
            value: widget.parcel!.senderName,
          ),
          const SizedBox(height: 8),
          _detailRow(
            icon: Icons.phone_rounded,
            label: 'Telephone',
            value: widget.parcel!.senderPhone,
          ),
        ],
      ),
    );
  }

  void _showOfferSheet() {
    _priceController.clear();
    _messageController.clear();
    Parcel? selectedParcel;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: const BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.slate300,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Votre offre',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_userParcels.isNotEmpty) ...[
                          const Text(
                            'Selectionner un colis',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _userParcels.length + 1,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (ctx, index) {
                                if (index == 0) {
                                  final isSelected = selectedParcel == null;
                                  return ChoiceChip(
                                    label: const Text('Aucun'),
                                    selected: isSelected,
                                    onSelected: (_) {
                                      setSheetState(() => selectedParcel = null);
                                    },
                                    selectedColor: AppTheme.teal50,
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? AppTheme.teal700 : AppTheme.textSecondary,
                                    ),
                                    side: BorderSide(
                                      color: isSelected ? AppTheme.primary : AppTheme.slate200,
                                    ),
                                  );
                                }
                                final parcel = _userParcels[index - 1];
                                final isSelected = selectedParcel?.id == parcel.id;
                                return ChoiceChip(
                                  label: Text(
                                    parcel.trackingNumber,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? AppTheme.teal700 : AppTheme.textSecondary,
                                    ),
                                  ),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setSheetState(() => selectedParcel = parcel);
                                  },
                                  selectedColor: AppTheme.teal50,
                                  side: BorderSide(
                                    color: isSelected ? AppTheme.primary : AppTheme.slate200,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        CustomTextField(
                          controller: _priceController,
                          label: 'Prix propose (FCFA)',
                          hint: 'ex: 10000',
                          prefixIcon: Icons.sell_outlined,
                          keyboardType: TextInputType.number,
                          style: AppTheme.mono(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        CustomTextField(
                          controller: _messageController,
                          label: 'Message (optionnel)',
                          hint: 'Votre message pour le chauffeur...',
                          maxLines: 3,
                          maxLength: 200,
                        ),
                        if (_messageController.text.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${_messageController.text.length}/200',
                              style: TextStyle(
                                fontSize: 11,
                                color: _messageController.text.length > 180
                                    ? AppTheme.warningColor
                                    : AppTheme.slate400,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        CustomButton(
                          text: 'Envoyer l\'offre',
                          icon: Icons.send_rounded,
                          isLoading: _isSubmittingOffer,
                          onPressed: _isSubmittingOffer
                              ? null
                              : () => _submitOffer(ctx, selectedParcel),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      if (_isSubmittingOffer) {
        setState(() => _isSubmittingOffer = false);
      }
    });
  }

  Future<void> _submitOffer(BuildContext sheetContext, Parcel? selectedParcel) async {
    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(
          content: const Text('Veuillez entrer un prix valide'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        ),
      );
      return;
    }

    setState(() => _isSubmittingOffer = true);

    try {
      final data = <String, dynamic>{
        'price': price.toInt(),
        'message': _messageController.text.trim().isNotEmpty
            ? _messageController.text.trim()
            : null,
        if (selectedParcel != null) 'parcelId': selectedParcel.id,
      };

      final result = await _apiService.createAdvertisementOffer(_adId, data);

      if (!mounted) return;

      if (result['success'] == true || result['id'] != null || result['offer'] != null) {
        Navigator.pop(sheetContext);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Offre envoyee avec succes'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        );
        await _loadAll();
      } else {
        final errorMsg = result['message']?.toString() ?? 'Erreur lors de l\'envoi de l\'offre';
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          SnackBar(
            content: const Text('Erreur reseau, veuillez reessayer'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingOffer = false);
    }
  }

  void _openDiscussion() {
    final driverId = widget.parcel?.driverId ??
        _adData?['driverId']?.toString() ??
        _adData?['driver']?['id']?.toString() ??
        '';

    Navigator.pushNamed(
      context,
      '/messages',
      arguments: {
        'peerId': driverId,
        'peerName': widget.parcel?.driverName ??
            _adData?['driver']?['fullName']?.toString() ??
            'Chauffeur',
        'parcelId': _adId,
      },
    );
  }

  void _openNegotiationChat() {
    _openDiscussion();
  }

  static Color _avatarColor(String name) {
    final colors = [
      AppTheme.teal500,
      AppTheme.green500,
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFFDB2777),
      const Color(0xFFEA580C),
      AppTheme.amber500,
      AppTheme.red400,
    ];
    final hash = name.isEmpty ? 0 : name.codeUnits.fold(0, (sum, c) => sum + c);
    return colors[hash.abs() % colors.length];
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  static String _formatMoney(num value) {
    final rounded = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < rounded.length; i++) {
      final reverseIndex = rounded.length - i;
      buffer.write(rounded[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) buffer.write(' ');
    }
    return buffer.toString();
  }

  String _formatRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "a l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return DateFormat('dd/MM/yyyy', 'fr').format(date);
  }
}
