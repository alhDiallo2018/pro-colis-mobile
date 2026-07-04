import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/parcel.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';

class AdminStatsScreen extends ConsumerStatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  ConsumerState<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends ConsumerState<AdminStatsScreen> {
  // ==================== CONSTANTES DE COULEUR (THÈME BLEU/BLANC) ====================
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color lightBlue = Color(0xFFE3F2FD);
  static const Color darkBlue = Color(0xFF0D47A1);
  static const Color backgroundColor = Color(0xFFF5F8FA);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A2332);
  static const Color textSecondary = Color(0xFF546E7A);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color warningColor = Color(0xFFF57C00);
  static const Color errorColor = Color(0xFFC62828);

  final ApiService _apiService = ApiService();
  List<User> _users = [];
  List<Parcel> _parcels = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await _apiService.getAllUsersSuperAdmin();
      final parcels = await _apiService.getAllParcelsSuperAdmin();

      setState(() {
        _users = users;
        _parcels = parcels;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  int get _totalUsers => _users.length;
  int get _totalDrivers => _users.where((u) => u.role == UserRole.driver).length;
  int get _totalParcels => _parcels.length;
  int get _parcelsInTransit => _parcels.where((p) => 
    p.status == ParcelStatus.inTransit || 
    p.status == ParcelStatus.outForDelivery ||
    p.status == ParcelStatus.pickedUp
  ).length;
  int get _parcelsDelivered => _parcels.where((p) => p.status == ParcelStatus.delivered).length;
  double get _totalRevenue => _parcels.where((p) => p.status == ParcelStatus.delivered).fold(0.0, (sum, p) => sum + (p.price ?? 0));

  List<Map<String, dynamic>> get _recentActivities {
    final activities = <Map<String, dynamic>>[];
    
    // Ajouter les 5 derniers utilisateurs
    for (var user in _users.reversed.take(5)) {
      activities.add({
        'type': 'user',
        'title': 'Nouvel utilisateur',
        'description': 'Inscription de ${user.fullName}',
        'time': user.createdAt,
        'icon': Icons.person_add,
        'color': primaryBlue,
      });
    }
    
    // Ajouter les 5 derniers colis
    for (var parcel in _parcels.reversed.take(5)) {
      final statusText = parcel.status.label;
      activities.add({
        'type': 'parcel',
        'title': 'Colis $statusText',
        'description': '${parcel.trackingNumber} - ${parcel.receiverName}',
        'time': parcel.createdAt,
        'icon': parcel.status == ParcelStatus.delivered ? Icons.check_circle : Icons.local_shipping,
        'color': parcel.status == ParcelStatus.delivered ? successColor : warningColor,
      });
    }
    
    // Trier par date décroissante
    activities.sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));
    
    // Retourner les 10 plus récentes
    return activities.take(10).toList();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Tableau de bord',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: textPrimary,
          ),
        ),
        backgroundColor: cardColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryBlue),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: primaryBlue,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                ),
              )
            : _error != null
                ? _buildErrorState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Cartes de statistiques - Première ligne
                        Row(
                          children: [
                            _StatsCard(
                              title: 'Utilisateurs',
                              value: _totalUsers.toString(),
                              icon: Icons.people,
                              color: primaryBlue,
                            ),
                            const SizedBox(width: 12),
                            _StatsCard(
                              title: 'Chauffeurs',
                              value: _totalDrivers.toString(),
                              icon: Icons.delivery_dining,
                              color: successColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Cartes de statistiques - Deuxième ligne
                        Row(
                          children: [
                            _StatsCard(
                              title: 'Colis',
                              value: _totalParcels.toString(),
                              icon: Icons.inventory,
                              color: warningColor,
                            ),
                            const SizedBox(width: 12),
                            _StatsCard(
                              title: 'Colis livrés',
                              value: _parcelsDelivered.toString(),
                              icon: Icons.check_circle,
                              color: successColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Cartes de statistiques - Troisième ligne
                        Row(
                          children: [
                            _StatsCard(
                              title: 'En transit',
                              value: _parcelsInTransit.toString(),
                              icon: Icons.local_shipping,
                              color: Colors.purple,
                            ),
                            const SizedBox(width: 12),
                            _StatsCard(
                              title: 'Revenus',
                              value: '${_totalRevenue.toInt()} FCFA',
                              icon: Icons.attach_money,
                              color: primaryBlue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Graphique des revenus (version simplifiée)
                        Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity( 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Aperçu des colis',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildParcelStatusChart(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Dernières activités
                        Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity( 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Dernières activités',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_recentActivities.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Center(
                                      child: Text(
                                        'Aucune activité récente',
                                        style: TextStyle(
                                          color: textSecondary,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  ..._recentActivities.map((activity) => Column(
                                    children: [
                                      ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: (activity['color'] as Color).withOpacity( 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            activity['icon'] as IconData,
                                            color: activity['color'] as Color,
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(
                                          activity['title'] as String,
                                          style: const TextStyle(
                                            color: textPrimary,
                                          ),
                                        ),
                                        subtitle: Text(
                                          activity['description'] as String,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textSecondary,
                                          ),
                                        ),
                                        trailing: Text(
                                          _formatDate(activity['time'] as DateTime),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ),
                                      const Divider(height: 1),
                                    ],
                                  )),
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

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity( 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: errorColor.withOpacity( 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: errorColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParcelStatusChart() {
    final Map<String, int> statusCount = {
      'En attente': _parcels.where((p) => p.status == ParcelStatus.pending).length,
      'Confirmés': _parcels.where((p) => p.status == ParcelStatus.confirmed).length,
      'Ramassés': _parcels.where((p) => p.status == ParcelStatus.pickedUp).length,
      'En transit': _parcels.where((p) => p.status == ParcelStatus.inTransit).length,
      'Arrivés': _parcels.where((p) => p.status == ParcelStatus.arrived).length,
      'En livraison': _parcels.where((p) => p.status == ParcelStatus.outForDelivery).length,
      'Livrés': _parcels.where((p) => p.status == ParcelStatus.delivered).length,
      'Annulés': _parcels.where((p) => p.status == ParcelStatus.cancelled).length,
    };

    final colors = {
      'En attente': Colors.grey,
      'Confirmés': primaryBlue,
      'Ramassés': Colors.teal,
      'En transit': warningColor,
      'Arrivés': Colors.purple,
      'En livraison': Colors.deepOrange,
      'Livrés': successColor,
      'Annulés': errorColor,
    };

    final entries = statusCount.entries.where((e) => e.value > 0).toList();
    
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'Aucun colis',
          style: TextStyle(
            color: textSecondary,
          ),
        ),
      );
    }

    return Column(
      children: entries.map((entry) {
        final percentage = _totalParcels > 0 ? entry.value / _totalParcels : 0.0;
        final color = colors[entry.key] ?? Colors.grey;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 13,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${entry.value} colis (${(percentage * 100).toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey.shade200,
                color: color,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity( 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity( 0.15),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity( 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}