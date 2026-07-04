// mobile/lib/screens/garage_admin/garage_assignations_screen.dart
// Écran d'assignation chauffeurs→colis - aligné Web

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/parcel.dart';
import '../../models/user.dart';
import '../../providers/parcel_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class GarageAssignationsScreen extends ConsumerStatefulWidget {
  const GarageAssignationsScreen({super.key});

  @override
  ConsumerState<GarageAssignationsScreen> createState() =>
      _GarageAssignationsScreenState();
}

class _GarageAssignationsScreenState
    extends ConsumerState<GarageAssignationsScreen> {
  final ApiService _apiService = ApiService();
  List<Parcel> _pendingParcels = [];
  List<User> _drivers = [];
  bool _isLoading = true;
  Map<String, String?> _selectedDriver = {}; // parcelId → driverId
  Map<String, bool> _assigningState = {}; // parcelId → isAssigning

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final parcels = await _apiService.getGarageParcels();
      final pendingParcels = parcels
          .where((p) =>
              p.status == ParcelStatus.pending ||
              p.status == ParcelStatus.confirmed ||
              p.status == ParcelStatus.free)
          .toList();

      final drivers = await _apiService.getGarageDrivers();

      if (mounted) {
        setState(() {
          _pendingParcels = pendingParcels;
          _drivers = drivers
              .where((d) => d.driverStatus == DriverStatus.available)
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _assignDriver(String parcelId, String driverId) async {
    setState(() => _assigningState[parcelId] = true);
    try {
      final result = await _apiService.assignDriverToParcel(parcelId, driverId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['success'] == true
                ? 'Chauffeur assigné avec succès'
                : result['message'] ?? 'Erreur'),
            backgroundColor:
                result['success'] == true ? AppTheme.green600 : AppTheme.error,
          ),
        );
        if (result['success'] == true) await _loadData();
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _assigningState[parcelId] = false);
    }
  }

  Future<void> _bulkAssign() async {
    final assignments = <Map<String, String>>[];
    for (final parcel in _pendingParcels) {
      final driverId = _selectedDriver[parcel.id];
      if (driverId != null) {
        assignments.add({'parcelId': parcel.id, 'driverId': driverId});
      }
    }
    if (assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Aucune assignation à effectuer'),
            backgroundColor: AppTheme.warningColor),
      );
      return;
    }

    for (final a in assignments) {
      await _apiService.assignDriverToParcel(
          a['parcelId']!, a['driverId']!);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Assignation en masse effectuée'),
          backgroundColor: AppTheme.green600),
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Assignations',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          if (_pendingParcels.isNotEmpty)
            TextButton(
              onPressed: _bulkAssign,
              child: const Text('Tout assigner',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  // Stats bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: AppTheme.teal50,
                    child: Row(
                      children: [
                        _statBox('${_pendingParcels.length}', 'Colis en attente'),
                        const SizedBox(width: 16),
                        _statBox('${_drivers.length}', 'Chauffeurs dispo.'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _pendingParcels.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 64, color: AppTheme.green500),
                                const SizedBox(height: 16),
                                const Text('Tous les colis sont assignés !',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: AppTheme.textSecondary)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _pendingParcels.length,
                            itemBuilder: (context, index) {
                              final parcel = _pendingParcels[index];
                              final isAssigning =
                                  _assigningState[parcel.id] ?? false;
                              final selectedId = _selectedDriver[parcel.id];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.slate200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('#${parcel.trackingNumber}',
                                            style: AppTheme.mono(
                                                fontSize: 13,
                                                color: AppTheme.primary)),
                                        const Spacer(),
                                        _statusBadge(parcel.status.value),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${parcel.departureGarageName} → ${parcel.arrivalGarageName ?? 'À définir'}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary),
                                    ),
                                    Text(
                                      '${parcel.senderName} • ${parcel.formattedWeight}',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.slate500),
                                    ),
                                    const SizedBox(height: 12),
                                    if (parcel.driverId != null)
                                      Row(
                                        children: [
                                          const Icon(Icons.person,
                                              size: 16,
                                              color: AppTheme.green600),
                                          const SizedBox(width: 4),
                                          Text(
                                              parcel.driverName ?? 'Assigné',
                                              style: const TextStyle(
                                                  color: AppTheme.green600,
                                                  fontWeight: FontWeight.w500)),
                                        ],
                                      )
                                    else ...[
                                      const Text('Assigner un chauffeur :',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppTheme.textSecondary)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child:
                                                DropdownButtonFormField<String>(
                                              isExpanded: true,
                                              value: selectedId,
                                              hint: const Text('Choisir...'),
                                              decoration: InputDecoration(
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 10),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                                isDense: true,
                                              ),
                                              items: _drivers.map((d) {
                                                return DropdownMenuItem(
                                                  value: d.id,
                                                  child: Text(
                                                    d.fullName,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 13),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (v) {
                                                setState(() =>
                                                    _selectedDriver[
                                                        parcel.id] = v);
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: (isAssigning ||
                                                    selectedId == null)
                                                ? null
                                                : () => _assignDriver(
                                                    parcel.id, selectedId!),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                            ),
                                            child: isAssigning
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white))
                                                : const Text('Assigner'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statusBadge(String status) {
    final colors = AppTheme.statusColors(ParcelStatus.fromString(status));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(ParcelStatus.fromString(status).label,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.foreground)),
    );
  }

  Widget _statBox(String value, String label) {
    return Expanded(
      child: Row(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.teal700)),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(color: AppTheme.teal600, fontSize: 13)),
        ],
      ),
    );
  }
}
