// lib/screens/parcel/trip_detail_screen.dart
//
// Détail d'une annonce de trajet publiée par un chauffeur (ressource
// /advertisements). Accessible depuis l'onglet "Voyages" du libre service.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/advertisement.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_bottom_nav.dart';
import '../shared/messages_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final Advertisement trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Advertisement get _trip => widget.trip;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _call() async {
    final phone = _trip.driverPhone;
    if (phone == null || phone.isEmpty) {
      _snack('Numéro du chauffeur indisponible');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) _snack('Appel impossible');
  }

  void _contact() {
    if (_trip.driverId.isEmpty) {
      _snack('Chauffeur indisponible pour la messagerie');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessagesScreen(
          initialPeerId: _trip.driverId,
          initialPeerName: _trip.driverName,
        ),
      ),
    );
  }

  Future<void> _toggleAudio(String url) async {
    try {
      if (_playing) {
        await _audioPlayer.stop();
        if (mounted) setState(() => _playing = false);
        return;
      }
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      _snack('Lecture audio impossible');
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = _trip.departureCity?.isNotEmpty == true ? _trip.departureCity! : '—';
    final to = _trip.arrivalCity?.isNotEmpty == true ? _trip.arrivalCity! : '—';
    final driver = _trip.driverName.isNotEmpty ? _trip.driverName : 'Chauffeur';
    final description = _trip.description?.trim() ?? '';
    final audioUrl = _trip.audioUrl;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Détail du voyage'),
        shape: const Border(bottom: BorderSide(color: AppTheme.slate200)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          _routeCard(from, to, _trip.departureAt),
          const SizedBox(height: 16),
          _infoCard(),
          const SizedBox(height: 16),
          _driverCard(driver),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 16),
            _notesCard(description),
          ],
          if (audioUrl != null && audioUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            _audioCard(audioUrl),
          ],
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_actionBar(), const AppBottomNav()],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: child,
      );

  Widget _routeCard(String from, String to, DateTime? date) => _card(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_shipping_rounded,
                  color: AppTheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$from  →  $to',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  if (date != null) ...[
                    const SizedBox(height: 4),
                    Text('Départ : ${_formatDate(date)}',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );

  Widget _infoCard() => _card(
        child: Row(
          children: [
            Expanded(
                child: _stat(Icons.scale_rounded, 'Capacité',
                    _trip.formattedWeight)),
            Container(width: 1, height: 40, color: AppTheme.slate200),
            Expanded(
                child: _stat(Icons.payments_rounded, 'Prix proposé',
                    _trip.formattedPrice)),
          ],
        ),
      );

  Widget _stat(IconData icon, String label, String value) => Column(
        children: [
          Icon(icon, color: AppTheme.primary, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      );

  Widget _driverCard(String driver) => _card(
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primary,
              child: Text(driver[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driver,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  const Text('Chauffeur',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _notesCard(String description) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informations du voyage',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(description,
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: AppTheme.textPrimary)),
          ],
        ),
      );

  Widget _audioCard(String url) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Note vocale du chauffeur',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _toggleAudio(url),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.slate50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                        _playing
                            ? Icons.stop_circle_rounded
                            : Icons.play_circle_fill_rounded,
                        color: AppTheme.primary),
                    const SizedBox(width: 10),
                    const Text('Écouter la note vocale',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _actionBar() => SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _call,
                icon: const Icon(Icons.call_rounded),
                label: const Text('Appeler'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _contact,
                icon: const Icon(Icons.chat_rounded),
                label: const Text('Contacter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      );

  static const _months = [
    'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
    'juil', 'août', 'sep', 'oct', 'nov', 'déc'
  ];

  String _formatDate(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_months[d.month - 1]} ${d.year} à $hh:$mm';
  }
}
