import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/garage.dart';
import '../models/parcel.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_page.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/dashboard/notifications/notifications_screen.dart';
import '../screens/driver/garage_screen.dart';
import '../screens/driver/mes_annonces_screen.dart';
import '../screens/driver/parametres_screen.dart';
import '../screens/driver/points_screen.dart';
import '../screens/driver/itinerary_map_screen.dart';
import '../screens/driver/revenus_screen.dart';
import '../screens/driver/vehicle_documents_screen.dart';
import '../screens/garage_admin/garage_admin_drivers_screen.dart';
import '../screens/garage_admin/garage_admin_parcel_detail.dart';
import '../screens/garage_admin/garage_assignations_screen.dart';
import '../screens/garage_admin/garage_rapports_screen.dart';
import '../screens/help/help_screen.dart';
import '../screens/parcel/ads/advertisement_detail_screen.dart';
import '../screens/parcel/ads/advertisements_screen.dart';
import '../screens/parcel/confirm_delivery_screen.dart';
import '../screens/parcel/free_parcels_screen.dart';
import '../screens/parcel/offres_recues_screen.dart';
import '../screens/parcel/parcel_detail_screen.dart';
import '../screens/parcel/track_parcel_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/shared/messages_screen.dart';
import '../screens/client/client_libre_service_screen.dart';
import '../screens/super-admin/add_points_dialog.dart';
import '../screens/super-admin/remove_points_dialog.dart';
import '../screens/super-admin/admin_parametres_screen.dart';
import '../screens/super-admin/classement_screen.dart';
import '../screens/super-admin/commission_config_screen.dart';
import '../screens/super-admin/driver_detail_screen.dart';
import '../screens/super-admin/finance_dashboard_screen.dart';
import '../screens/super-admin/garage_drivers_screen.dart';
import '../screens/super-admin/garages_management_screen.dart';
import '../screens/super-admin/payments_screen.dart';
import '../screens/super-admin/reputation_dashboard_screen.dart';
import '../screens/super-admin/score_detail_screen.dart';
import '../screens/super-admin/scores_screen.dart';
import '../screens/super-admin/stats_screen.dart';
import '../screens/super-admin/users_management_screen.dart';
import '../screens/super-admin/wallet_detail_screen.dart';
import '../screens/super-admin/wallets_screen.dart';
import '../screens/wallet/wallet_screen.dart';
import '../services/auth_notifier.dart';

class AppRouter {
  static GoRouter router() {
    return GoRouter(
      refreshListenable: authRefreshNotifier,
      initialLocation: '/splash',
      redirect: (context, state) {
        final container = ProviderScope.containerOf(context);
        final authState = container.read(authProvider);
        final location = state.matchedLocation;
        final isLogin = location == '/login';
        final isRegister = location == '/register';
        final isTrack = location.startsWith('/track');
        final isSplash = location == '/splash';
        final isPublic = isLogin || isRegister || isTrack;

        if (isSplash) {
          if (authState.isLoading) return null;
          return authState.isAuthenticated ? '/dashboard' : '/login';
        }

        if (authState.isLoading) return null;
        if (!authState.isAuthenticated && !isPublic) return '/login';
        if (authState.isAuthenticated && (isLogin || isRegister)) return '/dashboard';
        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          name: 'register',
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: '/track',
          name: 'track',
          builder: (context, state) => const TrackParcelScreen(),
          routes: [
            GoRoute(
              path: ':trackingNumber',
              builder: (context, state) => TrackParcelScreen(
                trackingNumber: state.pathParameters['trackingNumber'],
              ),
            ),
          ],
        ),

        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),

        GoRoute(
          path: '/parcel/:parcelId',
          name: 'parcel-detail',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is Parcel) return ParcelDetailScreen(parcel: extra);
            final parcelId = state.pathParameters['parcelId'] ?? '';
            return ParcelDetailScreen(parcelId: parcelId);
          },
        ),


        GoRoute(
          path: '/free-parcels',
          name: 'free-parcels',
          builder: (context, state) => const FreeParcelsScreen(),
        ),

        GoRoute(
          path: '/client/libre',
          name: 'client-libre',
          builder: (context, state) => const ClientLibreServiceScreen(),
        ),
        GoRoute(
          path: '/client/offres',
          name: 'client-offres',
          builder: (context, state) => const OffresRecuesScreen(),
        ),

        GoRoute(
          path: '/advertisements',
          name: 'advertisements',
          builder: (context, state) => const AdvertisementsScreen(),
        ),

        GoRoute(
          path: '/advertisement/:adId',
          name: 'advertisement-detail',
          builder: (context, state) {
            final extra = state.extra;
            final adId = state.pathParameters['adId'];
            if (extra is Parcel) {
              return AdvertisementDetailScreen(
                parcel: extra,
                adId: adId ?? extra.id,
              );
            }
            if (adId != null && adId.isNotEmpty) {
              return AdvertisementDetailScreen(adId: adId);
            }
            return const AdvertisementsScreen();
          },
        ),

        GoRoute(
          path: '/confirm-delivery',
          name: 'confirm-delivery',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is Parcel) return ConfirmDeliveryScreen(parcel: extra);
            return const Scaffold(body: Center(child: Text('Aucun colis spécifié')));
          },
        ),

        GoRoute(
          path: '/driver/my-ads',
          name: 'driver-my-ads',
          builder: (context, state) => const DriverMesAnnoncesScreen(),
        ),
        GoRoute(
          path: '/driver/revenue',
          name: 'driver-revenue',
          builder: (context, state) => const DriverRevenusScreen(),
        ),
        GoRoute(
          path: '/driver/points',
          name: 'driver-points',
          builder: (context, state) => const DriverPointsScreen(),
        ),
        GoRoute(
          path: '/driver/settings',
          name: 'driver-settings',
          builder: (context, state) => const DriverParametresScreen(),
        ),
        GoRoute(
          path: '/driver/itinerary',
          name: 'driver-itinerary',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final garagesRaw = extra?['garages'] as List<dynamic>?;
            final garages = garagesRaw
                ?.whereType<Garage>()
                .toList();
            return ItineraryMapScreen(
              departureLat: extra?['departureLat'] as double?,
              departureLng: extra?['departureLng'] as double?,
              arrivalLat: extra?['arrivalLat'] as double?,
              arrivalLng: extra?['arrivalLng'] as double?,
              departureName: extra?['departureName']?.toString() ?? '',
              arrivalName: extra?['arrivalName']?.toString() ?? '',
              garages: garages,
            );
          },
        ),
        GoRoute(
          path: '/driver/garage',
          name: 'driver-garage',
          builder: (context, state) => const DriverGarageScreen(),
        ),
        GoRoute(
          path: '/driver/documents',
          name: 'driver-documents',
          builder: (context, state) => const VehicleDocumentsScreen(),
        ),

        GoRoute(
          path: '/messages',
          name: 'messages',
          builder: (context, state) => const MessagesScreen(),
        ),
        GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/wallet',
          name: 'wallet',
          builder: (context, state) => const WalletScreen(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/help',
          name: 'help',
          builder: (context, state) => const HelpScreen(),
        ),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),

        GoRoute(
          path: '/garage/assignments',
          name: 'garage-assignments',
          builder: (context, state) => const GarageAssignationsScreen(),
        ),
        GoRoute(
          path: '/garage/parcel/:parcelId',
          name: 'garage-parcel-detail',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is Parcel) return GarageAdminParcelDetailScreen(parcel: extra);
            return const Scaffold(body: Center(child: Text('Colis introuvable')));
          },
        ),
        GoRoute(
          path: '/garage/drivers',
          name: 'garage-drivers',
          builder: (context, state) => const GarageAdminDriversScreen(),
        ),
        GoRoute(
          path: '/garage/rapports',
          name: 'garage-rapports',
          builder: (context, state) => const GarageRapportsScreen(),
        ),

        GoRoute(
          path: '/admin/users',
          name: 'admin-users',
          builder: (context, state) => const UsersManagementScreen(),
        ),
        GoRoute(
          path: '/admin/garages',
          name: 'admin-garages',
          builder: (context, state) => const GaragesManagementScreen(),
        ),
        GoRoute(
          path: '/admin/stats',
          name: 'admin-stats',
          builder: (context, state) => const AdminStatsScreen(),
        ),
        GoRoute(
          path: '/admin/parametres',
          name: 'admin-parametres',
          builder: (context, state) => const AdminParametresScreen(),
        ),
        GoRoute(
          path: '/admin/garage/drivers',
          name: 'admin-garage-drivers',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is Garage) return GarageDriversScreen(garage: extra);
            return const Scaffold(body: Center(child: Text('Garage introuvable')));
          },
        ),

        // --- Super Admin Finance ---
        GoRoute(
          path: '/admin/finance',
          name: 'admin-finance',
          builder: (context, state) => const FinanceDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/wallets',
          name: 'admin-wallets',
          builder: (context, state) => const WalletsScreen(),
        ),
        GoRoute(
          path: '/admin/wallets/:userId',
          name: 'admin-wallet-detail',
          builder: (context, state) {
            final userId = state.pathParameters['userId'] ?? '';
            return WalletDetailScreen(userId: userId);
          },
        ),
        GoRoute(
          path: '/admin/payments',
          name: 'admin-payments',
          builder: (context, state) => const PaymentsScreen(),
        ),
        GoRoute(
          path: '/admin/commissions',
          name: 'admin-commissions',
          builder: (context, state) => const CommissionConfigScreen(),
        ),

        // --- Super Admin Reputation ---
        GoRoute(
          path: '/admin/reputation',
          name: 'admin-reputation',
          builder: (context, state) => const ReputationDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/scores',
          name: 'admin-scores',
          builder: (context, state) => const ScoresScreen(),
        ),
        GoRoute(
          path: '/admin/scores/:userId',
          name: 'admin-score-detail',
          builder: (context, state) {
            final userId = state.pathParameters['userId'] ?? '';
            return ScoreDetailScreen(userId: userId);
          },
        ),
        GoRoute(
          path: '/admin/classement',
          name: 'admin-classement',
          builder: (context, state) => const ClassementScreen(),
        ),
        GoRoute(
          path: '/admin/drivers/:userId',
          name: 'admin-driver-detail',
          builder: (context, state) {
            final userId = state.pathParameters['userId'] ?? '';
            return DriverDetailScreen(userId: userId);
          },
        ),
      ],
    );
  }
}
