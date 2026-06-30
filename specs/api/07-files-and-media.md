# Fichiers et medias

## Types supportes

- photos colis : `jpg`, `jpeg`, `png`, `webp`.
- videos colis : `mp4`, `mov`, `webm`.
- audio colis/offres : `m4a`, `aac`, `mp3`, `wav`, `webm`.
- documents identite : `jpg`, `png`, `pdf`.

## Endpoints

- `POST /upload/parcel-photo`
- `POST /upload/parcel-video`
- `POST /upload/parcel-audio`
- `POST /upload/bid-audio`
- `POST /upload/base64`
- `POST /upload`
- `POST /identity/upload`

## Payload base64

```json
{
  "file": "base64-content",
  "parcelId": "uuid",
  "filename": "photo.jpg"
}
```

Reponse :

```json
{
  "success": true,
  "url": "https://cdn.example.com/uploads/parcels/photo.jpg",
  "media": {
    "id": "uuid",
    "mediaType": "photo"
  }
}
```

## Multipart

Le backend doit accepter `multipart/form-data` avec champ `file`.

## Stockage

Developpement :

- stocker sous `uploads/`.
- servir publiquement sous `/uploads`.

Production :

- utiliser S3 compatible.
- stocker uniquement l'URL publique ou signee dans PostgreSQL.

## Validation

Verifier :

- type MIME.
- extension.
- taille.
- presence du `parcelId` si upload lie a un colis.
- droit de l'utilisateur sur le colis.

Limites recommandees :

- photo : 8 MB.
- audio : 20 MB.
- video : 150 MB.
- document identite : 20 MB.

## Association au colis

L'upload peut creer directement une ligne `parcel_media` si `parcelId` est fourni.

L'endpoint `PATCH /{role}/parcels/:parcelId/media` doit aussi accepter :

```json
{
  "photoUrls": [],
  "videoUrls": [],
  "audioUrls": [],
  "signatureUrl": "https://..."
}
```

Le backend doit convertir ces URLs en lignes `parcel_media` quand elles n'existent pas encore.

## Securite

- Ne jamais executer un fichier upload.
- Renommer les fichiers cote serveur.
- Supprimer les metadonnees dangereuses si possible.
- Refuser les extensions inconnues.
- Ne jamais logger le contenu base64.

