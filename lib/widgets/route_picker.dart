// mobile/lib/widgets/route_picker.dart
// Widget combiné Départ → Arrivée avec sélecteurs recherchables,
// pillule visuelle de trajet, et bouton d'inversion.

import 'package:flutter/material.dart';
import 'package:procolis/theme/fonts.dart';

import '../models/garage.dart';
import '../theme/app_theme.dart';
import 'garage_picker.dart';
import 'pc_components.dart';

class RoutePicker extends StatefulWidget {
  final List<Garage> garages;
  final Garage? initialDeparture;
  final Garage? initialArrival;
  final ValueChanged<Garage?> onDepartureChanged;
  final ValueChanged<Garage?> onArrivalChanged;
  final bool showLabels;
  final String departureLabel;
  final String arrivalLabel;

  const RoutePicker({
    super.key,
    required this.garages,
    this.initialDeparture,
    this.initialArrival,
    required this.onDepartureChanged,
    required this.onArrivalChanged,
    this.showLabels = true,
    this.departureLabel = 'Départ',
    this.arrivalLabel = 'Arrivée',
  });

  @override
  State<RoutePicker> createState() => _RoutePickerState();
}

class _RoutePickerState extends State<RoutePicker> {
  Garage? _departure;
  Garage? _arrival;

  @override
  void initState() {
    super.initState();
    _departure = widget.initialDeparture;
    _arrival = widget.initialArrival;
  }

  @override
  void didUpdateWidget(RoutePicker old) {
    super.didUpdateWidget(old);
    if (old.initialDeparture != widget.initialDeparture) {
      _departure = widget.initialDeparture;
    }
    if (old.initialArrival != widget.initialArrival) {
      _arrival = widget.initialArrival;
    }
  }

  Future<void> _pickDeparture() async {
    final result = await GaragePickerSheet.show(
      context: context,
      garages: widget.garages,
      exclude: _arrival,
      initial: _departure,
      title: 'Zone de départ',
    );
    if (result != null) {
      setState(() => _departure = result);
      widget.onDepartureChanged(result);
    }
  }

  Future<void> _pickArrival() async {
    final result = await GaragePickerSheet.show(
      context: context,
      garages: widget.garages,
      exclude: _departure,
      initial: _arrival,
      title: "Zone d'arrivée",
    );
    if (result != null) {
      setState(() => _arrival = result);
      widget.onArrivalChanged(result);
    }
  }

  void _swap() {
    final tmp = _departure;
    setState(() {
      _departure = _arrival;
      _arrival = tmp;
    });
    widget.onDepartureChanged(_departure);
    widget.onArrivalChanged(_arrival);
  }

  String _name(Garage? g) => g?.name ?? '—';
  String _city(Garage? g) => g?.city ?? '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildGarageCard(
              label: widget.showLabels ? widget.departureLabel : null,
              garage: _departure,
              onTap: _pickDeparture,
              icon: Icons.trip_origin_rounded,
            )),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: GestureDetector(
                onTap: _swap,
                child: Container(
                  width: 36, height: 36,
                  margin: EdgeInsets.only(top: widget.showLabels ? 18 : 0),
                  decoration: BoxDecoration(
                    color: AppTheme.slate100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swap_horiz_rounded,
                      size: 20, color: AppTheme.slate500),
                ),
              ),
            ),
            Expanded(child: _buildGarageCard(
              label: widget.showLabels ? widget.arrivalLabel : null,
              garage: _arrival,
              onTap: _pickArrival,
              icon: Icons.pin_drop_rounded,
            )),
          ],
        ),
        if (_departure != null && _arrival != null) ...[
          const SizedBox(height: 10),
          _RoutePill(from: _city(_departure), to: _city(_arrival)),
        ],
      ],
    );
  }

  Widget _buildGarageCard({
    String? label,
    required Garage? garage,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label,
              style: AppFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppTheme.slate700)),
          const SizedBox(height: 6),
        ],
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.slate50,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: garage != null ? AppTheme.teal100 : AppTheme.slate200,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18,
                    color: garage != null ? AppTheme.primary : AppTheme.slate400),
                const SizedBox(width: 8),
                Expanded(
                  child: garage != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(garage.name,
                                style: AppFonts.manrope(
                                    fontSize: 13.5, fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary),
                                overflow: TextOverflow.ellipsis),
                            if (_city(garage).isNotEmpty)
                              Text(_city(garage),
                                  style: AppFonts.manrope(
                                      fontSize: 11.5,
                                      color: AppTheme.textSecondary)),
                          ],
                        )
                      : Text('Choisir...',
                          style: AppFonts.manrope(
                              fontSize: 13, color: AppTheme.slate400)),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.slate400, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutePill extends StatelessWidget {
  final String from;
  final String to;

  const _RoutePill({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.teal50,
        border: Border.all(color: AppTheme.teal100),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(from,
                textAlign: TextAlign.center,
                style: AppFonts.plusJakartaSans(
                    fontSize: 13.5, fontWeight: FontWeight.w700,
                    color: AppTheme.teal700)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: const Icon(Icons.local_shipping_rounded,
                size: 18, color: AppTheme.teal500),
          ),
          Container(
            width: 48, height: 1,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.teal400, style: BorderStyle.solid),
              ),
            ),
          ),
          Expanded(
            child: Text(to,
                textAlign: TextAlign.center,
                style: AppFonts.plusJakartaSans(
                    fontSize: 13.5, fontWeight: FontWeight.w700,
                    color: AppTheme.teal700)),
          ),
        ],
      ),
    );
  }
}
