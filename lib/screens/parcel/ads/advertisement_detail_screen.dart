import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:procolis/theme/fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/parcel.dart';
import '../../../models/user.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_bottom_nav.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/negotiation_chat_widget.dart';
import '../../../widgets/pc_components.dart';

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

  final _priceController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmittingOffer = false;

  // Lecture de la note vocale attachee a l'annonce.
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingAudio = false;

  String get _adId => widget.adId ?? widget.parcel?.id ?? '';

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
    _loadAll();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _priceController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Resout une URL de media : les chemins relatifs `/uploads/...` sont
  /// prefixes avec le backend, comme dans le reste de l'application.
  String _mediaUrl(String url) => url.startsWith('http')
      ? url
      : ApiService.resolveMediaUrl(url);

  Future<void> _toggleAdAudio(String url) async {
    try {
      if (_isPlayingAudio) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _isPlayingAudio = false);
        return;
      }
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(_mediaUrl(url)));
      if (mounted) setState(() => _isPlayingAudio = true);
    } catch (_) {
      if (mounted) setState(() => _isPlayingAudio = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lecture audio impossible'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
        );
      }
    }
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final launched = await launchUrl(uri);
      if (launched) return;
    } catch (_) {}
    // Repli : copie du numero dans le presse-papiers.
    await Clipboard.setData(ClipboardData(text: phone));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appel impossible. Numero copie : $phone'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBottomBar(),
          const AppBottomNav(),
        ],
      ),
      body: Column(
        children: [
          _buildHero(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAll,
                    color: AppTheme.primary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDriverProfile(),
                          const SizedBox(height: 16),
                          _buildDetailsCard(),
                          if (_myOffer != null) ...[
                            const SizedBox(height: 16),
                            _buildMyOfferCard(),
                          ],
                          if (_myOffer == null && widget.parcel != null) ...[
                            const SizedBox(height: 16),
                            _buildSenderInfo(),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Hero (bandeau brand : route depart -> arrivee)
  // ============================================================

  Widget _buildHero() {
    final departure = widget.parcel?.departureGarageName ??
        _adData?['departureCity']?.toString() ??
        _adData?['departureGarageName']?.toString() ??
        'Depart';
    final arrival = widget.parcel?.arrivalGarageName ??
        _adData?['arrivalCity']?.toString() ??
        _adData?['arrivalGarageName']?.toString() ??
        'Arrivee';

    return PcGradientHeader(
      padding: const EdgeInsets.fromLTRB(12, 52, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HeroBackButton(onTap: () => Navigator.pop(context)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Detail de l\'annonce',
                  style: AppFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: _HeroPlace(label: 'Depart', place: departure),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                Expanded(
                  child: _HeroPlace(
                    label: 'Arrivee',
                    place: arrival,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Carte chauffeur
  // ============================================================

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

    return PcCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PcAvatar(driverName, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  style: AppFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (garageName != null && garageName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    garageName,
                    style: AppFonts.manrope(
                      fontSize: 13,
                      color: AppTheme.slate500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (driverPhone != null && driverPhone.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _callPhone(driverPhone),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_rounded, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 5),
                        Text(
                          driverPhone,
                          style: AppTheme.mono(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.teal600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (rating != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.amber50,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 15, color: AppTheme.amber500),
                  const SizedBox(width: 3),
                  Text(
                    rating.toStringAsFixed(1),
                    style: AppFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.amber700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // Carte details
  // ============================================================

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
    final adAudioUrl = _adData?['audioUrl']?.toString();

    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PcSectionHeader('Details'),
          if (departureDate != null)
            _detailRow(
              icon: Icons.calendar_today_rounded,
              label: 'Date de depart',
              value: DateFormat('dd MMMM yyyy', 'fr').format(departureDate),
              valueStyle: AppTheme.mono(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          if (weight > 0)
            _detailRow(
              icon: Icons.monitor_weight_outlined,
              label: 'Poids disponible',
              value: '${weight.toStringAsFixed(1)} kg',
              valueStyle: AppTheme.mono(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          if (price != null && price > 0)
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
          if (createdAt != null)
            _detailRow(
              icon: Icons.schedule_rounded,
              label: 'Publiee',
              value: _formatRelativeTime(createdAt),
            ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Description',
              style: AppFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate500,
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
                style: AppFonts.manrope(
                  fontSize: 14,
                  height: 1.5,
                  color: AppTheme.slate700,
                ),
              ),
            ),
          ],
          if (adAudioUrl != null && adAudioUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.headphones_rounded, size: 18, color: AppTheme.slate500),
                const SizedBox(width: 8),
                Text(
                  'Audio joint',
                  style: AppFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate500,
                  ),
                ),
                const Spacer(),
                PcButton(
                  _isPlayingAudio ? 'Arreter' : 'Ecouter',
                  icon: _isPlayingAudio
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  variant: PcButtonVariant.secondary,
                  size: PcButtonSize.sm,
                  onPressed: () => _toggleAdAudio(adAudioUrl),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.slate400),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate500,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: valueStyle ??
                  AppFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Carte "Votre offre"
  // ============================================================

  Widget _buildMyOfferCard() {
    if (_myOffer == null) return const SizedBox.shrink();

    final price = (_myOffer!['price'] as num?)?.toDouble() ?? 0;
    final message = _myOffer!['message']?.toString();
    final status = _myOffer!['status']?.toString() ?? 'pending';
    final isAccepted = status == 'accepted';
    final isRejected = status == 'rejected';

    PcTone tone;
    String statusText;
    IconData statusIcon;
    if (isAccepted) {
      tone = PcTone.green;
      statusText = 'Acceptee';
      statusIcon = Icons.check_circle_rounded;
    } else if (isRejected) {
      tone = PcTone.red;
      statusText = 'Refusee';
      statusIcon = Icons.cancel_rounded;
    } else {
      tone = PcTone.amber;
      statusText = 'En attente';
      statusIcon = Icons.hourglass_empty_rounded;
    }

    return PcCard(
      color: AppTheme.teal50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: AppTheme.teal600, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Votre offre',
                      style: AppFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    PcBadge(statusText, tone: tone),
                  ],
                ),
              ),
              Text(
                '${_formatMoney(price)} FCFA',
                style: AppTheme.mono(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.teal700,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                message,
                style: AppFonts.manrope(
                  fontSize: 13,
                  height: 1.45,
                  color: AppTheme.slate700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          PcButton(
            'Voir la discussion',
            icon: Icons.forum_outlined,
            variant: PcButtonVariant.secondary,
            block: true,
            onPressed: _openDiscussion,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Carte expediteur
  // ============================================================

  Widget _buildSenderInfo() {
    if (widget.parcel == null) return const SizedBox.shrink();

    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PcSectionHeader('Expediteur'),
          _detailRow(
            icon: Icons.person_outline_rounded,
            label: 'Nom',
            value: widget.parcel!.senderName,
          ),
          _detailRow(
            icon: Icons.phone_rounded,
            label: 'Telephone',
            value: widget.parcel!.senderPhone,
            valueStyle: AppTheme.mono(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Barre d'action
  // ============================================================

  Widget _buildBottomBar() {
    if (_isLoading) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(top: BorderSide(color: AppTheme.slate200)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: _myOffer != null
              ? PcButton(
                  'Negocier',
                  icon: Icons.chat_bubble_outline_rounded,
                  variant: PcButtonVariant.secondary,
                  size: PcButtonSize.lg,
                  block: true,
                  onPressed: _openNegotiationChat,
                )
              : PcButton(
                  'Faire une offre',
                  icon: Icons.gavel_rounded,
                  size: PcButtonSize.lg,
                  block: true,
                  onPressed: _showOfferSheet,
                ),
        ),
      ),
    );
  }

  // ============================================================
  // Feuille "Faire une offre"
  // ============================================================

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
                        Text(
                          'Votre offre',
                          style: AppFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_userParcels.isNotEmpty) ...[
                          Text(
                            'Selectionner un colis',
                            style: AppFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.slate500,
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
                        PcButton(
                          'Envoyer l\'offre',
                          icon: Icons.send_rounded,
                          size: PcButtonSize.lg,
                          block: true,
                          loading: _isSubmittingOffer,
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
        await _loadAll();
        _openDiscussion();
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
    final driverName = widget.parcel?.driverName ??
        _adData?['driver']?['fullName']?.toString() ??
        'Chauffeur';
    final offerId = _myOffer?['id']?.toString();
    final adId = _adData?['id']?.toString() ?? _adId;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NegotiationChatScreen(
          peerId: driverId,
          peerName: driverName,
          parcelId: _adId,
          advertisementId: adId,
          offerId: offerId,
          onChanged: _loadAll,
        ),
      ),
    );
  }

  void _openNegotiationChat() {
    _openDiscussion();
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

// ============================================================
// Sous-widgets du bandeau hero
// ============================================================

class _HeroBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _HeroPlace extends StatelessWidget {
  final String label;
  final String place;
  final bool alignEnd;

  const _HeroPlace({
    required this.label,
    required this.place,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Colors.white.withOpacity(0.75),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          place,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: AppFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
