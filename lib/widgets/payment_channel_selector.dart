// lib/widgets/payment_channel_selector.dart
//
// Sélecteurs partagés du mode de règlement d'une course :
//
// - [AcceptedPaymentChannelsField] : côté chauffeur, dans son annonce, il coche
//   les modes qu'il accepte (espèces et/ou plateforme).
// - [PaymentChannelField] : côté client, il choisit un mode parmi ceux que le
//   chauffeur accepte.
// - [CashCollectionPointField] : en espèces, qui remet l'argent et quand
//   (l'expéditeur au ramassage, ou le destinataire à la livraison).

import 'package:flutter/material.dart';
import 'package:procolis/theme/fonts.dart';

import '../models/payment.dart';
import '../theme/app_theme.dart';

/// Case à cocher / bouton radio habillé, commun aux trois sélecteurs.
class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;

  /// `true` pour une case à cocher (choix multiple), `false` pour un radio.
  final bool multiple;
  final VoidCallback? onTap;

  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.multiple,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final borderColor = selected ? AppTheme.primary : AppTheme.slate200;
    final bg = selected ? AppTheme.teal50 : AppTheme.cardColor;

    return Opacity(
      opacity: disabled && !selected ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: borderColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppTheme.primary : AppTheme.slate400,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppTheme.teal700
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: AppFonts.manrope(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _indicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _indicator() {
    if (multiple) {
      return Icon(
        selected
            ? Icons.check_box_rounded
            : Icons.check_box_outline_blank_rounded,
        size: 21,
        color: selected ? AppTheme.primary : AppTheme.slate300,
      );
    }
    return Icon(
      selected
          ? Icons.radio_button_checked_rounded
          : Icons.radio_button_unchecked_rounded,
      size: 21,
      color: selected ? AppTheme.primary : AppTheme.slate300,
    );
  }
}

/// Libellé de section, aligné sur le style des formulaires existants.
class _FieldLabel extends StatelessWidget {
  final String text;
  final String? hint;

  const _FieldLabel(this.text, {this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: AppFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate700,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              style: AppFonts.manrope(
                fontSize: 11.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Côté chauffeur : les modes de règlement qu'il accepte sur un trajet.
///
/// Au moins un mode doit rester coché — décocher le dernier est ignoré, ce qui
/// évite de publier une annonce que personne ne peut payer.
class AcceptedPaymentChannelsField extends StatelessWidget {
  final List<PaymentChannel> value;
  final ValueChanged<List<PaymentChannel>> onChanged;
  final String label;

  const AcceptedPaymentChannelsField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Modes de paiement acceptés',
  });

  void _toggle(PaymentChannel channel) {
    final next = value.toList();
    if (next.contains(channel)) {
      if (next.length <= 1) return; // On garde toujours un mode payable.
      next.remove(channel);
    } else {
      next.add(channel);
    }
    onChanged(PaymentChannel.values.where(next.contains).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(
          label,
          hint: 'Le client choisira parmi les modes que vous acceptez.',
        ),
        for (final channel in PaymentChannel.values) ...[
          _ChoiceTile(
            icon: channel.icon,
            title: channel.label,
            subtitle: channel.hint,
            selected: value.contains(channel),
            multiple: true,
            onTap: () => _toggle(channel),
          ),
          if (channel != PaymentChannel.values.last)
            const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Côté client : le mode de règlement retenu, restreint à [available].
///
/// Quand un seul mode est disponible, il est affiché en lecture seule : le
/// chauffeur n'accepte que celui-là, il n'y a rien à choisir.
class PaymentChannelField extends StatelessWidget {
  final PaymentChannel value;
  final ValueChanged<PaymentChannel> onChanged;

  /// Modes proposés. Par défaut les deux.
  final List<PaymentChannel> available;
  final String label;

  /// Note affichée sous le sélecteur (ex. « le chauffeur doit encore accepter »).
  final String? footnote;

  const PaymentChannelField({
    super.key,
    required this.value,
    required this.onChanged,
    this.available = PaymentChannel.values,
    this.label = 'Mode de paiement',
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final channels =
        available.isEmpty ? PaymentChannel.values : available;
    final locked = channels.length == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(
          label,
          hint: locked
              ? 'Seul mode accepté par le chauffeur.'
              : 'Comment la livraison sera réglée.',
        ),
        for (final channel in channels) ...[
          _ChoiceTile(
            icon: channel.icon,
            title: channel.label,
            subtitle: channel.hint,
            selected: value == channel,
            multiple: false,
            onTap: locked ? null : () => onChanged(channel),
          ),
          if (channel != channels.last) const SizedBox(height: 8),
        ],
        if (footnote != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: AppTheme.slate400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  footnote!,
                  style: AppFonts.manrope(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// En espèces : qui remet l'argent au chauffeur, et à quelle étape.
class CashCollectionPointField extends StatelessWidget {
  final CashCollectionPoint value;
  final ValueChanged<CashCollectionPoint> onChanged;
  final String label;

  const CashCollectionPointField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Qui règle les espèces ?',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(
          label,
          hint: 'Le chauffeur confirmera l’encaissement à ce moment-là.',
        ),
        for (final point in CashCollectionPoint.values) ...[
          _ChoiceTile(
            icon: point.icon,
            title: point.label,
            subtitle: point.hint,
            selected: value == point,
            multiple: false,
            onTap: () => onChanged(point),
          ),
          if (point != CashCollectionPoint.values.last)
            const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// Pastille récapitulative du mode de règlement, réutilisable dans les listes
/// et les fiches colis.
class PaymentChannelBadge extends StatelessWidget {
  final PaymentChannel channel;
  final CashCollectionPoint? collectionPoint;

  /// Étiquette d'état facultative (« Encaissement déclaré », « Payé »…).
  final String? status;
  final Color? statusColor;

  const PaymentChannelBadge({
    super.key,
    required this.channel,
    this.collectionPoint,
    this.status,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final isCash = channel.isCash;
    final fg = isCash ? AppTheme.amber700 : AppTheme.teal700;
    final bg = isCash ? AppTheme.amber50 : AppTheme.teal50;

    final parts = <String>[channel.label];
    if (isCash && collectionPoint != null) {
      parts.add(collectionPoint!.payerLabel.toLowerCase());
    }
    if (status != null && status!.isNotEmpty) parts.add(status!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(channel.icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            parts.join(' · '),
            style: AppFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: statusColor ?? fg,
            ),
          ),
        ],
      ),
    );
  }
}
