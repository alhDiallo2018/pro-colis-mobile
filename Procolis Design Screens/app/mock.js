// PRO COLIS — mobile app mock data (no backend). window.PCMock
(function () {
  const parcels = [
    { id: 'p1', tracking: 'PC-7F3K-2291', from: 'Abidjan', to: 'Bouaké', status: 'transit', price: '12 500 FCFA', weight: '8 kg', type: 'Colis standard', eta: '~4 h', express: true,
      sender: 'Awa Diallo', recipient: 'Moussa Traoré', recipientPhone: '+225 07 88 21 04', driver: 'Koffi Aka', garage: 'Garage de Cocody', vehicle: 'Toyota Hiace', rating: '4,9', offers: 0, distance: '350 km', pin: '4827' },
    { id: 'p2', tracking: 'PC-2M9X-7740', from: 'Abidjan', to: 'Yamoussoukro', status: 'free', price: '6 000 FCFA', weight: '3 kg', type: 'Document', eta: '~2 h', express: false,
      sender: 'Awa Diallo', recipient: 'Service RH — Banque Atlantique', recipientPhone: '+225 27 30 64 12', offers: 3, distance: '240 km' },
    { id: 'p3', tracking: 'PC-5J1B-3382', from: 'Abidjan', to: 'San-Pédro', status: 'delivered', price: '18 000 FCFA', weight: '15 kg', type: 'Volumineux', eta: 'Livré', express: false,
      sender: 'Awa Diallo', recipient: 'Comptoir du Port', recipientPhone: '+225 07 45 18 90', driver: 'Ibrahim Koné', garage: 'Garage Treichville', vehicle: 'Renault Master', rating: '4,7', offers: 0, distance: '340 km', deliveredAt: 'Hier · 18:24' },
    { id: 'p4', tracking: 'PC-9D4C-1120', from: 'Abidjan', to: 'Korhogo', status: 'pending', price: '22 000 FCFA', weight: '12 kg', type: 'Fragile', eta: 'À confirmer', express: false,
      sender: 'Awa Diallo', recipient: 'Pharmacie du Nord', recipientPhone: '+225 07 62 33 77', offers: 0, distance: '630 km' },
  ];

  // libre-service pool seen by a driver
  const freeParcels = [
    { id: 'f1', tracking: 'PC-2M9X-7740', from: 'Abidjan', to: 'Yamoussoukro', status: 'free', price: '6 000 FCFA', weight: '3 kg', type: 'Document', eta: '~2 h', distance: '240 km', offers: 3, client: 'Awa Diallo' },
    { id: 'f2', tracking: 'PC-8K3P-5521', from: 'Abidjan', to: 'Daloa', status: 'free', price: '14 500 FCFA', weight: '10 kg', type: 'Colis standard', eta: '~5 h', distance: '380 km', offers: 1, express: true, client: 'Yao Konan' },
    { id: 'f3', tracking: 'PC-1A7T-9043', from: 'Abidjan', to: 'Man', status: 'free', price: '20 000 FCFA', weight: '18 kg', type: 'Volumineux', eta: '~7 h', distance: '570 km', offers: 0, client: 'Fatou Bamba' },
    { id: 'f4', tracking: 'PC-3R6V-8810', from: 'Abidjan', to: 'Gagnoa', status: 'free', price: '9 500 FCFA', weight: '5 kg', type: 'Document', eta: '~3 h', distance: '270 km', offers: 2, client: 'Awa Diallo' },
  ];

  // missions accepted/active for the driver
  const missions = [
    { id: 'm1', tracking: 'PC-7F3K-2291', from: 'Abidjan', to: 'Bouaké', status: 'transit', price: '11 000 FCFA', weight: '8 kg', type: 'Colis standard', eta: '~4 h', express: true,
      client: 'Awa Diallo', recipient: 'Moussa Traoré', recipientPhone: '+225 07 88 21 04', distance: '350 km', points: '+150 pts' },
    { id: 'm2', tracking: 'PC-6T2N-4419', from: 'Abidjan', to: 'Yamoussoukro', status: 'pickup', price: '8 000 FCFA', weight: '6 kg', type: 'Colis standard', eta: '~2 h', express: false,
      client: 'Yao Konan', recipient: 'Boutique Centrale', recipientPhone: '+225 05 11 22 33', distance: '240 km', points: '+90 pts' },
    { id: 'm3', tracking: 'PC-0L9F-2207', from: 'Abidjan', to: 'Aboisso', status: 'delivered', price: '7 000 FCFA', weight: '4 kg', type: 'Document', eta: 'Livré', express: false,
      client: 'Fatou Bamba', recipient: 'Mairie d’Aboisso', distance: '120 km', points: '+70 pts', deliveredAt: 'Hier · 16:02' },
  ];

  const offers = [
    { id: 'o1', driver: 'Koffi Aka', rating: '4,9', garage: 'Garage de Cocody', vehicle: 'Toyota Hiace', price: '11 000 FCFA', message: 'Je pars à 14 h, livraison ce soir.', hasAudio: true, audioLen: '0:08', when: 'il y a 8 min' },
    { id: 'o2', driver: 'Ibrahim Koné', rating: '4,7', garage: 'Garage Treichville', vehicle: 'Renault Master', price: '12 000 FCFA', message: 'Disponible immédiatement.', hasAudio: false, when: 'il y a 22 min' },
    { id: 'o3', driver: 'Sékou Bamba', rating: '4,8', garage: 'Garage de Cocody', vehicle: 'Peugeot Partner', price: '13 500 FCFA', message: 'Véhicule réfrigéré dispo si besoin.', hasAudio: true, audioLen: '0:11', when: 'il y a 1 h' },
  ];

  const timeline = [
    { label: 'Colis créé', time: 'Auj. 08:12', status: 'done', icon: 'add_box', note: 'Déposé par Awa Diallo' },
    { label: 'Mis en libre service', time: '08:14', status: 'done', icon: 'sell' },
    { label: 'Offre acceptée · Koffi Aka', time: '08:28', status: 'done', icon: 'gavel', note: '11 000 FCFA' },
    { label: 'Ramassé · Garage de Cocody', time: '09:40', status: 'done', icon: 'package_2', note: 'Chauffeur : Koffi Aka' },
    { label: 'En transit vers Bouaké', time: '10:05', status: 'current', icon: 'local_shipping', note: 'Position : Toumodi · ~4 h restantes' },
    { label: 'Arrivé au garage destination', status: 'todo', icon: 'pin_drop' },
    { label: 'Livré', status: 'todo', icon: 'task_alt' },
  ];

  const notifications = [
    { id: 'n1', icon: 'sell', tone: 'primary', title: 'Nouvelle offre reçue', body: 'Koffi A. propose 11 000 FCFA pour PC-2M9X-7740.', when: '8 min', unread: true },
    { id: 'n2', icon: 'local_shipping', tone: 'green', title: 'Colis en transit', body: 'PC-7F3K-2291 part vers Bouaké.', when: '1 h', unread: true },
    { id: 'n3', icon: 'account_balance_wallet', tone: 'amber', title: 'Points crédités', body: '+150 pts pour votre dernière livraison.', when: '3 h', unread: false },
    { id: 'n4', icon: 'task_alt', tone: 'green', title: 'Colis livré', body: 'PC-5J1B-3382 a été livré à San-Pédro.', when: 'hier', unread: false },
    { id: 'n5', icon: 'verified', tone: 'primary', title: 'Compte vérifié', body: 'Votre identité a été confirmée. Bienvenue !', when: '2 j', unread: false },
  ];

  const chat = [
    { id: 'c1', from: 'driver', text: 'Bonjour, je suis en route pour récupérer votre colis.', time: '09:12' },
    { id: 'c2', from: 'me', text: 'Parfait, le gardien vous attend à l’entrée.', time: '09:14' },
    { id: 'c3', from: 'driver', text: 'Bien reçu. Colis ramassé, je pars vers Bouaké.', time: '09:41' },
    { id: 'c4', from: 'driver', audio: true, audioLen: '0:06', time: '09:42' },
    { id: 'c5', from: 'me', text: 'Merci ! Le destinataire est prévenu.', time: '09:43' },
  ];

  const txns = [
    { id: 't1', icon: 'task_alt', tone: 'green', title: 'Livraison PC-5J1B-3382', when: 'Hier · 18:24', amount: '+150 pts', positive: true },
    { id: 't2', icon: 'redeem', tone: 'amber', title: 'Bon de réduction transport', when: '12 juin', amount: '−500 pts', positive: false },
    { id: 't3', icon: 'add_card', tone: 'primary', title: 'Recharge Mobile Money', when: '8 juin', amount: '+1 000 pts', positive: true },
    { id: 't4', icon: 'task_alt', tone: 'green', title: 'Livraison PC-4X8Q-0093', when: '2 juin', amount: '+120 pts', positive: true },
  ];

  const onboarding = [
    { icon: 'inventory_2', title: 'Envoyez vos colis\nde ville en ville', body: 'Déclarez un colis en moins d’une minute et fixez votre trajet entre deux villes.', glyphs: ['package_2', 'route', 'pin_drop'] },
    { icon: 'gavel', title: 'Le meilleur prix\nen libre service', body: 'Publiez votre colis et recevez des offres de chauffeurs vérifiés. Vous choisissez.', glyphs: ['sell', 'gavel', 'mic'] },
    { icon: 'local_shipping', title: 'Suivez en temps réel\njusqu’à la livraison', body: 'Suivi du trajet, contact direct du chauffeur et preuve de livraison à l’arrivée.', glyphs: ['local_shipping', 'qr_code_2', 'verified'] },
  ];

  const helpTopics = [
    { icon: 'package_2', title: 'Créer et envoyer un colis' },
    { icon: 'sell', title: 'Libre service et offres' },
    { icon: 'qr_code_2', title: 'Suivi et livraison' },
    { icon: 'account_balance_wallet', title: 'Points et paiements' },
    { icon: 'shield', title: 'Sécurité et litiges' },
    { icon: 'person', title: 'Mon compte' },
  ];

  const faq = [
    { q: 'Comment fonctionne le libre service ?', a: 'Vous publiez votre colis, des chauffeurs vérifiés font des offres, vous acceptez celle qui vous convient.' },
    { q: 'Que se passe-t-il à la livraison ?', a: 'Le destinataire communique un code PIN au chauffeur pour confirmer la remise du colis.' },
    { q: 'Comment sont calculés les points ?', a: 'Chaque colis livré crédite des points utilisables en réductions sur vos prochains envois.' },
  ];

  const cities = ['Abidjan', 'Bouaké', 'Yamoussoukro', 'San-Pédro', 'Korhogo', 'Daloa', 'Man', 'Gagnoa', 'Divo', 'Abengourou', 'Aboisso'];
  const parcelTypes = ['Colis standard', 'Document', 'Fragile', 'Volumineux', 'Denrées'];

  const user = { name: 'Awa Diallo', phone: '+221 76 516 27 96', city: 'Abidjan', points: '2 450', initials: 'AD', role: 'client' };
  const driver = { name: 'Koffi Aka', phone: '+225 05 62 18 33', garage: 'Garage de Cocody', vehicle: 'Toyota Hiace', plate: '4821 CI 01', points: '6 180', rating: '4,9', initials: 'KA', role: 'driver', deliveries: 142, online: true };

  window.PCMock = { parcels, freeParcels, missions, offers, timeline, notifications, chat, txns, onboarding, helpTopics, faq, cities, parcelTypes, user, driver };
})();
