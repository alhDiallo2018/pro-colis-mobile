import 'package:flutter/material.dart';
import 'package:procolis/theme/fonts.dart';
import '../models/parcel.dart';
import '../theme/app_theme.dart';

enum StepStatus { done, current, todo }

class StepperStepData {
  final String label;
  final String? time;
  final StepStatus status;
  final IconData? icon;
  final String? note;

  const StepperStepData({
    required this.label,
    this.time,
    this.status = StepStatus.todo,
    this.icon,
    this.note,
  });
}

class StatusTimeline extends StatelessWidget {
  final List<StepperStepData> steps;
  final double dotSize;
  final double lineWidth;

  const StatusTimeline({
    super.key,
    required this.steps,
    this.dotSize = 30,
    this.lineWidth = 2,
  });

  /// Build from parcel events, computing done/current/todo automatically.
  factory StatusTimeline.fromEvents(
    List<ParcelEvent> events, {
    ParcelStatus? currentStatus,
  }) {
    final sorted = List<ParcelEvent>.from(events)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final steps = <StepperStepData>[];
    for (int i = 0; i < sorted.length; i++) {
      final evt = sorted[i];
      final isLast = i == sorted.length - 1;
      final matchesCurrent = currentStatus != null && evt.status == currentStatus;

      StepStatus status;
      if (matchesCurrent && !isLast) {
        status = StepStatus.current;
      } else if (isLast && currentStatus != null && evt.status == currentStatus) {
        status = StepStatus.current;
      } else {
        status = StepStatus.done;
      }

      steps.add(StepperStepData(
        label: _statusLabel(evt.status),
        time: _formatDateTime(evt.timestamp),
        status: status,
        icon: _statusIcon(evt.status),
        note: evt.description.isNotEmpty ? evt.description : null,
      ));
    }

    return StatusTimeline(steps: steps);
  }

  static String _statusLabel(ParcelStatus status) {
    switch (status) {
      case ParcelStatus.pending: return 'En attente';
      case ParcelStatus.free: return 'Annonce publiée';
      case ParcelStatus.confirmed: return 'Confirmé';
      case ParcelStatus.pickedUp: return 'Ramassé';
      case ParcelStatus.inTransit: return 'En transit';
      case ParcelStatus.arrived: return 'Arrivé';
      case ParcelStatus.outForDelivery: return 'En livraison';
      case ParcelStatus.delivered: return 'Livré';
      case ParcelStatus.cancelled: return 'Annulé';
    }
  }

  static IconData _statusIcon(ParcelStatus status) {
    switch (status) {
      case ParcelStatus.pending: return Icons.hourglass_empty;
      case ParcelStatus.free: return Icons.gavel;
      case ParcelStatus.confirmed: return Icons.check_circle;
      case ParcelStatus.pickedUp: return Icons.inventory_2;
      case ParcelStatus.inTransit: return Icons.local_shipping;
      case ParcelStatus.arrived: return Icons.location_on;
      case ParcelStatus.outForDelivery: return Icons.delivery_dining;
      case ParcelStatus.delivered: return Icons.check_circle;
      case ParcelStatus.cancelled: return Icons.cancel;
    }
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (i) {
        final step = steps[i];
        final isLast = i == steps.length - 1;
        final isDone = step.status == StepStatus.done;
        final isCurrent = step.status == StepStatus.current;

        final dotBg = isDone
            ? AppTheme.successColor
            : isCurrent
                ? AppTheme.primary
                : AppTheme.cardColor;
        final dotBorder = isDone
            ? AppTheme.successColor
            : isCurrent
                ? AppTheme.primary
                : AppTheme.slate300;
        final lineColor =
            isDone ? AppTheme.green300 : AppTheme.slate200;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: dotSize + 8,
                child: Column(
                  children: [
                    Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        color: dotBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: dotBorder, width: 2),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: (isDone || isCurrent)
                          ? Icon(
                              step.icon ?? (isDone ? Icons.check : Icons.local_shipping),
                              size: 17,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: lineWidth,
                          color: lineColor,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              step.label,
                              style: AppFonts.plusJakartaSans(
                                fontSize: 14.5,
                                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                                color: (isDone || isCurrent)
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          if (step.time != null)
                            Text(
                              step.time!,
                              style: AppTheme.mono(
                                fontSize: 11.5,
                                color: AppTheme.slate400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      if (step.note != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          step.note!,
                          style: AppFonts.manrope(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
