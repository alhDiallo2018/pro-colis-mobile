import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/parcel.dart';
import '../../providers/parcel_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';

class ConfirmDeliveryScreen extends ConsumerStatefulWidget {
  final Parcel parcel;

  const ConfirmDeliveryScreen({super.key, required this.parcel});

  @override
  ConsumerState<ConfirmDeliveryScreen> createState() =>
      _ConfirmDeliveryScreenState();
}

class _ConfirmDeliveryScreenState extends ConsumerState<ConfirmDeliveryScreen> {
  final ApiService _apiService = ApiService();

  String? _deliveryCode;
  bool _isLoadingCode = true;
  String? _loadError;
  String _pin = '';
  bool _isSubmitting = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _fetchDeliveryCode();
  }

  Future<void> _fetchDeliveryCode() async {
    setState(() {
      _isLoadingCode = true;
      _loadError = null;
    });
    try {
      final code = await _apiService.getDeliveryCode(widget.parcel.id);
      if (!mounted) return;
      if (code.isEmpty) {
        setState(() {
          _loadError = 'Code de livraison non disponible';
          _isLoadingCode = false;
        });
        return;
      }
      setState(() {
        _deliveryCode = code;
        _isLoadingCode = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Impossible de récupérer le code de livraison';
        _isLoadingCode = false;
      });
    }
  }

  void _pushKey(String key) {
    if (_isSubmitting || _done) return;

    if (key == 'del') {
      if (_pin.isEmpty) return;
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }

    if (_pin.length >= 4) return;

    final next = '$_pin$key';
    setState(() => _pin = next);
    if (next.length == 4) {
      _confirm(next);
    }
  }

  Future<void> _confirm(String pin) async {
    if (_isSubmitting || _deliveryCode == null) return;

    setState(() => _isSubmitting = true);
    try {
      if (pin != _deliveryCode) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        setState(() => _pin = '');
        _showSnack('Code PIN incorrect');
        return;
      }

      final result =
          await ref.read(parcelProvider.notifier).advanceParcel(
                widget.parcel.id,
                'deliver',
                otp: pin,
              );

      if (!mounted) return;
      if (result['success'] != true) {
        final msg = result['message']?.toString() ?? 'Confirmation impossible';
        _showSnack(msg);
        return;
      }

      setState(() => _done = true);
    } catch (error) {
      debugPrint('Erreur confirmation livraison: $error');
      if (mounted) _showSnack('Erreur lors de la confirmation');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _buildSuccess();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Confirmer la livraison'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
                child: const Icon(
                  Icons.lock_open_rounded,
                  color: AppTheme.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Code du destinataire',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  text: 'Demandez à ',
                  children: [
                    TextSpan(
                      text: widget.parcel.receiverName.isEmpty
                          ? 'au destinataire'
                          : widget.parcel.receiverName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const TextSpan(
                      text:
                          ' le code PIN à 4 chiffres reçu par SMS pour valider la remise.',
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              _OtpBoxes(value: _pin),
              const SizedBox(height: 8),
              _buildCodeHint(),
              if (_isSubmitting) ...[
                const SizedBox(height: 18),
                const CircularProgressIndicator(color: AppTheme.primary),
              ],
              const Spacer(),
              _Keypad(onKey: _deliveryCode != null ? _pushKey : (_) {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeHint() {
    if (_isLoadingCode) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              color: AppTheme.slate400,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Chargement du code...',
            style: TextStyle(
              color: AppTheme.slate400,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    if (_loadError != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 15, color: AppTheme.red500),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.red500,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _fetchDeliveryCode,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Réessayer',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    }

    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_outline_rounded,
            size: 15, color: AppTheme.green600),
        SizedBox(width: 4),
        Text(
          'Code de validation chargé',
          style: TextStyle(
            color: AppTheme.green600,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      bottomNavigationBar: const AppBottomNav(),
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
                  color: AppTheme.green50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: AppTheme.successColor,
                  size: 56,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Colis livré !',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: widget.parcel.trackingNumber,
                      style: AppTheme.mono(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(
                      text:
                          ' a bien été remis à ${widget.parcel.receiverName.isEmpty ? 'son destinataire' : widget.parcel.receiverName}.',
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.amber50,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Text(
                  '+150 pts crédités',
                  style: AppTheme.mono(
                    color: AppTheme.amber700,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DeliveryProofScreen(parcel: widget.parcel),
                    ),
                  );
                },
                icon: const Icon(Icons.photo_camera_rounded),
                label: const Text('Ajouter une preuve'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Retour à l’accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeliveryProofScreen extends StatefulWidget {
  final Parcel parcel;

  const DeliveryProofScreen({super.key, required this.parcel});

  @override
  State<DeliveryProofScreen> createState() => _DeliveryProofScreenState();
}

class _DeliveryProofScreenState extends State<DeliveryProofScreen> {
  final _picker = ImagePicker();
  final _noteController = TextEditingController();
  XFile? _photo;
  bool _signed = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
    );
    if (photo == null) return;
    setState(() => _photo = photo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Preuve de livraison'),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      bottomNavigationBar: const AppBottomNav(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.green50,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_rounded, color: AppTheme.green700),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Colis remis · PIN destinataire validé',
                    style: TextStyle(
                      color: AppTheme.green700,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SectionLabel('Photo du colis remis'),
          const SizedBox(height: 10),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            children: [
              _PhotoTile(photo: _photo),
              _AddPhotoTile(onTap: _pickPhoto),
            ],
          ),
          const SizedBox(height: 18),
          _SectionLabel('Signature du destinataire'),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _signed = true),
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: _signed ? AppTheme.primary : AppTheme.slate300,
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _signed ? widget.parcel.receiverName : 'Touchez pour signer',
                style: TextStyle(
                  color: _signed ? AppTheme.primary : AppTheme.slate400,
                  fontSize: _signed ? 34 : 14,
                  fontFamily: _signed ? 'cursive' : null,
                  fontWeight: _signed ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _noteController,
            minLines: 3,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Remarque (optionnel)',
              hintText: 'Ex : remis au gardien',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Valider la preuve'),
          ),
        ],
      ),
    );
  }
}

class _OtpBoxes extends StatelessWidget {
  final String value;

  const _OtpBoxes({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final hasValue = value.length > index;
        return Container(
          width: 52,
          height: 58,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: hasValue ? AppTheme.primary : AppTheme.slate200,
              width: hasValue ? 2 : 1,
            ),
            boxShadow: AppTheme.softShadow(alpha: 0.03),
          ),
          child: Text(
            hasValue ? value[index] : '',
            style: AppTheme.mono(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      }),
    );
  }
}

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onKey;

  const _Keypad({required this.onKey});

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final key = keys[index];
        if (key.isEmpty) return const SizedBox.shrink();

        return OutlinedButton(
          onPressed: () => onKey(key),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.cardColor,
            foregroundColor: AppTheme.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              side: const BorderSide(color: AppTheme.slate200),
            ),
          ),
          child: key == 'del'
              ? const Icon(Icons.backspace_outlined)
              : Text(
                  key,
                  style: AppTheme.mono(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final XFile? photo;

  const _PhotoTile({required this.photo});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: photo == null
          ? const Icon(Icons.image_rounded, size: 44, color: AppTheme.slate400)
          : Image.file(File(photo!.path), fit: BoxFit.cover),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddPhotoTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.teal100, width: 1.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_rounded, color: AppTheme.primary, size: 32),
            SizedBox(height: 6),
            Text(
              'Ajouter',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
