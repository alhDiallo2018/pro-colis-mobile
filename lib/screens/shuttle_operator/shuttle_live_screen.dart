// lib/screens/shuttle_operator/shuttle_live_screen.dart
//
// SCP-007 — Supervision temps réel des trajets actifs sur les lignes de
// l'opérateur. Auto-refresh 15s (Timer périodique) + invalidate du provider.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/shuttle_operator_provider.dart';
import '../../services/api/shuttle_operator_api.dart';

class ShuttleLiveScreen extends ConsumerStatefulWidget {
  const ShuttleLiveScreen({super.key});

  @override
  ConsumerState<ShuttleLiveScreen> createState() => _ShuttleLiveScreenState();
}

class _ShuttleLiveScreenState extends ConsumerState<ShuttleLiveScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) ref.invalidate(shuttleLiveProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shuttleLiveProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervision'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(shuttleLiveProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(shuttleLiveProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _Error(message: err.toString(), onRetry: () => ref.invalidate(shuttleLiveProvider)),
          data: (snapshot) => _LiveBody(snapshot: snapshot),
        ),
      ),
    );
  }
}

class _LiveBody extends StatelessWidget {
  final ShuttleLiveSnapshot snapshot;

  const _LiveBody({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _FleetRow(fleet: snapshot.fleet, activeCount: snapshot.activeJourneys.length),
        const SizedBox(height: 12),
        if (snapshot.activeJourneys.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Aucun trajet actif en ce moment.', textAlign: TextAlign.center)),
          )
        else
          ...snapshot.activeJourneys.map((j) => _JourneyCard(journey: j)),
        const SizedBox(height: 12),
        Text(
          'Dernière mise à jour : ${_formatTime(snapshot.generatedAt)}',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FleetRow extends StatelessWidget {
  final ShuttleLiveFleet fleet;
  final int activeCount;

  const _FleetRow({required this.fleet, required this.activeCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Pill(label: 'Trajets', value: '$activeCount', color: Colors.teal, icon: Icons.directions_bus)),
        const SizedBox(width: 8),
        Expanded(child: _Pill(label: 'Dispo', value: '${fleet.available}', color: Colors.green, icon: Icons.check_circle)),
        const SizedBox(width: 8),
        Expanded(child: _Pill(label: 'Mainten.', value: '${fleet.maintenance}', color: Colors.orange, icon: Icons.build)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _Pill({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  final ShuttleLiveJourney journey;

  const _JourneyCard({required this.journey});

  @override
  Widget build(BuildContext context) {
    final pickupLate = journey.pickupTotal > 0 && journey.pickupDone < journey.pickupTotal;
    final dropoffPartial = journey.dropoffTotal > 0 && journey.dropoffDone < journey.dropoffTotal;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(journey.lineNumber ?? '?')),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(journey.lineName ?? 'Ligne inconnue', style: Theme.of(context).textTheme.titleMedium),
                      Text(journey.driverName ?? '—', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (journey.position == null)
                  const Icon(Icons.gps_off, color: Colors.red),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _InfoChip(
                  icon: Icons.location_on_outlined,
                  text: 'Arrêts ${journey.stopsReached}/${journey.stopsTotal}' +
                      (journey.nextStopLabel != null ? ' · prochain ${journey.nextStopLabel}' : ''),
                ),
                _InfoChip(
                  icon: Icons.upload_outlined,
                  text: 'Pickup ${journey.pickupDone}/${journey.pickupTotal}',
                  color: pickupLate ? Colors.orange : Colors.green,
                ),
                _InfoChip(
                  icon: Icons.download_outlined,
                  text: 'Remise ${journey.dropoffDone}/${journey.dropoffTotal}',
                  color: dropoffPartial ? Colors.orange : (journey.dropoffTotal == 0 ? null : Colors.green),
                ),
              ],
            ),
            if (journey.position != null) ...[
              const SizedBox(height: 8),
              Text(
                'GPS : ${journey.position!.latitude.toStringAsFixed(4)}, ${journey.position!.longitude.toStringAsFixed(4)} '
                '· ±${journey.position!.accuracyMeters.round()} m '
                '· ${_formatTime(journey.position!.capturedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _InfoChip({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final effective = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: effective.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: effective),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: effective, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _Error({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime date) {
  final local = date.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
}
