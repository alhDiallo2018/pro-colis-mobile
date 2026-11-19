// lib/screens/dashboard/shuttle_operator_dashboard.dart
//
// SCP-007 — Dashboard mobile de l'opérateur navette. Navigation par onglets
// vers les 5 espaces : overview, supervision (live), lignes, flotte, horaires.

import 'package:flutter/material.dart';

import '../shuttle_operator/shuttle_lines_screen.dart';
import '../shuttle_operator/shuttle_live_screen.dart';
import '../shuttle_operator/shuttle_overview_screen.dart';
import '../shuttle_operator/shuttle_schedules_screen.dart';
import '../shuttle_operator/shuttle_vehicles_screen.dart';

class ShuttleOperatorDashboard extends StatefulWidget {
  const ShuttleOperatorDashboard({super.key});

  @override
  State<ShuttleOperatorDashboard> createState() => _ShuttleOperatorDashboardState();
}

class _ShuttleOperatorDashboardState extends State<ShuttleOperatorDashboard> {
  int _index = 0;

  static const _pages = <Widget>[
    ShuttleOverviewScreen(),
    ShuttleLiveScreen(),
    ShuttleLinesScreen(),
    ShuttleVehiclesScreen(),
    ShuttleSchedulesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.radar_outlined), selectedIcon: Icon(Icons.radar), label: 'Live'),
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: 'Lignes'),
          NavigationDestination(icon: Icon(Icons.directions_bus_outlined), selectedIcon: Icon(Icons.directions_bus), label: 'Flotte'),
          NavigationDestination(icon: Icon(Icons.schedule_outlined), selectedIcon: Icon(Icons.schedule), label: 'Horaires'),
        ],
      ),
    );
  }
}
