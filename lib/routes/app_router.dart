import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/advertisement.dart';
import '../models/garage.dart';
import '../models/parcel.dart';
import '../providers/auth_provider.dart';
import '../screens/accueil/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/settings/notification_preferences_screen.dart';
import '../screens/super-admin/brevo_config_screen.dart';
import '../screens/super-admin/paydunya_config_screen.dart';
import '../screens/super-admin/broadcasts_page.dart';
import '../screens/super-admin/assistances_screen.dart';
import '../screens/super-admin/expenses_screen.dart';
import '../screens/super-admin/identity_verifications_screen.dart';
import '../screens/auth/register_page.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/dashboard/notifications/notifications_screen.dart';
import '../screens/dashboard/support_admin_dashboard.dart';
import '../screens/dashboard/support_commercial_dashboard.dart';
import '../screens/dashboard/support_technique_dashboard.dart';
import '../screens/driver/garage_screen.dart';
import '../screens/driver/historique_screen.dart';
import '../screens/driver/mes_annonces_screen.dart';
import '../screens/driver/parametres_screen.dart';
import '../screens/driver/points_screen.dart';
import '../screens/driver/itinerary_map_screen.dart';
import '../screens/driver/revenus_screen.dart';
import '../screens/driver/vehicle_documents_screen.dart';
import '../screens/garage_admin/garage_admin_drivers_screen.dart';
import '../screens/garage_admin/garage_admin_parcel_detail.dart';
import '../screens/garage_admin/garage_assignations_screen.dart';
import '../screens/garage_admin/garage_colis_screen.dart';
import '../screens/garage_admin/garage_rapports_screen.dart';
import '../screens/help/help_screen.dart';
import '../screens/legal/mentions_legales_page.dart';
import '../screens/legal/conditions_transport_page.dart';
import '../screens/legal/confidentialite_page.dart';
import '../screens/legal/cgu_page.dart';
import '../screens/legal/a_propos_page.dart';
import '../screens/legal/contact_page.dart';
import '../screens/legal/paiement_page.dart';
import '../screens/legal/remboursement_page.dart';
import '../screens/legal/reclamations_page.dart';
import '../screens/legal/colis_interdits_page.dart';
import '../screens/parcel/ads/advertisement_detail_screen.dart';
import '../screens/parcel/ads/advertisements_screen.dart';
import '../screens/parcel/new_parcel_wizard_screen.dart';
import '../screens/parcel/trip_detail_screen.dart';
import '../screens/super-admin/colis_management_screen.dart';
import '../screens/super-admin/chauffeurs_management_screen.dart';
import '../screens/parcel/confirm_delivery_screen.dart';
import '../screens/parcel/free_parcels_screen.dart';
import '../screens/parcel/offres_recues_screen.dart';
import '../screens/parcel/parcel_detail_screen.dart';
import '../screens/parcel/track_parcel_screen.dart';
import '../screens/payment/payment_status_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/shared/messages_screen.dart';
import '../screens/shared/support_chat_screen.dart';
import '../screens/shared/admin_support_screen.dart';
import '../screens/client/client_libre_service_screen.dart';
import '../screens/super-admin/admin_parametres_screen.dart';
import '../screens/super-admin/classement_screen.dart';
import '../screens/super-admin/commission_config_screen.dart';
import '../screens/super-admin/driver_detail_screen.dart';
import '../screens/super-admin/finance_dashboard_screen.dart';
import '../screens/super-admin/garage_drivers_screen.dart';
import '../screens/super-admin/garages_management_screen.dart';
import '../screens/super-admin/cash_declarations_screen.dart';
import '../screens/super-admin/payments_screen.dart';
import '../screens/super-admin/payment_notifications_screen.dart';
import '../screens/super-admin/reputation_dashboard_screen.dart';
import '../screens/super-admin/score_detail_screen.dart';
import '../screens/super-admin/scores_screen.dart';
import '../screens/super-admin/stats_screen.dart';
import '../screens/super-admin/users_management_screen.dart';
import '../screens/super-admin/zones_management_screen.dart';
import '../screens/super-admin/wallet_detail_screen.dart';
import '../screens/super-admin/wallets_screen.dart';
import '../screens/super-admin/withdrawals_screen.dart';
import '../screens/wallet/wallet_screen.dart';
import '../services/auth_notifier.dart';
import '../services/api_service.dart';

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
        final isLanding = location == '/' || location == '/landing';
        final isHelp = location == '/help';
        final isPaymentReturn =
            location == '/payment-status' || location == '/payment-status.php';
        final isSplash = location == '/splash';
        final isLegal = location.startsWith('/a-propos') ||
            location.startsWith('/contact') ||
            location.startsWith('/mentions-legales') ||
            location.startsWith('/confidentialite') ||
            location.startsWith('/cgu') ||
            location.startsWith('/conditions-transport') ||
            location.startsWith('/paiement') ||
            location.startsWith('/remboursement') ||
            location.startsWith('/reclamations') ||
            location.startsWith('/colis-interdits');
        final isPublic = isLogin ||
            isRegister ||
            isTrack ||
            isLanding ||
            isHelp ||
            isPaymentReturn ||
            isLegal;

        if (isSplash) {
          if (authState.isLoading) return null;
          return authState.isAuthenticated ? '/dashboard' : '/landing';
        }

        if (authState.isLoading) return null;
        if (!authState.isAuthenticated && !isPublic) return '/login';
        if (authState.isAuthenticated && (isLogin || isRegister))
          return '/dashboard';

        // Garde par rôle (aligné sur RequireRole du web) :
        // chaque espace est réservé à son rôle, sinon retour au dashboard.
        if (authState.isAuthenticated) {
          final user = authState.user;
          if (user != null) {
            if (location.startsWith('/admin') && !user.isSuperAdmin) {
              return '/dashboard';
            }
            if (location.startsWith('/garage') &&
                !user.isAdmin &&
                !user.isSuperAdmin) {
              return '/dashboard';
            }
            if (location.startsWith('/driver') && !user.isDriver) {
              return '/dashboard';
            }
            if (location.startsWith('/client') && !user.isClient) {
              return '/dashboard';
            }
            // Espaces support : chaque métier ne voit que le sien, le super
            // admin conserve un accès transverse.
            if (location.startsWith('/support-tech') &&
                !user.isSupportTechnique &&
                !user.isSuperAdmin) {
              return '/dashboard';
            }
            if (location.startsWith('/support-com') &&
                !user.isSupportCommercial &&
                !user.isSuperAdmin) {
              return '/dashboard';
            }
            // Espace support transverse : les trois rôles support et le super
            // admin, comme le `RequireRole` de `/support-admin` côté web.
            if (location.startsWith('/support-admin') &&
                !user.isSupport &&
                !user.isSuperAdmin) {
              return '/dashboard';
            }
          }
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/landing',
          name: 'landing',
          builder: (context, state) => const OnboardingScreen(),
        ),
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
          builder: (context, state) => RegisterPage(
            initialRole: state.uri.queryParameters['role'] ?? 'client',
          ),
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
          path: '/parcel/new',
          name: 'new-parcel',
          builder: (context, state) => const NewParcelWizardScreen(),
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
          path: '/trip/:tripId',
          name: 'trip-detail',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is Advertisement) {
              return TripDetailScreen(trip: extra);
            }
            return _AdvertisementLoader(
              advertisementId: state.pathParameters['tripId'] ?? '',
              builder: (trip) => TripDetailScreen(trip: trip),
            );
          },
        ),

        GoRoute(
          path: '/confirm-delivery',
          name: 'confirm-delivery',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is Parcel) return ConfirmDeliveryScreen(parcel: extra);
            return _ParcelLoader(
              parcelId: state.uri.queryParameters['parcelId'] ?? '',
              builder: (parcel) => ConfirmDeliveryScreen(parcel: parcel),
            );
          },
        ),
        GoRoute(
          path: '/confirm-delivery/:parcelId',
          name: 'confirm-delivery-by-id',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is Parcel) return ConfirmDeliveryScreen(parcel: extra);
            return _ParcelLoader(
              parcelId: state.pathParameters['parcelId'] ?? '',
              builder: (parcel) => ConfirmDeliveryScreen(parcel: parcel),
            );
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
            final garages = garagesRaw?.whereType<Garage>().toList();
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
          path: '/driver/historique',
          name: 'driver-historique',
          builder: (context, state) => const DriverHistoriqueScreen(),
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
          path: '/settings/notifications',
          name: 'notification-preferences',
          builder: (context, state) => const NotificationPreferencesScreen(),
        ),
        GoRoute(
          path: '/help',
          name: 'help',
          builder: (context, state) => const HelpScreen(),
        ),
        GoRoute(
          path: '/payment-status',
          name: 'payment-status',
          builder: (context, state) => PaymentStatusScreen(
            status: PaymentReturnStatus.fromQuery(
              state.uri.queryParameters['payment'],
            ),
          ),
        ),
        GoRoute(
          path: '/payment-status.php',
          name: 'payment-status-legacy',
          builder: (context, state) => PaymentStatusScreen(
            status: PaymentReturnStatus.fromQuery(
              state.uri.queryParameters['payment'],
            ),
          ),
        ),
        GoRoute(
          path: '/support',
          name: 'support',
          builder: (context, state) => const SupportChatScreen(),
        ),
        GoRoute(
            path: '/a-propos',
            name: 'a-propos',
            builder: (context, state) => const AProposPage()),
        GoRoute(
            path: '/contact',
            name: 'contact',
            builder: (context, state) => const ContactPage()),
        GoRoute(
            path: '/mentions-legales',
            name: 'mentions-legales',
            builder: (context, state) => const MentionsLegalesPage()),
        GoRoute(
            path: '/confidentialite',
            name: 'confidentialite',
            builder: (context, state) => const ConfidentialitePage()),
        GoRoute(
            path: '/cgu',
            name: 'cgu',
            builder: (context, state) => const CGUPage()),
        GoRoute(
            path: '/conditions-transport',
            name: 'conditions-transport',
            builder: (context, state) => const ConditionsTransportPage()),
        GoRoute(
            path: '/paiement',
            name: 'paiement',
            builder: (context, state) => const PaiementPage()),
        GoRoute(
            path: '/remboursement',
            name: 'remboursement',
            builder: (context, state) => const RemboursementPage()),
        GoRoute(
            path: '/reclamations',
            name: 'reclamations',
            builder: (context, state) => const ReclamationsPage()),
        GoRoute(
            path: '/colis-interdits',
            name: 'colis-interdits',
            builder: (context, state) => const ColisInterditsPage()),
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),

        // Gestion du support (aligné sur le web) : garde par préfixe de rôle
        // — /admin → super-admin, /garage → admin ou super-admin.
        GoRoute(
          path: '/admin/support',
          name: 'admin-support',
          builder: (context, state) => const AdminSupportScreen(),
        ),
        GoRoute(
          path: '/garage/support',
          name: 'garage-support',
          builder: (context, state) => const AdminSupportScreen(),
        ),

        // --- Support technique ---
        // La file de tickets est la vraie messagerie de support (API existante) ;
        // les autres entrées ouvrent le dashboard sur l'onglet correspondant.
        GoRoute(
          path: '/support-tech/tickets',
          name: 'support-tech-tickets',
          builder: (context, state) => const AdminSupportScreen(),
        ),
        GoRoute(
          path: '/support-tech/incidents',
          name: 'support-tech-incidents',
          builder: (context, state) =>
              const SupportTechniqueDashboard(initialTab: 2),
        ),
        // Journal des assistances : le support codifie lui-même l'assistance
        // qu'il vient de rendre. Même écran que côté super admin, exposé sous le
        // préfixe du métier pour rester compatible avec la garde par rôle.
        GoRoute(
          path: '/support-tech/assistances',
          name: 'support-tech-assistances',
          builder: (context, state) => const AssistancesScreen(),
        ),

        // --- Support commercial ---
        GoRoute(
          path: '/support-com/leads',
          name: 'support-com-leads',
          builder: (context, state) =>
              const SupportCommercialDashboard(initialTab: 1),
        ),
        GoRoute(
          path: '/support-com/coverage',
          name: 'support-com-coverage',
          builder: (context, state) =>
              const SupportCommercialDashboard(initialTab: 2),
        ),
        GoRoute(
          path: '/support-com/assistances',
          name: 'support-com-assistances',
          builder: (context, state) => const AssistancesScreen(),
        ),

        // --- Espace support transverse ---
        // Aligné sur SUPPORT_NAV du web (`/support-admin`) : ouvert aux trois
        // rôles support et au super admin. Les écrans sont ceux du super admin,
        // exposés sous ce préfixe pour que la garde de rôle les laisse passer
        // sans ouvrir tout `/admin`.
        GoRoute(
          path: '/support-admin',
          name: 'support-admin',
          builder: (context, state) => const SupportAdminDashboard(),
        ),
        GoRoute(
          path: '/support-admin/conversations',
          name: 'support-admin-conversations',
          builder: (context, state) => const AdminSupportScreen(),
        ),
        GoRoute(
          path: '/support-admin/assistances',
          name: 'support-admin-assistances',
          builder: (context, state) => const AssistancesScreen(),
        ),
        GoRoute(
          path: '/support-admin/colis',
          name: 'support-admin-colis',
          builder: (context, state) => const ColisManagementScreen(),
        ),
        GoRoute(
          path: '/support-admin/chauffeurs',
          name: 'support-admin-chauffeurs',
          builder: (context, state) => const ChauffeursManagementScreen(),
        ),
        GoRoute(
          path: '/support-admin/users',
          name: 'support-admin-users',
          builder: (context, state) => const UsersManagementScreen(),
        ),
        GoRoute(
          path: '/support-admin/profil',
          name: 'support-admin-profil',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/support-admin/notifications',
          name: 'support-admin-notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),

        GoRoute(
          path: '/garage/assignments',
          name: 'garage-assignments',
          builder: (context, state) => const GarageAssignationsScreen(),
        ),
        GoRoute(
          path: '/garage/colis',
          name: 'garage-colis',
          builder: (context, state) => const GarageColisScreen(),
        ),
        GoRoute(
          path: '/garage/parcel/:parcelId',
          name: 'garage-parcel-detail',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is Parcel) {
              return GarageAdminParcelDetailScreen(parcel: extra);
            }
            return _ParcelLoader(
              parcelId: state.pathParameters['parcelId'] ?? '',
              builder: (parcel) =>
                  GarageAdminParcelDetailScreen(parcel: parcel),
            );
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
          path: '/admin/colis',
          name: 'admin-colis',
          builder: (context, state) => const ColisManagementScreen(),
        ),
        GoRoute(
          path: '/admin/chauffeurs',
          name: 'admin-chauffeurs',
          builder: (context, state) => const ChauffeursManagementScreen(),
        ),
        GoRoute(
          path: '/admin/garages',
          name: 'admin-garages',
          builder: (context, state) => const GaragesManagementScreen(),
        ),
        GoRoute(
          path: '/admin/zones',
          name: 'admin-zones',
          builder: (context, state) => const ZonesManagementScreen(),
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
            final garageId = state.uri.queryParameters['garageId'] ?? '';
            return _GarageLoader(garageId: garageId);
          },
        ),
        GoRoute(
          path: '/admin/garages/:garageId/drivers',
          name: 'admin-garage-drivers-by-id',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is Garage) return GarageDriversScreen(garage: extra);
            return _GarageLoader(
              garageId: state.pathParameters['garageId'] ?? '',
            );
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
          path: '/admin/payments-cash',
          name: 'admin-payments-cash',
          builder: (context, state) => const CashDeclarationsScreen(),
        ),
        GoRoute(
          path: '/admin/withdrawals',
          name: 'admin-withdrawals',
          builder: (context, state) => const WithdrawalsScreen(),
        ),
        GoRoute(
          path: '/admin/payments-notifications',
          name: 'admin-payments-notifications',
          builder: (context, state) => const PaymentNotificationsScreen(),
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
        GoRoute(
          path: '/admin/notifications/brevo',
          name: 'admin-brevo-config',
          builder: (context, state) => const BrevoConfigScreen(),
        ),
        GoRoute(
          path: '/admin/payments/paydunya',
          name: 'admin-paydunya-config',
          builder: (context, state) => const PaydunyaConfigScreen(),
        ),
        GoRoute(
          path: '/admin/broadcasts',
          name: 'admin-broadcasts',
          builder: (context, state) => const BroadcastsPage(),
        ),
        GoRoute(
          path: '/admin/assistances',
          name: 'admin-assistances',
          builder: (context, state) => const AssistancesScreen(),
        ),
        GoRoute(
          path: '/admin/expenses',
          name: 'admin-expenses',
          builder: (context, state) => const ExpensesScreen(),
        ),
        GoRoute(
          path: '/admin/verifications',
          name: 'admin-verifications',
          builder: (context, state) => const IdentityVerificationsScreen(),
        ),
      ],
    );
  }
}

class _ParcelLoader extends StatefulWidget {
  final String parcelId;
  final Widget Function(Parcel parcel) builder;

  const _ParcelLoader({required this.parcelId, required this.builder});

  @override
  State<_ParcelLoader> createState() => _ParcelLoaderState();
}

class _ParcelLoaderState extends State<_ParcelLoader> {
  late Future<Parcel?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.parcelId.isEmpty
        ? Future<Parcel?>.value()
        : ApiService().getParcelById(widget.parcelId);
  }

  @override
  Widget build(BuildContext context) {
    return _ResourceLoader<Parcel>(
      future: _future,
      notFoundMessage: 'Colis introuvable',
      builder: widget.builder,
    );
  }
}

class _AdvertisementLoader extends StatefulWidget {
  final String advertisementId;
  final Widget Function(Advertisement advertisement) builder;

  const _AdvertisementLoader({
    required this.advertisementId,
    required this.builder,
  });

  @override
  State<_AdvertisementLoader> createState() => _AdvertisementLoaderState();
}

class _AdvertisementLoaderState extends State<_AdvertisementLoader> {
  late Future<Advertisement?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Advertisement?> _load() async {
    if (widget.advertisementId.isEmpty) return null;
    final json =
        await ApiService().getAdvertisementDetail(widget.advertisementId);
    return json.isEmpty ? null : Advertisement.fromJson(json);
  }

  @override
  Widget build(BuildContext context) {
    return _ResourceLoader<Advertisement>(
      future: _future,
      notFoundMessage: 'Voyage introuvable',
      builder: widget.builder,
    );
  }
}

class _GarageLoader extends StatefulWidget {
  final String garageId;

  const _GarageLoader({required this.garageId});

  @override
  State<_GarageLoader> createState() => _GarageLoaderState();
}

class _GarageLoaderState extends State<_GarageLoader> {
  late Future<Garage?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Garage?> _load() async {
    if (widget.garageId.isEmpty) return null;
    final garages = await ApiService().getAllGaragesSuperAdmin();
    for (final garage in garages) {
      if (garage.id == widget.garageId) return garage;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _ResourceLoader<Garage>(
      future: _future,
      notFoundMessage: 'Zone introuvable',
      builder: (garage) => GarageDriversScreen(garage: garage),
    );
  }
}

/// État commun des deep-links qui doivent reconstruire un objet métier depuis
/// son identifiant lorsque `GoRouter.extra` n'existe pas (application relancée,
/// notification push ou lien externe).
class _ResourceLoader<T> extends StatelessWidget {
  final Future<T?> future;
  final String notFoundMessage;
  final Widget Function(T value) builder;

  const _ResourceLoader({
    required this.future,
    required this.notFoundMessage,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(notFoundMessage)),
          );
        }
        return builder(snapshot.data as T);
      },
    );
  }
}
