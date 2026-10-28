# Connexion mobile et accès hors ligne

Une première connexion serveur réussie est nécessaire. L'application conserve
la session et les réponses réelles déjà synchronisées dans le stockage sécurisé.
L'historique est préparé après connexion, sans données fictives ; les écrans
indiquent le mode hors ligne et la date de sauvegarde. Les entrées expirent après
30 jours. Les positions GPS en direct ne sont jamais présentées comme disponibles
hors ligne. Une déconnexion explicite ou une révocation serveur efface le cache.

L'activation biométrique ne reconnecte plus par PIN et ne vide plus l'historique.
Le verrou propose la biométrie ou le code système de l'appareil, sans réseau.
Une reconnexion vérifiée du même compte conserve les copies et leur date ; un
changement de compte ou de rôle les invalide.

## Google : configuration externe requise

Le client Web de l'API sert de serverClientId. Sur Android, vérifier dans Google
Cloud le package com.sendprocolis.app et les SHA des signatures utilisées
(debug, release et signature Play). Un test avec un service simulé ne valide pas
cette configuration externe.

Sur iOS, créer ou retrouver un vrai client OAuth iOS correspondant au bundle ID
compilé (actuellement com.example.proColisClean). Ne pas utiliser le client Web
à sa place. Appliquer son identifiant public :

```sh
python3 tool/configure_google_ios.py --client-id IDENTIFIANT_IOS.apps.googleusercontent.com
```

Recompiler ensuite : un hot reload n'enregistre pas le schéma URL natif.
En absence de ce client, l'application explique la configuration manquante et
n'appelle pas le SDK natif. Aucun identifiant OAuth n'est inventé.

Références officielles :
- https://pub.dev/packages/google_sign_in_ios
- https://pub.dev/packages/google_sign_in_android

## Recette sur appareil

1. Se connecter en ligne, ouvrir l'historique et noter un vrai colis.
2. Activer la biométrie ; vérifier que ce colis reste présent.
3. Passer en mode avion, fermer puis rouvrir l'application : déverrouiller et
   vérifier le même colis avec sa date de synchronisation.
4. Revenir après plus d'une minute en arrière-plan : le verrou doit demander
   la biométrie, sans imposer une nouvelle connexion PIN au serveur.
5. Reconnecter un autre compte : aucun colis du compte précédent ne doit rester.
6. Tester Google sur un appareil avec les véritables clients OAuth configurés.

Les tests automatiques couvrent le cache, les générations de session, les refus
serveur et l'initialisation Google injectée ; ils ne remplacent pas la vérification
du capteur ni une connexion réelle auprès de Google.
