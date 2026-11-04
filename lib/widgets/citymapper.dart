// ============================================================
// SENDPROCOLIS MOBILE — CITYMAPPER-INSPIRED WIDGETS
// Additive only : s'appuie sur AppTheme sans le modifier.
// Préfixe `Cm` pour isoler de l'existant.
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/fonts.dart';

/// Rayons & marges partagés — alignés sur le web (`.cm-radius-*`).
class CmTokens {
  static const double radiusHero = 28;
  static const double radiusCard = 20;
  static const double radiusTile = 18;
  static const double radiusChip = 14;

  /// Couleurs de tuile Citymapper (dégradés profonds + lisibles).
  static const Color tileEmerald1 = Color(0xFF12B36A);
  static const Color tileEmerald2 = Color(0xFF0FA958);
  static const Color tileAmber1 = Color(0xFFFDB534);
  static const Color tileAmber2 = Color(0xFFFCA202);
  static const Color tileRose1 = Color(0xFFF04A32);
  static const Color tileRose2 = Color(0xFFE5240F);
  static const Color tileIndigo1 = Color(0xFF5466D6);
  static const Color tileIndigo2 = Color(0xFF3949AB);
  static const Color tileCyan1 = Color(0xFF16AFBE);
  static const Color tileCyan2 = Color(0xFF0097A7);
  static const Color tileViolet1 = Color(0xFF8B5CF6);
  static const Color tileViolet2 = Color(0xFF6D28D9);

  static List<BoxShadow> shadowRaise() => [
        BoxShadow(
          color: AppTheme.tone(
            const Color(0xFF0B464F).withValues(alpha: 0.08),
            Colors.black.withValues(alpha: 0.45),
          ),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: AppTheme.tone(
            const Color(0xFF0B464F).withValues(alpha: 0.04),
            Colors.black.withValues(alpha: 0.30),
          ),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> shadowHero() => [
        BoxShadow(
          color: AppTheme.tone(
            const Color(0xFF0A3A43).withValues(alpha: 0.22),
            Colors.black.withValues(alpha: 0.60),
          ),
          blurRadius: 48,
          offset: const Offset(0, 20),
        ),
      ];

  static String greetingLabel() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Bonne nuit';
    if (h < 12) return 'Bonne matinée';
    if (h < 18) return 'Bon après-midi';
    return 'Bonne soirée';
  }
}

enum CmTileColor { emerald, amber, rose, indigo, cyan, violet, teal, slate }

/// ------------------------------------------------------------------
/// Hero d'accueil Citymapper : salutation + accroche + search button
/// ------------------------------------------------------------------
class CmHero extends StatelessWidget {
  final String eyebrow;
  final List<InlineSpan> greetingSpans;
  final String searchTitle;
  final String searchSub;
  final IconData searchIcon;
  final VoidCallback onSearchTap;

  const CmHero({
    super.key,
    required this.eyebrow,
    required this.greetingSpans,
    required this.searchTitle,
    required this.searchSub,
    this.searchIcon = Icons.near_me,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.teal700, AppTheme.deep700, const Color(0xFF0A3A43)],
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(CmTokens.radiusHero),
        boxShadow: CmTokens.shadowHero(),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -40,
            bottom: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.amber400.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  letterSpacing: 0.1 * 11.5,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  children: greetingSpans,
                  style: const TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    height: 1.1,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _CmHeroSearch(
                icon: searchIcon,
                title: searchTitle,
                sub: searchSub,
                onTap: onSearchTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CmHeroSearch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  const _CmHeroSearch({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(CmTokens.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CmTokens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.amber50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: AppTheme.amber600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, size: 22, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------------
/// Tuile d'action colorée (grid 2 ou 4 colonnes)
/// ------------------------------------------------------------------
class CmActionTile extends StatelessWidget {
  final CmTileColor color;
  final IconData icon;
  final String label;
  final String? sub;
  final int? badge;
  final VoidCallback onTap;

  const CmActionTile({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    this.sub,
    this.badge,
    required this.onTap,
  });

  LinearGradient _gradient() {
    switch (color) {
      case CmTileColor.emerald:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CmTokens.tileEmerald1, CmTokens.tileEmerald2],
        );
      case CmTileColor.amber:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CmTokens.tileAmber1, CmTokens.tileAmber2],
        );
      case CmTileColor.rose:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CmTokens.tileRose1, CmTokens.tileRose2],
        );
      case CmTileColor.indigo:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CmTokens.tileIndigo1, CmTokens.tileIndigo2],
        );
      case CmTileColor.cyan:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CmTokens.tileCyan1, CmTokens.tileCyan2],
        );
      case CmTileColor.violet:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CmTokens.tileViolet1, CmTokens.tileViolet2],
        );
      case CmTileColor.teal:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.teal500, AppTheme.teal700],
        );
      case CmTileColor.slate:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.slate600, AppTheme.slate800],
        );
    }
  }

  Color _fg() {
    return color == CmTileColor.amber ? AppTheme.amberOnFg : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final fg = _fg();
    final iconBg = color == CmTileColor.amber
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.22);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(CmTokens.radiusTile),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CmTokens.radiusTile),
        child: Container(
          height: 112,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: _gradient(),
            borderRadius: BorderRadius.circular(CmTokens.radiusTile),
            boxShadow: CmTokens.shadowRaise(),
          ),
          child: Stack(
            children: [
              if (badge != null && badge! > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$badge',
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: fg),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: fg,
                          height: 1.2,
                        ),
                      ),
                      if (sub != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            sub!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: fg.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------------
/// En-tête de page compact : titre + sous-titre + action optionnelle
/// ------------------------------------------------------------------
class CmPageHead extends StatelessWidget {
  final String title;
  final Widget? subtitle;
  final Widget? action;

  const CmPageHead({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  letterSpacing: -0.35,
                  color: AppTheme.textPrimary,
                  height: 1.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                  child: subtitle!,
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 12),
          action!,
        ],
      ],
    );
  }
}

/// ------------------------------------------------------------------
/// Stat cell compact pour un strip horizontal
/// ------------------------------------------------------------------
enum CmStatTone { teal, green, amber, rose, slate }

class CmStatPill extends StatelessWidget {
  final CmStatTone tone;
  final IconData icon;
  final String value;
  final String label;

  const CmStatPill({
    super.key,
    required this.tone,
    required this.icon,
    required this.value,
    required this.label,
  });

  (Color, Color) _colors() {
    switch (tone) {
      case CmStatTone.teal:
        return (AppTheme.teal50, AppTheme.teal600);
      case CmStatTone.green:
        return (AppTheme.green50, AppTheme.green700);
      case CmStatTone.amber:
        return (AppTheme.amber50, AppTheme.amber600);
      case CmStatTone.rose:
        return (AppTheme.red50, AppTheme.red500);
      case CmStatTone.slate:
        return (AppTheme.slate100, AppTheme.slate600);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(CmTokens.radiusChip),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppTheme.textPrimary,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------------
/// Carte "journey" avec rail Citymapper (départ → véhicule → arrivée)
/// ------------------------------------------------------------------
class CmJourneyStep {
  final String label;
  final String? sub;
  final bool isCurrent;
  final bool isDeparture;
  final bool isDestination;
  final IconData? vehicleIcon;

  const CmJourneyStep({
    required this.label,
    this.sub,
    this.isCurrent = false,
    this.isDeparture = false,
    this.isDestination = false,
    this.vehicleIcon,
  });
}

class CmJourneyCard extends StatelessWidget {
  final Widget? head;
  final List<CmJourneyStep> steps;
  final List<Widget>? actions;
  final Color? lineColor;

  const CmJourneyCard({
    super.key,
    this.head,
    required this.steps,
    this.actions,
    this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = lineColor ?? AppTheme.teal500;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(CmTokens.radiusCard),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: CmTokens.shadowRaise(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (head != null) ...[
            head!,
            const SizedBox(height: 14),
          ],
          _CmRouteRail(steps: steps, lineColor: color),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: actions!,
            ),
          ],
        ],
      ),
    );
  }
}

class _CmRouteRail extends StatelessWidget {
  final List<CmJourneyStep> steps;
  final Color lineColor;

  const _CmRouteRail({required this.steps, required this.lineColor});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rail (ligne colorée + nœuds alignés sur chaque step)
          SizedBox(
            width: 22,
            child: CustomPaint(
              painter: _CmRailPainter(
                steps: steps.length,
                lineColor: lineColor,
                vehicleIndex: steps.indexWhere((s) => s.isCurrent),
              ),
              child: Column(
                children: List.generate(steps.length, (i) {
                  final step = steps[i];
                  Widget node;
                  if (step.isCurrent && step.vehicleIcon != null) {
                    node = Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.teal700,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.cardColor,
                            blurRadius: 0,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(step.vehicleIcon,
                          size: 16, color: Colors.white),
                    );
                  } else {
                    final filled = step.isDeparture;
                    node = Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: filled ? lineColor : AppTheme.cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: lineColor, width: 3),
                      ),
                    );
                  }
                  return Expanded(
                    child: Center(child: node),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(steps.length, (i) {
                final step = steps[i];
                return Padding(
                  padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        step.label,
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontWeight: FontWeight.w800,
                          fontSize: step.isCurrent ? 14 : 16,
                          color: step.isCurrent
                              ? AppTheme.textBody
                              : AppTheme.textPrimary,
                          height: 1.25,
                        ),
                      ),
                      if (step.sub != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          step.sub!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _CmRailPainter extends CustomPainter {
  final int steps;
  final Color lineColor;
  final int vehicleIndex;

  _CmRailPainter({
    required this.steps,
    required this.lineColor,
    required this.vehicleIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (steps < 2) return;
    final paint = Paint()
      ..color = lineColor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final cx = size.width / 2;
    final top = size.height * (0.5 / steps);
    final bottom = size.height - top;
    canvas.drawLine(Offset(cx, top), Offset(cx, bottom), paint);
  }

  @override
  bool shouldRepaint(_CmRailPainter old) =>
      old.steps != steps ||
      old.lineColor != lineColor ||
      old.vehicleIndex != vehicleIndex;
}

/// ------------------------------------------------------------------
/// Filter chip Citymapper-style (pressed state)
/// ------------------------------------------------------------------
class CmFilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const CmFilterChip({
    super.key,
    required this.label,
    this.icon,
    this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppTheme.teal600 : AppTheme.cardColor;
    final fg = selected ? Colors.white : AppTheme.textSecondary;
    final border = selected ? AppTheme.teal600 : AppTheme.slate200;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: fg,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : AppTheme.slate100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: selected ? Colors.white : AppTheme.textBody,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------------
/// Bandeau origine → destination
/// ------------------------------------------------------------------
class CmOdBand extends StatelessWidget {
  final String departure;
  final String arrival;
  final IconData icon;

  const CmOdBand({
    super.key,
    required this.departure,
    required this.arrival,
    this.icon = Icons.local_shipping,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.teal50, AppTheme.cardColor],
        ),
        borderRadius: BorderRadius.circular(CmTokens.radiusCard),
        border: Border.all(color: AppTheme.teal100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DÉPART',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 0.08 * 10.5,
                    color: AppTheme.teal600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  departure,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: AppTheme.teal800,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.teal500,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'ARRIVÉE',
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    letterSpacing: 0.08 * 10.5,
                    color: AppTheme.teal600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  arrival,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: AppTheme.teal800,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------------
/// Ligne méta (icône + label + valeur)
/// ------------------------------------------------------------------
class CmMetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const CmMetaRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.slate200)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.slate400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------------
/// Carte code de réception (gradient teal + QR optionnel)
/// ------------------------------------------------------------------
class CmReceiveCode extends StatelessWidget {
  final String code;
  final String? description;
  final Widget? qr;

  const CmReceiveCode({
    super.key,
    required this.code,
    this.description,
    this.qr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.teal700, AppTheme.teal800],
        ),
        borderRadius: BorderRadius.circular(CmTokens.radiusCard),
        boxShadow: CmTokens.shadowRaise(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.verified_user, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Code de réception',
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        description!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                code,
                style: TextStyle(
                  fontFamily: AppFonts.monoFamily,
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                  letterSpacing: 0.22 * 28,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (qr != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: qr!),
            ),
          ],
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------------
/// Driver hero (avatar + nom + sous-texte + action à droite)
/// ------------------------------------------------------------------
class CmDriverHero extends StatelessWidget {
  final Widget avatar;
  final String name;
  final String? sub;
  final Widget? trailing;

  const CmDriverHero({
    super.key,
    required this.avatar,
    required this.name,
    this.sub,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(CmTokens.radiusCard),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: CmTokens.shadowRaise(),
      ),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.2,
                    color: AppTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------------
/// Pill (ETA / badge inline)
/// ------------------------------------------------------------------
class CmPill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? bg;
  final Color? fg;

  const CmPill({
    super.key,
    this.icon,
    required this.label,
    this.bg,
    this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final b = bg ?? AppTheme.amber50;
    final f = fg ?? AppTheme.amber700;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
      decoration: BoxDecoration(
        color: b,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: f),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: f,
            ),
          ),
        ],
      ),
    );
  }
}
