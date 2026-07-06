// lib/widgets/pc_components.dart
//
// Librairie de composants ProColis, portée depuis le design system fourni
// (tokens: Plus Jakarta Sans / Manrope / JetBrains Mono, teal #018982…).
// Préfixe `Pc` pour cohabiter avec les widgets existants pendant la refonte.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

// ============================================================
// Tokens partagés
// ============================================================

enum PcTone { neutral, primary, green, amber, red }

class _ToneChip {
  final Color bg;
  final Color fg;
  const _ToneChip(this.bg, this.fg);
}

_ToneChip _toneChip(PcTone tone) {
  switch (tone) {
    case PcTone.primary:
      return const _ToneChip(AppTheme.teal50, AppTheme.teal500);
    case PcTone.green:
      return const _ToneChip(AppTheme.green50, AppTheme.green700);
    case PcTone.amber:
      return const _ToneChip(AppTheme.amber50, AppTheme.amber600);
    case PcTone.red:
      return const _ToneChip(AppTheme.red50, AppTheme.red500);
    case PcTone.neutral:
      return const _ToneChip(AppTheme.slate100, AppTheme.slate500);
  }
}

TextStyle _display({
  double size = 15,
  FontWeight weight = FontWeight.w700,
  Color color = AppTheme.textPrimary,
  double? letterSpacing,
  double? height,
}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );

TextStyle _body({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = AppTheme.slate600,
  double? height,
}) =>
    GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );

// ============================================================
// PcButton
// ============================================================

enum PcButtonVariant { primary, secondary, ghost, danger, amber }

enum PcButtonSize { sm, md, lg }

class PcButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PcButtonVariant variant;
  final PcButtonSize size;
  final IconData? icon;
  final IconData? iconTrailing;
  final bool block;
  final bool loading;

  const PcButton(
    this.label, {
    super.key,
    this.onPressed,
    this.variant = PcButtonVariant.primary,
    this.size = PcButtonSize.md,
    this.icon,
    this.iconTrailing,
    this.block = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final ({double h, double px, double fs, double ic, double gap}) s =
        switch (size) {
      PcButtonSize.sm => (h: 36, px: 14, fs: 13, ic: 18, gap: 6),
      PcButtonSize.md => (h: 46, px: 18, fs: 15, ic: 20, gap: 8),
      PcButtonSize.lg => (h: 54, px: 22, fs: 16, ic: 22, gap: 8),
    };

    late Color bg, fg;
    Color? border;
    List<BoxShadow> shadow = const [];
    switch (variant) {
      case PcButtonVariant.primary:
        bg = AppTheme.primary;
        fg = Colors.white;
        shadow = AppTheme.brandShadow();
      case PcButtonVariant.amber:
        bg = AppTheme.amber400;
        fg = AppTheme.amberOnFg;
        shadow = AppTheme.amberShadow();
      case PcButtonVariant.secondary:
        bg = AppTheme.cardColor;
        fg = AppTheme.textPrimary;
        border = AppTheme.slate300;
        shadow = AppTheme.shadowXs();
      case PcButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppTheme.primary;
      case PcButtonVariant.danger:
        bg = AppTheme.red400;
        fg = Colors.white;
    }
    if (disabled && !loading) {
      bg = AppTheme.slate200;
      fg = AppTheme.slate400;
      border = null;
      shadow = const [];
    }

    Widget content;
    if (loading) {
      content = SizedBox(
        width: s.ic,
        height: s.ic,
        child: CircularProgressIndicator(strokeWidth: 2, color: fg),
      );
    } else {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: s.ic, color: fg),
            SizedBox(width: s.gap),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: _display(
                  size: s.fs, weight: FontWeight.w700, color: fg, letterSpacing: 0.1),
            ),
          ),
          if (iconTrailing != null) ...[
            SizedBox(width: s.gap),
            Icon(iconTrailing, size: s.ic, color: fg),
          ],
        ],
      );
    }

    return Semantics(
      button: true,
      enabled: !disabled,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            height: s.h,
            width: block ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: s.px),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: border != null ? Border.all(color: border) : null,
              boxShadow: shadow,
            ),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PcIconButton
// ============================================================

enum PcIconButtonVariant { ghost, solid, soft, danger }

class PcIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final PcIconButtonVariant variant;
  final PcButtonSize size;
  final bool round;
  final String? tooltip;

  const PcIconButton(
    this.icon, {
    super.key,
    this.onPressed,
    this.variant = PcIconButtonVariant.ghost,
    this.size = PcButtonSize.md,
    this.round = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final ({double d, double ic}) s = switch (size) {
      PcButtonSize.sm => (d: 34, ic: 18),
      PcButtonSize.md => (d: 44, ic: 22),
      PcButtonSize.lg => (d: 52, ic: 26),
    };
    late Color bg, fg;
    switch (variant) {
      case PcIconButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppTheme.slate500;
      case PcIconButtonVariant.solid:
        bg = AppTheme.primary;
        fg = Colors.white;
      case PcIconButtonVariant.soft:
        bg = AppTheme.teal50;
        fg = AppTheme.primary;
      case PcIconButtonVariant.danger:
        bg = AppTheme.red50;
        fg = AppTheme.red400;
    }
    final radius =
        round ? BorderRadius.circular(s.d) : BorderRadius.circular(AppTheme.radiusSm);
    final btn = Material(
      color: bg,
      borderRadius: radius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: SizedBox(
          width: s.d,
          height: s.d,
          child: Icon(icon, size: s.ic, color: fg),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

// ============================================================
// PcFab
// ============================================================

class PcFab extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onPressed;
  final bool amber;

  const PcFab({
    super.key,
    this.icon = Icons.add_rounded,
    this.label,
    this.onPressed,
    this.amber = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = amber ? AppTheme.amber400 : AppTheme.primary;
    final fg = amber ? AppTheme.amberOnFg : Colors.white;
    final shadow = amber ? AppTheme.amberShadow() : AppTheme.brandShadow();
    final radius = label != null
        ? BorderRadius.circular(999)
        : BorderRadius.circular(28);
    return Material(
      color: bg,
      borderRadius: radius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: Container(
          height: 56,
          width: label == null ? 56 : null,
          padding: label != null
              ? const EdgeInsets.only(left: 18, right: 22)
              : null,
          decoration: BoxDecoration(borderRadius: radius, boxShadow: shadow),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: fg),
              if (label != null) ...[
                const SizedBox(width: 8),
                Text(label!,
                    style: _display(size: 15, weight: FontWeight.w700, color: fg)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PcCard
// ============================================================

class PcCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accent;
  final Color color;
  final double radius;
  final List<BoxShadow>? shadow;

  const PcCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.accent,
    this.color = AppTheme.cardColor,
    this.radius = AppTheme.radiusMd,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: shadow,
        gradient: null,
      ),
      child: accent == null
          ? child
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: accent),
                const SizedBox(width: 12),
                Expanded(child: child),
              ],
            ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

// ============================================================
// PcStatBox
// ============================================================

class PcStatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final PcTone tone;

  const PcStatBox({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.tone = PcTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final chip = _toneChip(tone);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: AppTheme.shadowXs(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: chip.bg,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, size: 20, color: chip.fg),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: _display(size: 26, weight: FontWeight.w800, height: 1)),
          const SizedBox(height: 5),
          Text(label,
              style: _body(size: 13, weight: FontWeight.w500, color: AppTheme.slate500)),
        ],
      ),
    );
  }
}

// ============================================================
// PcBadge
// ============================================================

enum PcBadgeVariant { soft, solid }

class PcBadge extends StatelessWidget {
  final String label;
  final PcTone tone;
  final PcBadgeVariant variant;
  final IconData? icon;

  const PcBadge(
    this.label, {
    super.key,
    this.tone = PcTone.neutral,
    this.variant = PcBadgeVariant.soft,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    late Color bg, fg;
    if (variant == PcBadgeVariant.solid) {
      switch (tone) {
        case PcTone.primary:
          bg = AppTheme.primary;
          fg = Colors.white;
        case PcTone.green:
          bg = AppTheme.green600;
          fg = Colors.white;
        case PcTone.amber:
          bg = AppTheme.amber400;
          fg = AppTheme.amberOnFg;
        case PcTone.red:
          bg = AppTheme.red400;
          fg = Colors.white;
        case PcTone.neutral:
          bg = AppTheme.slate700;
          fg = Colors.white;
      }
    } else {
      final c = _toneChip(tone);
      bg = c.bg;
      fg = c.fg;
    }
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: _display(size: 11.5, weight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

// ============================================================
// PcTag (dont variante Express)
// ============================================================

class PcTag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool express;
  final PcTone tone;

  const PcTag(this.label,
      {super.key, this.icon, this.express = false, this.tone = PcTone.neutral});

  const PcTag.express({super.key})
      : label = 'Express',
        icon = null,
        express = true,
        tone = PcTone.red;

  @override
  Widget build(BuildContext context) {
    if (express) {
      return Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: AppTheme.red50,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.red100),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('»',
                style: _display(
                    size: 12, weight: FontWeight.w800, color: AppTheme.red500)),
            const SizedBox(width: 4),
            Text(label.toUpperCase(),
                style: _display(
                    size: 11.5,
                    weight: FontWeight.w700,
                    color: AppTheme.red500,
                    letterSpacing: 0.4)),
          ],
        ),
      );
    }
    final fg = _toneChip(tone).fg;
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.slate300),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 5),
          ],
          Text(label, style: _body(size: 12.5, weight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

// ============================================================
// PcAvatar
// ============================================================

enum PcAvatarStatus { none, online, busy, offline }

class PcAvatar extends StatelessWidget {
  final String name;
  final double size;
  final PcAvatarStatus status;
  final bool square;

  const PcAvatar(
    this.name, {
    super.key,
    this.size = 44,
    this.status = PcAvatarStatus.none,
    this.square = false,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    const palettes = [
      _ToneChip(AppTheme.teal100, AppTheme.teal700),
      _ToneChip(AppTheme.green100, AppTheme.green800),
      _ToneChip(AppTheme.amber100, AppTheme.amber700),
      _ToneChip(AppTheme.infoSoft, AppTheme.deep700),
    ];
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    final pal = palettes[hash % palettes.length];
    final radius =
        square ? BorderRadius.circular(AppTheme.radiusMd) : BorderRadius.circular(size);

    final dotColor = switch (status) {
      PcAvatarStatus.online => AppTheme.green500,
      PcAvatarStatus.busy => AppTheme.amber400,
      PcAvatarStatus.offline => AppTheme.slate300,
      PcAvatarStatus.none => null,
    };
    final dotSize = (size * 0.28).clamp(9, 18).toDouble();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: pal.bg, borderRadius: radius),
            alignment: Alignment.center,
            child: Text(_initials,
                style: _display(size: size * 0.38, weight: FontWeight.w700, color: pal.fg)),
          ),
          if (dotColor != null)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.cardColor, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// PcListRow + PcDivider
// ============================================================

class PcListRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final PcTone iconTone;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;

  const PcListRow({
    super.key,
    this.icon,
    this.leading,
    this.iconTone = PcTone.neutral,
    required this.title,
    this.subtitle,
    this.trailing,
    this.chevron = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = _toneChip(iconTone);
    final row = Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          if (leading != null)
            leading!
          else if (icon != null)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: chip.bg,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, size: 22, color: chip.fg),
            ),
          if (leading != null || icon != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _display(size: 15, weight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _body(size: 13, color: AppTheme.slate500)),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          if (chevron) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 22, color: AppTheme.slate400),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: row,
      ),
    );
  }
}

class PcDivider extends StatelessWidget {
  const PcDivider({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Divider(height: 1, thickness: 1, color: AppTheme.slate200),
      );
}

// ============================================================
// PcEmptyState
// ============================================================

class PcEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final PcTone tone;

  const PcEmptyState({
    super.key,
    this.icon = Icons.inbox_rounded,
    required this.title,
    this.message,
    this.action,
    this.tone = PcTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final chip = _toneChip(tone);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: chip.bg, shape: BoxShape.circle),
              child: Icon(icon, size: 38, color: chip.fg),
            ),
            const SizedBox(height: 6),
            Text(title, style: _display(size: 17, weight: FontWeight.w700)),
            if (message != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(message!,
                    textAlign: TextAlign.center,
                    style: _body(size: 14, color: AppTheme.slate500, height: 1.5)),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PcSectionHeader
// ============================================================

class PcSectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const PcSectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: _display(size: 16, weight: FontWeight.w700)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: _display(
                      size: 13, weight: FontWeight.w600, color: AppTheme.teal600)),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// PcGradientHeader (bandeau brand)
// ============================================================

class PcGradientHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool amber;

  const PcGradientHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 52, 16, 22),
    this.amber = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: amber ? AppTheme.amberGradient : AppTheme.brandGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: child,
    );
  }
}

// ============================================================
// PcMeta (icône + texte) — utilitaire lignes méta
// ============================================================

class PcMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  const PcMeta(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.slate400),
        const SizedBox(width: 5),
        Text(text, style: _body(size: 12.5, weight: FontWeight.w500, color: AppTheme.slate500)),
      ],
    );
  }
}
