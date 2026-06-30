# Erreurs, logging et validation

## Validation

Tous les endpoints avec `body`, `params` ou `query` doivent avoir un schema de validation.

Bibliotheque recommandee : Zod.

Exemple :

```js
const createParcelSchema = z.object({
  senderName: z.string().min(2),
  senderPhone: z.string().min(8),
  receiverName: z.string().min(2),
  receiverPhone: z.string().min(8),
  description: z.string().min(2),
  weight: z.number().positive(),
  type: z.enum(['document', 'package', 'fragile', 'perishable', 'valuable']).default('package'),
  departureGarageId: z.string().uuid(),
  arrivalGarageId: z.string().uuid().optional(),
  price: z.number().nonnegative().optional(),
  isUrgent: z.boolean().default(false),
  isInsured: z.boolean().default(false)
});
```

## Codes erreurs

| Code HTTP | Code API | Usage |
| --- | --- | --- |
| 400 | `BAD_REQUEST` | Requete mal formee. |
| 401 | `UNAUTHORIZED` | Token absent/invalide. |
| 403 | `FORBIDDEN` | Role insuffisant. |
| 404 | `NOT_FOUND` | Ressource introuvable. |
| 409 | `CONFLICT` | Doublon ou etat incompatible. |
| 422 | `VALIDATION_ERROR` | Payload invalide. |
| 429 | `RATE_LIMITED` | Trop de requetes. |
| 500 | `INTERNAL_ERROR` | Erreur serveur. |

## Gestion des erreurs en controlleur

Obligatoire pour les actions critiques :

- `try/catch`.
- log avec `req.log.error`.
- message utilisateur propre.
- ne pas exposer stack trace en production.

```js
async function updateParcelStatus(req, res) {
  try {
    // La transition de statut modifie le colis, ajoute un evenement et notifie les acteurs.
    const parcel = await parcelService.updateStatus({
      actor: req.user,
      parcelId: req.params.parcelId,
      status: req.body.status,
      location: req.body.location
    });

    return res.json({ success: true, parcel });
  } catch (error) {
    req.log.error({
      error,
      action: 'parcel.updateStatus',
      parcelId: req.params.parcelId,
      userId: req.user?.id
    }, 'Failed to update parcel status');

    return res.status(error.statusCode || 500).json({
      success: false,
      message: error.publicMessage || 'Impossible de mettre a jour le statut du colis'
    });
  }
}
```

## Logging propre

Logger :

- action.
- ressource cible.
- utilisateur.
- role.
- requestId.
- temps d'execution.

Ne pas logger :

- password.
- currentPassword.
- newPassword.
- pin/currentPin/newPin.
- otpCode/code.
- refreshToken.
- contenu base64.

## Sanitization de logs

Mettre en place une fonction qui masque automatiquement les cles sensibles :

```js
const sensitiveKeys = [
  'password',
  'currentPassword',
  'newPassword',
  'pin',
  'currentPin',
  'newPin',
  'otpCode',
  'code',
  'token',
  'refreshToken',
  'file'
];
```

## Tests d'erreur obligatoires

Tester :

- payload invalide.
- token absent.
- role insuffisant.
- ressource inexistante.
- transition statut interdite.
- tentative d'acces a une ressource d'un autre utilisateur.
- upload trop volumineux.
- paiement deja confirme.

