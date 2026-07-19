import 'package:shared_preferences/shared_preferences.dart';
import 'brevo_service.dart';

enum NotificationEventType {
  parcelCreated('parcel_created', 'Colis créé'),
  parcelConfirmed('parcel_confirmed', 'Colis confirmé'),
  parcelPickedUp('parcel_picked_up', 'Colis ramassé'),
  parcelInTransit('parcel_in_transit', 'Colis en transit'),
  parcelArrived('parcel_arrived', 'Colis arrivé'),
  parcelOutForDelivery('parcel_out_for_delivery', 'En livraison'),
  parcelDelivered('parcel_delivered', 'Colis livré'),
  parcelCancelled('parcel_cancelled', 'Colis annulé'),
  bidReceived('bid_received', 'Offre reçue'),
  bidAccepted('bid_accepted', 'Offre acceptée'),
  bidRejected('bid_rejected', 'Offre refusée'),
  driverAssigned('driver_assigned', 'Chauffeur assigné'),
  paymentConfirmed('payment_confirmed', 'Paiement confirmé'),
  welcome('welcome', 'Bienvenue'),
  passwordReset('password_reset', 'Mot de passe'),
  verification('verification', 'Vérification'),
  accountSuspended('account_suspended', 'Compte suspendu');

  final String value;
  final String label;
  const NotificationEventType(this.value, this.label);

  static NotificationEventType fromString(String v) =>
      NotificationEventType.values.firstWhere(
        (e) => e.value == v,
        orElse: () => NotificationEventType.parcelCreated,
      );
}

const List<NotificationEventType> allEventTypes = NotificationEventType.values;

enum NotificationChannel { inApp, email, sms }

class NotificationPreference {
  final NotificationEventType eventType;
  final List<NotificationChannel> channels;

  const NotificationPreference({
    required this.eventType,
    this.channels = const [NotificationChannel.inApp],
  });

  NotificationPreference copyWith({List<NotificationChannel>? channels}) {
    return NotificationPreference(
      eventType: eventType,
      channels: channels ?? this.channels,
    );
  }
}

class NotificationContext {
  final String? trackingNumber;
  final String? description;
  final String? status;
  final String? senderName;
  final String? receiverName;
  final String? departureCity;
  final String? arrivalCity;
  final double? price;
  final String? fullName;
  final String? driverName;
  final String? garageName;
  final double? bidPrice;
  final String? reason;
  final String? resetLink;
  final String? verificationCode;

  const NotificationContext({
    this.trackingNumber,
    this.description,
    this.status,
    this.senderName,
    this.receiverName,
    this.departureCity,
    this.arrivalCity,
    this.price,
    this.fullName,
    this.driverName,
    this.garageName,
    this.bidPrice,
    this.reason,
    this.resetLink,
    this.verificationCode,
  });
}

const String _appName = 'SENDPROCOLIS';
const String _platformUrl = 'https://sendprocolis.com';

final _statusLabel = <String, String>{
  'pending': 'En attente',
  'free': 'Disponible aux enchères',
  'confirmed': 'Confirmé',
  'picked_up': 'Ramassé',
  'in_transit': 'En transit',
  'arrived': 'Arrivé à destination',
  'out_for_delivery': 'En cours de livraison',
  'delivered': 'Livré',
  'cancelled': 'Annulé',
};

String _emailShell(String title, String bodyContent) {
  return '''<!DOCTYPE html>
<html lang="fr">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>$title</title></head>
<body style="margin:0;padding:0;background:#f5f7fa;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f5f7fa;padding:40px 0;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.06);">
<tr><td style="background:linear-gradient(135deg,#0d9488,#14b8a6);padding:32px 40px;text-align:center;">
<span style="font-size:22px;font-weight:700;color:#fff;letter-spacing:0.5px;">$_appName</span>
</td></tr>
<tr><td style="padding:32px 40px;">
<h1 style="margin:0 0 16px;font-size:20px;color:#1e293b;">$title</h1>
$bodyContent
</td></tr>
<tr><td style="background:#f8fafc;padding:20px 40px;border-top:1px solid #e2e8f0;">
<p style="margin:0 0 8px;font-size:12px;color:#94a3b8;">Ce message a été envoyé automatiquement par $_appName.<br/>Pour gérer vos préférences de notification, connectez-vous à votre compte sur <a href="$_platformUrl" style="color:#0d9488;">$_platformUrl</a>.</p>
<p style="margin:0;font-size:11px;color:#cbd5e1;">© ${DateTime.now().year} $_appName — Livraison de colis au Sénégal, en Afrique et à l'international</p>
</td></tr>
</table>
</td></tr>
</table>
</body>
</html>''';
}

String parcelCreatedEmail(NotificationContext ctx) {
  final t = ctx.trackingNumber ?? '';
  final d = ctx.description ?? '';
  final body = '''
<p style="margin:0 0 16px;font-size:15px;color:#475569;line-height:1.6;">
Votre colis <strong style="color:#0d9488;">$t</strong> a bien été enregistré.
${d.isNotEmpty ? '<br/><em>"$d"</em>' : ''}
</p>
<table cellpadding="0" cellspacing="0" style="width:100%;margin-bottom:20px;">
<tr><td style="padding:12px 16px;background:#f1f5f9;border-radius:8px;">
<table cellpadding="0" cellspacing="0" width="100%">
<tr><td style="font-size:13px;color:#64748b;">Expéditeur</td><td style="font-size:13px;color:#1e293b;font-weight:600;">${ctx.senderName ?? '—'}</td></tr>
<tr><td style="font-size:13px;color:#64748b;">Destinataire</td><td style="font-size:13px;color:#1e293b;font-weight:600;">${ctx.receiverName ?? '—'}</td></tr>
<tr><td style="font-size:13px;color:#64748b;">Trajet</td><td style="font-size:13px;color:#1e293b;font-weight:600;">${ctx.departureCity ?? '—'} → ${ctx.arrivalCity ?? '—'}</td></tr>
</table>
</td></tr>
</table>
<p style="margin:0 0 24px;font-size:14px;color:#64748b;">Suivez l'avancement de votre colis à tout moment via votre tableau de bord.</p>
<a href="$_platformUrl/client/suivi?tracking=$t" style="display:inline-block;padding:12px 28px;background:#0d9488;color:#fff;border-radius:8px;text-decoration:none;font-weight:600;font-size:14px;">Suivre mon colis</a>''';
  return _emailShell('Colis $t enregistré avec succès', body);
}

String parcelStatusEmail(NotificationContext ctx) {
  final t = ctx.trackingNumber ?? '';
  final status = _statusLabel[ctx.status ?? ''] ?? ctx.status ?? '';
  final price = ctx.price;

  final body = '''
<p style="margin:0 0 16px;font-size:15px;color:#475569;line-height:1.6;">
Le statut de votre colis <strong style="color:#0d9488;">$t</strong> a été mis à jour.
</p>
<div style="background:#ecfdf5;border-left:4px solid #0d9488;padding:14px 18px;border-radius:0 8px 8px 0;margin-bottom:20px;">
<span style="font-size:16px;font-weight:700;color:#0d9488;">$status</span>
</div>
${ctx.driverName != null && ctx.driverName!.isNotEmpty ? '<p style="margin:0 0 16px;font-size:14px;color:#475569;">Chauffeur assigné : <strong>${ctx.driverName}</strong></p>' : ''}
${price != null ? '<p style="margin:0 0 16px;font-size:14px;color:#475569;">Montant : <strong>${price.toStringAsFixed(0)} FCFA</strong></p>' : ''}
<a href="$_platformUrl/client/suivi?tracking=$t" style="display:inline-block;padding:12px 28px;background:#0d9488;color:#fff;border-radius:8px;text-decoration:none;font-weight:600;font-size:14px;">Voir le détail</a>''';
  return _emailShell('Colis $t : $status', body);
}

String parcelDeliveredEmail(NotificationContext ctx) {
  final t = ctx.trackingNumber ?? '';
  final body = '''
<p style="margin:0 0 16px;font-size:15px;color:#475569;line-height:1.6;">
Votre colis <strong style="color:#0d9488;">$t</strong> a été livré avec succès !
</p>
<div style="background:#ecfdf5;border:1px solid #6ee7b7;border-radius:8px;padding:18px;margin-bottom:20px;text-align:center;">
<span style="font-size:32px;">📦</span>
<p style="margin:8px 0 0;font-size:15px;font-weight:600;color:#065f46;">Livraison confirmée</p>
${ctx.driverName != null && ctx.driverName!.isNotEmpty ? '<p style="margin:4px 0 0;font-size:13px;color:#047857;">par ${ctx.driverName}</p>' : ''}
</div>
<p style="margin:0 0 20px;font-size:14px;color:#64748b;">Merci de votre confiance ! Vous pouvez noter le service dans votre tableau de bord.</p>
<a href="$_platformUrl/client" style="display:inline-block;padding:12px 28px;background:#0d9488;color:#fff;border-radius:8px;text-decoration:none;font-weight:600;font-size:14px;">Tableau de bord</a>''';
  return _emailShell('Colis $t livré !', body);
}

String bidReceivedEmail(NotificationContext ctx) {
  final t = ctx.trackingNumber ?? '';
  final body = '''
<p style="margin:0 0 16px;font-size:15px;color:#475569;line-height:1.6;">
Un chauffeur a fait une offre pour votre colis <strong style="color:#0d9488;">$t</strong>.
</p>
<table cellpadding="0" cellspacing="0" style="width:100%;margin-bottom:20px;">
<tr><td style="padding:12px 16px;background:#f1f5f9;border-radius:8px;">
<table cellpadding="0" cellspacing="0" width="100%">
<tr><td style="font-size:13px;color:#64748b;">Chauffeur</td><td style="font-size:13px;color:#1e293b;font-weight:600;">${ctx.driverName ?? '—'}</td></tr>
${ctx.bidPrice != null ? '<tr><td style="font-size:13px;color:#64748b;">Prix proposé</td><td style="font-size:13px;color:#1e293b;font-weight:600;">${ctx.bidPrice!.toStringAsFixed(0)} FCFA</td></tr>' : ''}
</table>
</td></tr>
</table>
<a href="$_platformUrl/client/offres" style="display:inline-block;padding:12px 28px;background:#0d9488;color:#fff;border-radius:8px;text-decoration:none;font-weight:600;font-size:14px;">Voir les offres</a>''';
  return _emailShell('Nouvelle offre pour le colis $t', body);
}

String bidAcceptedEmail(NotificationContext ctx) {
  final t = ctx.trackingNumber ?? '';
  final body = '''
<p style="margin:0 0 16px;font-size:15px;color:#475569;line-height:1.6;">
Votre offre pour le colis <strong style="color:#0d9488;">$t</strong> a été acceptée !
</p>
<div style="background:#ecfdf5;border:1px solid #6ee7b7;border-radius:8px;padding:18px;margin-bottom:20px;">
<p style="margin:0;font-size:15px;font-weight:600;color:#065f46;">Vous êtes assigné à cette livraison.</p>
${ctx.bidPrice != null ? '<p style="margin:6px 0 0;font-size:14px;color:#047857;">Prix convenu : ${ctx.bidPrice!.toStringAsFixed(0)} FCFA</p>' : ''}
</div>
<a href="$_platformUrl/driver/missions" style="display:inline-block;padding:12px 28px;background:#0d9488;color:#fff;border-radius:8px;text-decoration:none;font-weight:600;font-size:14px;">Voir mes missions</a>''';
  return _emailShell('Offre acceptée pour le colis $t', body);
}

String driverAssignedEmail(NotificationContext ctx) {
  final t = ctx.trackingNumber ?? '';
  final body = '''
<p style="margin:0 0 16px;font-size:15px;color:#475569;line-height:1.6;">
Un chauffeur a été assigné à votre colis <strong style="color:#0d9488;">$t</strong>.
</p>
${ctx.driverName != null && ctx.driverName!.isNotEmpty ? '<p style="margin:0 0 16px;font-size:14px;color:#475569;">Chauffeur : <strong>${ctx.driverName}</strong></p>' : ''}
<a href="$_platformUrl/client/suivi?tracking=$t" style="display:inline-block;padding:12px 28px;background:#0d9488;color:#fff;border-radius:8px;text-decoration:none;font-weight:600;font-size:14px;">Suivre mon colis</a>''';
  return _emailShell('Chauffeur assigné — Colis $t', body);
}

String welcomeEmail(NotificationContext ctx) {
  final name = ctx.fullName ?? '';
  final body = '''
<p style="margin:0 0 16px;font-size:15px;color:#475569;line-height:1.6;">
Bienvenue sur $_appName,${name.isNotEmpty ? ' <strong>$name</strong> !' : ' !'}
</p>
<p style="margin:0 0 16px;font-size:14px;color:#64748b;line-height:1.6;">
$_appName est votre plateforme de livraison de colis au Sénégal, en Afrique et à l'international.
Commandez, expédiez ou transportez des colis en toute sécurité entre les principales villes du pays et au-delà des frontières.
</p>
<a href="$_platformUrl/login" style="display:inline-block;padding:12px 28px;background:#0d9488;color:#fff;border-radius:8px;text-decoration:none;font-weight:600;font-size:14px;">Accéder à mon compte</a>''';
  return _emailShell('Bienvenue sur $_appName !', body);
}

String passwordResetEmail(NotificationContext ctx) {
  final link = ctx.resetLink ?? '$_platformUrl/reset-password';
  final body = '''
<p style="margin:0 0 16px;font-size:15px;color:#475569;line-height:1.6;">
Vous avez demandé la réinitialisation de votre mot de passe.
</p>
<p style="margin:0 0 20px;font-size:14px;color:#64748b;">Cliquez sur le lien ci-dessous pour définir un nouveau mot de passe :</p>
<a href="$link" style="display:inline-block;padding:12px 28px;background:#0d9488;color:#fff;border-radius:8px;text-decoration:none;font-weight:600;font-size:14px;">Réinitialiser mon mot de passe</a>
<p style="margin:20px 0 0;font-size:12px;color:#94a3b8;">Si vous n'avez pas demandé cette réinitialisation, ignorez ce message.</p>''';
  return _emailShell('Réinitialisation du mot de passe', body);
}

String verificationEmail(NotificationContext ctx) {
  final code = ctx.verificationCode ?? '—';
  final body = '''
<p style="margin:0 0 16px;font-size:15px;color:#475569;line-height:1.6;">
Voici votre code de vérification pour $_appName :
</p>
<div style="background:#f1f5f9;border-radius:8px;padding:20px;text-align:center;margin-bottom:20px;">
<span style="font-family:'Courier New',monospace;font-size:28px;font-weight:700;color:#0d9488;letter-spacing:6px;">$code</span>
</div>
<p style="margin:0;font-size:12px;color:#94a3b8;">Ce code expire dans 10 minutes.</p>''';
  return _emailShell('Code de vérification', body);
}

String parcelCreatedSms(NotificationContext ctx) {
  final t = ctx.trackingNumber ?? '';
  return '$_appName : Colis $t enregistré. Suivez-le sur $_platformUrl/suivi';
}

String parcelStatusSms(NotificationContext ctx) {
  final t = ctx.trackingNumber ?? '';
  final status = _statusLabel[ctx.status ?? ''] ?? ctx.status ?? '';
  return '$_appName : Colis $t — $status. ${ctx.driverName != null ? 'Chauffeur : ${ctx.driverName}. ' : ''}Suivi : $_platformUrl/suivi';
}

String parcelDeliveredSms(NotificationContext ctx) {
  final t = ctx.trackingNumber ?? '';
  return '$_appName : Colis $t livré avec succès ! ${ctx.driverName != null ? 'Merci à ${ctx.driverName} ! ' : ''}Notez le service sur l\'app.';
}

String bidReceivedSms(NotificationContext ctx) {
  final t = ctx.trackingNumber ?? '';
  return '$_appName : Nouvelle offre pour le colis $t${ctx.bidPrice != null ? ' à ${ctx.bidPrice!.toStringAsFixed(0)} FCFA' : ''}. Consultez vos offres sur l\'app.';
}

String bidAcceptedSms(NotificationContext ctx) {
  final t = ctx.trackingNumber ?? '';
  return '$_appName : Votre offre pour le colis $t a été acceptée !${ctx.bidPrice != null ? ' Prix : ${ctx.bidPrice!.toStringAsFixed(0)} FCFA.' : ''} Voir vos missions.';
}

String driverAssignedSms(NotificationContext ctx) {
  final t = ctx.trackingNumber ?? '';
  return '$_appName : Chauffeur ${ctx.driverName ?? ''} assigné au colis $t. Suivi : $_platformUrl/suivi';
}

String welcomeSms(NotificationContext ctx) {
  return 'Bienvenue sur $_appName ! Livraison de colis au Sénégal et à l\'international. Téléchargez l\'app ou connectez-vous sur $_platformUrl';
}

String verificationSms(NotificationContext ctx) {
  return '$_appName : Votre code de vérification est ${ctx.verificationCode ?? '—'}. Valable 10 minutes.';
}

final emailTemplates = <NotificationEventType, String Function(NotificationContext)>{
  NotificationEventType.parcelCreated: parcelCreatedEmail,
  NotificationEventType.parcelConfirmed: parcelStatusEmail,
  NotificationEventType.parcelPickedUp: parcelStatusEmail,
  NotificationEventType.parcelInTransit: parcelStatusEmail,
  NotificationEventType.parcelArrived: parcelStatusEmail,
  NotificationEventType.parcelOutForDelivery: parcelStatusEmail,
  NotificationEventType.parcelDelivered: parcelDeliveredEmail,
  NotificationEventType.parcelCancelled: parcelStatusEmail,
  NotificationEventType.bidReceived: bidReceivedEmail,
  NotificationEventType.bidAccepted: bidAcceptedEmail,
  NotificationEventType.bidRejected: parcelStatusEmail,
  NotificationEventType.driverAssigned: driverAssignedEmail,
  NotificationEventType.paymentConfirmed: parcelStatusEmail,
  NotificationEventType.welcome: welcomeEmail,
  NotificationEventType.passwordReset: passwordResetEmail,
  NotificationEventType.verification: verificationEmail,
  NotificationEventType.accountSuspended: parcelStatusEmail,
};

final smsTemplates = <NotificationEventType, String Function(NotificationContext)>{
  NotificationEventType.parcelCreated: parcelCreatedSms,
  NotificationEventType.parcelPickedUp: parcelStatusSms,
  NotificationEventType.parcelInTransit: parcelStatusSms,
  NotificationEventType.parcelDelivered: parcelDeliveredSms,
  NotificationEventType.bidReceived: bidReceivedSms,
  NotificationEventType.bidAccepted: bidAcceptedSms,
  NotificationEventType.driverAssigned: driverAssignedSms,
  NotificationEventType.welcome: welcomeSms,
  NotificationEventType.verification: verificationSms,
};

String _getSubjectFor(NotificationEventType eventType, NotificationContext ctx) {
  final t = ctx.trackingNumber ?? '';
  switch (eventType) {
    case NotificationEventType.parcelCreated: return 'SENDPROCOLIS — Colis $t enregistré';
    case NotificationEventType.parcelConfirmed: return 'SENDPROCOLIS — Colis $t confirmé';
    case NotificationEventType.parcelPickedUp: return 'SENDPROCOLIS — Colis $t ramassé';
    case NotificationEventType.parcelInTransit: return 'SENDPROCOLIS — Colis $t en transit';
    case NotificationEventType.parcelArrived: return 'SENDPROCOLIS — Colis $t arrivé';
    case NotificationEventType.parcelOutForDelivery: return 'SENDPROCOLIS — Colis $t en livraison';
    case NotificationEventType.parcelDelivered: return 'SENDPROCOLIS — Colis $t livré !';
    case NotificationEventType.parcelCancelled: return 'SENDPROCOLIS — Colis $t annulé';
    case NotificationEventType.bidReceived: return 'SENDPROCOLIS — Offre reçue pour $t';
    case NotificationEventType.bidAccepted: return 'SENDPROCOLIS — Offre acceptée pour $t';
    case NotificationEventType.bidRejected: return 'SENDPROCOLIS — Offre refusée pour $t';
    case NotificationEventType.driverAssigned: return 'SENDPROCOLIS — Chauffeur assigné à $t';
    case NotificationEventType.paymentConfirmed: return 'SENDPROCOLIS — Paiement confirmé';
    case NotificationEventType.welcome: return 'Bienvenue sur SENDPROCOLIS !';
    case NotificationEventType.passwordReset: return 'SENDPROCOLIS — Réinitialisation du mot de passe';
    case NotificationEventType.verification: return 'SENDPROCOLIS — Code de vérification';
    case NotificationEventType.accountSuspended: return 'SENDPROCOLIS — Compte suspendu';
  }
}

class NotificationEngine {
  static const String _prefsKey = 'sendprocolis-notification-prefs';

  final BrevoService _brevoService = BrevoService();

  List<NotificationChannel> _getChannels(NotificationEventType eventType, List<NotificationPreference> prefs) {
    final entry = prefs.cast<NotificationPreference?>().firstWhere(
      (p) => p?.eventType == eventType,
      orElse: () => null,
    );
    return entry?.channels ?? [NotificationChannel.inApp];
  }

  Future<void> dispatchNotification({
    required NotificationEventType eventType,
    required NotificationContext context,
    String? userEmail,
    String? userPhone,
  }) async {
    final prefs = await getPreferences();
    final channels = _getChannels(eventType, prefs);

    if (channels.contains(NotificationChannel.email) && userEmail != null && userEmail.isNotEmpty) {
      final template = emailTemplates[eventType];
      if (template != null) {
        final htmlContent = template(context);
        final subject = _getSubjectFor(eventType, context);
        _brevoService.sendEmail(BrevoEmailParams(
          to: userEmail,
          toName: context.fullName,
          subject: subject,
          htmlContent: htmlContent,
        )).catchError((_) {});
      }
    }

    if (channels.contains(NotificationChannel.sms) && userPhone != null && userPhone.isNotEmpty) {
      final template = smsTemplates[eventType];
      if (template != null) {
        final content = template(context);
        _brevoService.sendSms(BrevoSmsParams(
          to: userPhone,
          content: content,
        )).catchError((_) {});
      }
    }
  }

  Future<List<NotificationPreference>> getPreferences() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = _decodeStringList(raw);
        return decoded;
      }
    } catch (_) {}
    return _defaultPreferences();
  }

  Future<void> updatePreferences(List<NotificationPreference> preferences) async {
    final sp = await SharedPreferences.getInstance();
    final encoded = _encodePreferences(preferences);
    await sp.setString(_prefsKey, encoded);
  }

  List<NotificationPreference> _defaultPreferences() {
    return allEventTypes.map((e) => NotificationPreference(
      eventType: e,
      channels: [NotificationChannel.inApp],
    )).toList();
  }

  List<NotificationPreference> _decodeStringList(String raw) {
    final parts = raw.split('|');
    final result = <NotificationPreference>[];
    for (final part in parts) {
      final segments = part.split(':');
      if (segments.length >= 2) {
        final eventType = NotificationEventType.fromString(segments[0]);
        final channels = segments[1].split(',').map((c) {
          switch (c) {
            case 'email': return NotificationChannel.email;
            case 'sms': return NotificationChannel.sms;
            default: return NotificationChannel.inApp;
          }
        }).toList();
        result.add(NotificationPreference(eventType: eventType, channels: channels));
      }
    }
    return result.isNotEmpty ? result : _defaultPreferences();
  }

  String _encodePreferences(List<NotificationPreference> prefs) {
    return prefs.map((p) {
      final channelStr = p.channels.map((c) {
        switch (c) {
          case NotificationChannel.email: return 'email';
          case NotificationChannel.sms: return 'sms';
          default: return 'in_app';
        }
      }).join(',');
      return '${p.eventType.value}:$channelStr';
    }).join('|');
  }
}
