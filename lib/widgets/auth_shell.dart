import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/fonts.dart';
import 'app_logo.dart';
import 'delivery_van.dart';

/// Shared scaffold for login / register / forgot-pin / google-completion.
/// Simple top bar (brand + optional actions) and a clean content area.
/// No large gradient banner — keeps the form prominent like the older design.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    this.lead,
    this.eyebrow,
    this.heroIcon,
    this.heroAccent,
    required this.child,
    this.actions,
    this.footer,
    this.onBrandTap,
    this.showBrand = true,
    this.showVan = true,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 24, 20, 32),
  });

  final String title;
  final String? lead;
  final String? eyebrow;
  final IconData? heroIcon;
  final Color? heroAccent;
  final Widget child;
  final List<Widget>? actions;
  final Widget? footer;
  final VoidCallback? onBrandTap;
  final bool showBrand;
  final bool showVan;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showBrand) _AuthTopBar(onBrandTap: onBrandTap, actions: actions),
            if (showVan)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: DeliveryVan(height: 72),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: AppTheme.screenMaxWidth),
                    child: Padding(
                      padding: contentPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AuthHeader(
                            title: title,
                            lead: lead,
                            eyebrow: eyebrow,
                            heroIcon: heroIcon,
                            heroAccent: heroAccent,
                          ),
                          const SizedBox(height: 24),
                          child,
                          if (footer != null) ...[
                            const SizedBox(height: 20),
                            footer!,
                          ],
                          SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthTopBar extends StatelessWidget {
  const _AuthTopBar({required this.onBrandTap, required this.actions});

  final VoidCallback? onBrandTap;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(bottom: BorderSide(color: AppTheme.slate100)),
      ),
      child: Row(
        children: [
          AppBrandLink(
            isWhite: false,
            onTap: onBrandTap ?? () {},
          ),
          const Spacer(),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({
    required this.title,
    required this.lead,
    required this.eyebrow,
    required this.heroIcon,
    required this.heroAccent,
  });

  final String title;
  final String? lead;
  final String? eyebrow;
  final IconData? heroIcon;
  final Color? heroAccent;

  @override
  Widget build(BuildContext context) {
    final accent = heroAccent ?? AppTheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (heroIcon != null) ...[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(heroIcon, color: accent, size: 28),
          ),
          const SizedBox(height: 14),
        ],
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: AppFonts.plusJakartaSans(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          title,
          style: AppFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.4,
          ),
        ),
        if (lead != null) ...[
          const SizedBox(height: 8),
          Text(
            lead!,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// Small rounded section used inside auth forms (grey/teal background).
class AuthCallout extends StatelessWidget {
  const AuthCallout({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tone = AuthCalloutTone.info,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final AuthCalloutTone tone;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      AuthCalloutTone.info => (AppTheme.teal50, AppTheme.teal700),
      AuthCalloutTone.amber => (AppTheme.amber50, AppTheme.amber700),
      AuthCalloutTone.success => (AppTheme.green50, AppTheme.green700),
      AuthCalloutTone.danger => (AppTheme.red50, AppTheme.red500),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: fg.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: fg, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

enum AuthCalloutTone { info, amber, success, danger }

/// Rounded segmented toggle used by login (phone/email) and elsewhere.
class AuthSegment extends StatelessWidget {
  const AuthSegment({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final List<AuthSegmentOption> options;
  final int value;
  final ValueChanged<int> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.slate100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: enabled ? () => onChanged(i) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: value == i ? AppTheme.cardColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: value == i
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        options[i].icon,
                        size: 18,
                        color: value == i ? AppTheme.teal600 : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        options[i].label,
                        style: AppFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: value == i ? AppTheme.textPrimary : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AuthSegmentOption {
  const AuthSegmentOption({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
