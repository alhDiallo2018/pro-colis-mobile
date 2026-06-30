# PRO COLIS Mobile API Guide

Ce dossier documente les endpoints a consommer depuis l'application Flutter.

Base URL locale Docker :

```text
http://localhost:18081/api/v1
```

En emulateur Android, utiliser generalement :

```text
http://10.0.2.2:18081/api/v1
```

## Fichiers

- `00-conventions.md` : headers, auth, formats JSON, pagination, erreurs.
- `01-auth.md` : login, register, refresh, utilisateur courant.
- `02-common.md` : endpoints communs a plusieurs profils.
- `03-client.md` : parcours client/customer.
- `04-driver.md` : parcours chauffeur/driver.
- `05-garage-admin.md` : parcours admin garage.
- `06-super-admin.md` : parcours super admin.

## Comptes seedes

```text
Client:
phone: +221770000101
pin: 123456

Driver:
phone: +221770000202
pin: 123456
```

## Statut implementation

Les endpoints marques `IMPLEMENTE` existent dans le backend actuel. Les endpoints marques `SPEC` sont le contrat attendu pour brancher Flutter et guider la suite d'implementation backend.
