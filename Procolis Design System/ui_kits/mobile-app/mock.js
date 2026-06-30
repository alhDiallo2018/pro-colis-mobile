// Procolis mobile UI kit — mock data (no backend). window.PCMock
(function () {
  const parcels = [
    { id: 'p1', tracking: 'PC-7F3K-2291', from: 'Abidjan', to: 'Bouaké', status: 'transit', price: '12 500 FCFA', weight: '8 kg', type: 'Colis standard', eta: '~4 h', express: true,
      sender: 'Awa Diallo', recipient: 'Moussa Traoré', recipientPhone: '+225 07 88 21 04', driver: 'Koffi Aka', offers: 0 },
    { id: 'p2', tracking: 'PC-2M9X-7740', from: 'Abidjan', to: 'Yamoussoukro', status: 'free', price: '6 000 FCFA', weight: '3 kg', type: 'Document', eta: '~2 h', express: false,
      sender: 'Awa Diallo', recipient: 'Service RH — Banque Atlantique', offers: 3 },
    { id: 'p3', tracking: 'PC-5J1B-3382', from: 'Abidjan', to: 'San-Pédro', status: 'delivered', price: '18 000 FCFA', weight: '15 kg', type: 'Volumineux', eta: 'Livré', express: false,
      sender: 'Awa Diallo', recipient: 'Comptoir du Port', driver: 'Ibrahim Koné', offers: 0 },
    { id: 'p4', tracking: 'PC-9D4C-1120', from: 'Abidjan', to: 'Korhogo', status: 'pending', price: '22 000 FCFA', weight: '12 kg', type: 'Fragile', eta: 'À confirmer', express: false,
      sender: 'Awa Diallo', recipient: 'Pharmacie du Nord', offers: 0 },
  ];

  // libre-service pool seen by a driver
  const freeParcels = [
    { id: 'f1', tracking: 'PC-2M9X-7740', from: 'Abidjan', to: 'Yamoussoukro', status: 'free', price: '6 000 FCFA', weight: '3 kg', type: 'Document', eta: '~2 h', distance: '240 km', offers: 3 },
    { id: 'f2', tracking: 'PC-8K3P-5521', from: 'Abidjan', to: 'Daloa', status: 'free', price: '14 500 FCFA', weight: '10 kg', type: 'Colis standard', eta: '~5 h', distance: '380 km', offers: 1, express: true },
    { id: 'f3', tracking: 'PC-1A7T-9043', from: 'Abidjan', to: 'Man', status: 'free', price: '20 000 FCFA', weight: '18 kg', type: 'Volumineux', eta: '~7 h', distance: '570 km', offers: 0 },
  ];

  const offers = [
    { id: 'o1', driver: 'Koffi Aka', rating: '4,9', garage: 'Garage de Cocody', price: '11 000 FCFA', message: 'Je pars à 14 h, livraison ce soir.', hasAudio: true, when: 'il y a 8 min' },
    { id: 'o2', driver: 'Ibrahim Koné', rating: '4,7', garage: 'Garage Treichville', price: '12 000 FCFA', message: 'Disponible immédiatement.', hasAudio: false, when: 'il y a 22 min' },
    { id: 'o3', driver: 'Sékou Bamba', rating: '4,8', garage: 'Garage de Cocody', price: '13 500 FCFA', message: 'Véhicule réfrigéré dispo si besoin.', hasAudio: true, when: 'il y a 1 h' },
  ];

  const timeline = [
    { label: 'Colis créé', time: 'Auj. 08:12', status: 'done', icon: 'add_box', note: 'Déposé par Awa Diallo' },
    { label: 'Confirmé', time: '08:30', status: 'done', icon: 'check' },
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
  ];

  const cities = ['Abidjan', 'Bouaké', 'Yamoussoukro', 'San-Pédro', 'Korhogo', 'Daloa', 'Man', 'Gagnoa', 'Divo', 'Abengourou'];
  const parcelTypes = ['Colis standard', 'Document', 'Fragile', 'Volumineux', 'Denrées'];

  const user = { name: 'Awa Diallo', phone: '+225 07 11 45 90', city: 'Abidjan', points: '2 450', initials: 'AD', role: 'client' };

  window.PCMock = { parcels, freeParcels, offers, timeline, notifications, cities, parcelTypes, user };
})();
