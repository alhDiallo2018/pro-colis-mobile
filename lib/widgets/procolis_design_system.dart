import 'package:flutter/material.dart';

import '../models/parcel.dart';
import '../theme/app_theme.dart';

class ProcolisCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// `null` : couleur de carte par défaut, résolue selon le thème courant.
  final Color? color;

  const ProcolisCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: AppTheme.softShadow(alpha: 0.06),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: card,
      ),
    );
  }
}

class ProcolisStatusBadge extends StatelessWidget {
  final ParcelStatus status;

  const ProcolisStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.statusColors(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: colors.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label.toUpperCase(),
            style: TextStyle(
              color: colors.foreground,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class ProcolisGradientHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ProcolisGradientHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 52, 16, 22),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      child: child,
    );
  }
}

class ProcolisQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? backgroundColor;

  const ProcolisQuickAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: backgroundColor ?? AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, color: iconColor ?? AppTheme.primary, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.slate700,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ProcolisSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const ProcolisSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

class ProcolisTabItem {
  final String label;
  final IconData icon;
  final int? badge;

  const ProcolisTabItem({
    required this.label,
    required this.icon,
    this.badge,
  });
}

/// Navigation commune : le bouton médian garde sa destination et gagne une
/// silhouette surélevée. Les barres à quatre onglets restent équilibrées.
class ProcolisTabBar extends StatelessWidget {
  final List<ProcolisTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ProcolisTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final middle =
        items.length >= 3 && items.length.isOdd ? items.length ~/ 2 : null;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    // La partie surélevée reste DANS les limites de la barre : elle reçoit
    // aussi les taps sur son bord supérieur, sans empiéter sur le contenu.
    final labelHeight = MediaQuery.textScalerOf(context).scale(11) * 1.25;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SizedBox(
        height: 88 + labelHeight,
        child: Stack(
          children: [
            Positioned(
              top: 18,
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppTheme.slate200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: AppTheme.isDark ? 0.22 : 0.07),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      flex: i == middle ? 12 : 10,
                      child: _ProcolisTabButton(
                        item: items[i],
                        active: i == currentIndex,
                        prominent: i == middle,
                        duration: duration,
                        onTap: () => onTap(i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcolisTabButton extends StatelessWidget {
  final ProcolisTabItem item;
  final bool active;
  final bool prominent;
  final Duration duration;
  final VoidCallback onTap;

  const _ProcolisTabButton({
    required this.item,
    required this.active,
    required this.prominent,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.teal600 : AppTheme.slate500;
    final count = item.badge ?? 0;
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      value: count > 0 ? '$count éléments' : null,
      onTap: onTap,
      child: Tooltip(
        message: item.label,
        excludeFromSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            excludeFromSemantics: true,
            borderRadius: BorderRadius.circular(24),
            child: ExcludeSemantics(
              child: Column(
                children: [
                  SizedBox(
                    height: 64,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          if (prominent)
                            _centralIcon()
                          else
                            AnimatedContainer(
                              duration: duration,
                              curve: Curves.easeOutCubic,
                              width: 48,
                              height: 36,
                              decoration: BoxDecoration(
                                color: active
                                    ? AppTheme.teal50
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: AnimatedScale(
                                scale: active ? 1.08 : 1,
                                duration: duration,
                                child: Icon(item.icon, size: 23, color: color),
                              ),
                            ),
                          if (count > 0)
                            Positioned(
                              top: prominent ? 2 : -3,
                              right: prominent ? 0 : -2,
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 19),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.red400,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppTheme.cardColor, width: 2),
                                ),
                                child: Text(
                                  count > 99 ? '99+' : '$count',
                                  textAlign: TextAlign.center,
                                  // Le compte complet reste accessible au lecteur
                                  // d'écran, même si la pastille est plafonnée.
                                  textScaler: TextScaler.noScaling,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    height: 1,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedDefaultTextStyle(
                    duration: duration,
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: color,
                          fontSize: 11,
                          height: 1.25,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w600,
                        ),
                    child: Text(item.label,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(height: 5),
                  AnimatedContainer(
                    duration: duration,
                    width: active ? 16 : 4,
                    height: 3,
                    decoration: BoxDecoration(
                      color: active
                          ? (prominent ? AppTheme.secondary : AppTheme.primary)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _centralIcon() {
    return Container(
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.cardColor,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF018982).withValues(alpha: 0.24),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: AnimatedScale(
        scale: active ? 1.08 : 1,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.brandGradient,
          ),
          child: Icon(item.icon, size: 30, color: Colors.white),
        ),
      ),
    );
  }
}
