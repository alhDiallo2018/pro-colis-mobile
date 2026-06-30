/* PRO COLIS — client screens (main). window.PCScreens.* */
(function () {
  const NS = window.ProcolisDesignSystem_1720b4;
  const { AppBar, IconButton, Button, Input, Select, Switch, Checkbox, Card, StatBox, Badge,
          StatusBadge, Tag, Avatar, ListRow, ParcelCard, Tabs, EmptyState } = NS;
  const M = window.PCMock;
  const SH = window.PCShared;
  const { Body, SectionHeader, FormSection, colStyle } = SH;
  const e = React.createElement;

  const notifDot = { position: 'absolute', top: 6, right: 6, minWidth: 16, height: 16, padding: '0 4px', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', background: 'var(--amber-400)', color: '#3a2600', borderRadius: '999px', fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 10, border: '2px solid #0a8c84' };
  const quickBtn = { display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, border: 'none', background: 'transparent', cursor: 'pointer', padding: 0 };
  const quickIcon = { display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 52, height: 52, borderRadius: 'var(--radius-md)', background: 'var(--color-primary-soft)' };

  function QuickActions({ nav }) {
    const items = [['add_box', 'Nouveau', () => nav('new')], ['sell', 'Libre service', () => nav('libre')], ['qr_code_2', 'Suivre', () => nav('detail')], ['history', 'Historique', () => nav('colis')]];
    return e('div', { style: { display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 10 } },
      items.map(([ic, lb, fn], i) => e('button', { key: i, onClick: fn, style: quickBtn },
        e('span', { style: quickIcon }, e('span', { className: 'material-symbols-rounded', style: { fontSize: 24, color: 'var(--color-primary)', fontVariationSettings: "'FILL' 1" } }, ic)),
        e('span', { style: { fontSize: 11.5, fontWeight: 600, color: 'var(--text-body)' } }, lb))));
  }

  function PointsCard({ nav, inverse }) {
    return e('div', { onClick: () => nav('wallet'), style: { cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 14, padding: 14, background: inverse ? 'rgba(255,255,255,.14)' : 'var(--surface-card)', border: inverse ? 'none' : '1px solid var(--border-subtle)', borderRadius: 'var(--radius-lg)', backdropFilter: inverse ? 'blur(4px)' : 'none', boxShadow: inverse ? 'none' : 'var(--shadow-xs)' } },
      e('span', { style: { display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 44, height: 44, borderRadius: 'var(--radius-md)', background: inverse ? 'rgba(255,255,255,.18)' : 'var(--amber-50)' } },
        e('span', { className: 'material-symbols-rounded', style: { fontSize: 24, color: inverse ? '#fff' : 'var(--amber-500)', fontVariationSettings: "'FILL' 1" } }, 'account_balance_wallet')),
      e('div', { style: { flex: 1 } },
        e('div', { style: { fontSize: 11.5, opacity: inverse ? .85 : 1, color: inverse ? '#fff' : 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '.07em', fontWeight: 700 } }, 'Solde de points'),
        e('div', { style: { fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 23, marginTop: 1, color: inverse ? '#fff' : 'var(--text-strong)' } }, M.user.points, e('span', { style: { fontSize: 14, opacity: .8 } }, ' pts'))),
      e(Button, { variant: 'amber', size: 'sm', icon: 'add', onClick: (ev) => { ev.stopPropagation(); nav('wallet'); } }, 'Recharger'),
    );
  }

  // =====================================================================
  // HOME — 3 variants (Tweak: homeVariant)
  // =====================================================================
  function HomeScreen({ nav, unread, variant = 'hero' }) {
    const header = e('div', { style: { display: 'flex', alignItems: 'center', gap: 12 } },
      e(Avatar, { name: M.user.name, status: 'online' }),
      e('div', { style: { flex: 1, minWidth: 0 } },
        e('div', { style: { fontSize: 12.5, opacity: variant === 'hero' ? .85 : 1, color: variant === 'hero' ? '#fff' : 'var(--text-muted)' } }, 'Bonjour,'),
        e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 17, color: variant === 'hero' ? '#fff' : 'var(--text-strong)' } }, M.user.name)),
      e(IconButton, { icon: 'search', variant: 'ghost', style: { color: variant === 'hero' ? '#fff' : 'var(--text-body)' } }),
      e('span', { style: { position: 'relative' } },
        e(IconButton, { icon: 'notifications', variant: 'ghost', style: { color: variant === 'hero' ? '#fff' : 'var(--text-body)' }, onClick: () => nav('notifications') }),
        unread ? e('span', { style: notifDot }, unread) : null));

    const kpis = e('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 } },
      e(StatBox, { icon: 'package_2', tone: 'primary', value: '3', label: 'Colis en cours' }),
      e(StatBox, { icon: 'task_alt', tone: 'green', value: '28', label: 'Colis livrés' }));

    const recent = e('div', null,
      e(SectionHeader, { title: 'Mes colis récents', action: 'Tout voir', onAction: () => nav('colis') }),
      e('div', { style: { display: 'flex', flexDirection: 'column', gap: 12 } },
        M.parcels.slice(0, 2).map((p) => e(ParcelCard, { key: p.id, parcel: p, onClick: () => nav('detail'),
          footer: p.status === 'free' ? e(Button, { block: true, variant: 'secondary', size: 'sm', iconTrailing: 'chevron_right', onClick: (ev) => { ev.stopPropagation(); nav('libre'); } }, `${p.offers} offres reçues`) : null }))));

    // active parcel mini-tracker (used by 'focus')
    const active = M.parcels[0];
    const activeCard = e('div', { onClick: () => nav('detail'), style: { cursor: 'pointer', background: 'var(--gradient-brand)', borderRadius: 'var(--radius-lg)', padding: 16, color: '#fff', boxShadow: 'var(--shadow-brand)' } },
      e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between' } },
        e('span', { style: { fontFamily: 'var(--font-mono)', fontWeight: 600, fontSize: 13 } }, active.tracking),
        e(StatusBadge, { status: active.status, size: 'sm', style: { background: 'rgba(255,255,255,.92)' } })),
      e('div', { style: { display: 'flex', alignItems: 'center', gap: 10, marginTop: 14 } },
        e('div', null, e('div', { style: { fontSize: 10.5, opacity: .8, textTransform: 'uppercase', letterSpacing: '.06em', fontWeight: 700 } }, 'De'), e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 16 } }, active.from)),
        e('div', { style: { flex: 1, position: 'relative', height: 2, background: 'rgba(255,255,255,.4)' } },
          e('span', { className: 'material-symbols-rounded', style: { position: 'absolute', left: '52%', top: -11, fontSize: 22, color: '#fff' } }, 'local_shipping')),
        e('div', { style: { textAlign: 'right' } }, e('div', { style: { fontSize: 10.5, opacity: .8, textTransform: 'uppercase', letterSpacing: '.06em', fontWeight: 700 } }, 'À'), e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 16 } }, active.to))),
      e('div', { style: { display: 'flex', justifyContent: 'space-between', marginTop: 14, fontSize: 12, opacity: .92 } },
        e('span', null, 'Chauffeur · ', active.driver), e('span', { style: { fontFamily: 'var(--font-mono)' } }, 'Reste ', active.eta)));

    // ---- variant: compact (light header) ----
    if (variant === 'compact') {
      return e('div', { style: colStyle },
        e('div', { style: { padding: '46px 16px 8px', background: 'var(--surface-card)', borderBottom: '1px solid var(--border-subtle)' } }, header),
        e('div', { style: { flex: 1, overflowY: 'auto', padding: '16px 16px 96px', display: 'flex', flexDirection: 'column', gap: 20 } },
          e(QuickActions, { nav }),
          e(PointsCard, { nav }),
          kpis,
          recent,
        ),
      );
    }

    // ---- variant: focus (active parcel first) ----
    if (variant === 'focus') {
      return e('div', { style: colStyle },
        e('div', { style: { padding: '46px 16px 8px', background: 'var(--surface-card)', borderBottom: '1px solid var(--border-subtle)' } }, header),
        e('div', { style: { flex: 1, overflowY: 'auto', padding: '16px 16px 96px', display: 'flex', flexDirection: 'column', gap: 18 } },
          e('div', null, e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 13, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '.06em', margin: '2px 2px 10px' } }, 'En cours de livraison'), activeCard),
          e(QuickActions, { nav }),
          e(PointsCard, { nav }),
          recent,
        ),
      );
    }

    // ---- variant: hero (default brand gradient) ----
    return e('div', { style: colStyle },
      e('div', { style: { background: 'var(--gradient-brand)', padding: '52px 16px 22px', color: '#fff' } },
        header,
        e('div', { style: { marginTop: 16 } }, e(PointsCard, { nav, inverse: true }))),
      e('div', { style: { flex: 1, overflowY: 'auto', padding: '18px 16px 96px', display: 'flex', flexDirection: 'column', gap: 22 } },
        e(QuickActions, { nav }),
        kpis,
        recent,
      ),
    );
  }

  // =====================================================================
  // MES COLIS
  // =====================================================================
  function MesColisScreen({ nav }) {
    const [tab, setTab] = React.useState('cours');
    const filterMap = { cours: ['pending', 'free', 'confirmed', 'pickup', 'transit', 'arrived', 'delivering'], livres: ['delivered'], annules: ['cancelled'] };
    const list = M.parcels.filter((p) => filterMap[tab].includes(p.status));
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Mes colis', actions: e(IconButton, { icon: 'tune' }) }),
      e('div', { style: { padding: '0 16px', background: 'var(--surface-card)', borderBottom: '1px solid var(--border-subtle)' } },
        e(Tabs, { value: tab, onChange: setTab, items: [{ value: 'cours', label: 'En cours', count: 3 }, { value: 'livres', label: 'Livrés', count: 1 }, { value: 'annules', label: 'Annulés' }] })),
      e(Body, null,
        list.length ? e('div', { style: { display: 'flex', flexDirection: 'column', gap: 12 } },
          list.map((p) => e(ParcelCard, { key: p.id, parcel: p, onClick: () => nav('detail') })))
          : e(EmptyState, { icon: 'inbox', title: 'Aucun colis ici', message: 'Vos colis de cette catégorie apparaîtront ici.', action: e(Button, { icon: 'add', onClick: () => nav('new') }, 'Nouveau colis') }),
      ),
    );
  }

  // =====================================================================
  // NOUVEAU COLIS
  // =====================================================================
  function NewParcelScreen({ nav }) {
    const [insurance, setInsurance] = React.useState(true);
    const [urgent, setUrgent] = React.useState(false);
    const [terms, setTerms] = React.useState(false);
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Nouveau colis', subtitle: 'Étape 1 sur 2', onBack: () => nav('home') }),
      e(Body, { style: { gap: 18 } },
        e(FormSection, { title: 'Trajet', icon: 'route' },
          e('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 } },
            e(Select, { label: 'Départ', icon: 'trip_origin', options: M.cities, placeholder: 'Ville' }),
            e(Select, { label: 'Arrivée', icon: 'pin_drop', options: M.cities, placeholder: 'Ville' }))),
        e(FormSection, { title: 'Destinataire', icon: 'person_pin' },
          e(Input, { label: 'Nom complet', icon: 'badge', placeholder: 'Ex : Moussa Traoré' }),
          e(Input, { label: 'Téléphone', icon: 'call', placeholder: '07 00 00 00', mono: true })),
        e(FormSection, { title: 'Colis', icon: 'package_2' },
          e('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 } },
            e(Select, { label: 'Type', icon: 'category', options: M.parcelTypes, placeholder: 'Type' }),
            e(Input, { label: 'Poids', suffix: 'kg', placeholder: '8', mono: true })),
          e(Input, { label: 'Description (optionnel)', icon: 'description', placeholder: 'Contenu du colis' })),
        e(FormSection, { title: 'Options', icon: 'tune' },
          e(Switch, { checked: insurance, onChange: setInsurance, label: 'Assurance', description: 'Couvre jusqu’à 200 000 FCFA' }),
          e(Switch, { checked: urgent, onChange: setUrgent, label: 'Livraison urgente (express)', description: 'Priorité haute, supplément 2 000 FCFA' })),
        e(Card, { padding: 'md', style: { background: 'var(--color-primary-soft)', border: '1px solid var(--teal-100)' } },
          e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between' } },
            e('div', null,
              e('div', { style: { fontSize: 12.5, color: 'var(--teal-700)', fontWeight: 600 } }, 'Prix estimé'),
              e('div', { style: { fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 24, color: 'var(--teal-700)' } }, urgent ? '14 500 FCFA' : '12 500 FCFA')),
            urgent ? e(Tag, { express: true }) : e(Tag, null, 'Standard'))),
        e(Checkbox, { checked: terms, onChange: setTerms, label: 'J’accepte les conditions de transport.' }),
        e(Button, { block: true, size: 'lg', disabled: !terms, onClick: () => nav('libre'), icon: 'sell' }, 'Publier en libre service'),
        e(Button, { block: true, variant: 'ghost', onClick: () => nav('home') }, 'Enregistrer comme brouillon'),
      ),
    );
  }

  // =====================================================================
  // NOTIFICATIONS
  // =====================================================================
  function NotificationsScreen({ nav }) {
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Notifications', onBack: () => nav('home'), actions: e(IconButton, { icon: 'done_all' }) }),
      e(Body, { style: { padding: '8px 12px 96px' } },
        M.notifications.map((n) => e('div', { key: n.id, style: { position: 'relative' } },
          e(ListRow, { icon: n.icon, iconTone: n.tone, title: n.title, subtitle: n.body,
            trailing: e('span', { style: { fontSize: 11.5, color: 'var(--text-faint)', whiteSpace: 'nowrap' } }, n.when),
            style: n.unread ? { background: 'var(--color-primary-soft)' } : null }),
          n.unread ? e('span', { style: { position: 'absolute', left: 4, top: '50%', width: 6, height: 6, borderRadius: '50%', background: 'var(--color-primary)' } }) : null)),
      ),
    );
  }

  // =====================================================================
  // PROFIL
  // =====================================================================
  function ProfileScreen({ nav }) {
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Profil', actions: e(IconButton, { icon: 'settings', onClick: () => nav('settings') }) }),
      e(Body, { style: { gap: 18 } },
        e('div', { style: { display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, paddingTop: 6 } },
          e(Avatar, { name: M.user.name, size: 'xl', status: 'online' }),
          e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 21, color: 'var(--text-strong)' } }, M.user.name),
          e('div', { style: { fontFamily: 'var(--font-mono)', fontSize: 13, color: 'var(--text-muted)' } }, M.user.phone),
          e(Badge, { tone: 'primary', icon: 'verified' }, 'Compte vérifié')),
        e('div', { style: { display: 'flex', gap: 10 } },
          e(StatBox, { icon: 'account_balance_wallet', tone: 'amber', value: '2 450', label: 'Points', style: { flex: 1 } }),
          e(StatBox, { icon: 'package_2', tone: 'primary', value: '31', label: 'Colis envoyés', style: { flex: 1 } })),
        e(Card, { padding: 'sm' },
          e(ListRow, { icon: 'person', iconTone: 'neutral', title: 'Informations personnelles', chevron: true }),
          e(Divider),
          e(ListRow, { icon: 'location_on', iconTone: 'neutral', title: 'Adresses', subtitle: `${M.user.city}, Côte d’Ivoire`, chevron: true }),
          e(Divider),
          e(ListRow, { icon: 'account_balance_wallet', iconTone: 'amber', title: 'Points & paiements', trailing: e(Badge, { tone: 'amber' }, '2 450 pts'), chevron: true, onClick: () => nav('wallet') }),
          e(Divider),
          e(ListRow, { icon: 'pin', iconTone: 'neutral', title: 'Code PIN', subtitle: 'Connexion rapide activée', chevron: true })),
        e(Card, { padding: 'sm' },
          e(ListRow, { icon: 'settings', iconTone: 'neutral', title: 'Paramètres', chevron: true, onClick: () => nav('settings') }),
          e(Divider),
          e(ListRow, { icon: 'help', iconTone: 'neutral', title: 'Aide & support', chevron: true, onClick: () => nav('help') }),
          e(Divider),
          e(ListRow, { icon: 'logout', iconTone: 'neutral', title: 'Se déconnecter', onClick: () => nav('login') })),
        e('div', { style: { textAlign: 'center', fontSize: 11.5, color: 'var(--text-faint)', fontFamily: 'var(--font-mono)' } }, 'PRO COLIS · v1.0.0'),
      ),
    );
  }
  function Divider() { return e('div', { style: { height: 1, background: 'var(--border-subtle)', margin: '0 14px' } }); }

  window.PCScreens = Object.assign(window.PCScreens || {}, { HomeScreen, MesColisScreen, NewParcelScreen, NotificationsScreen, ProfileScreen });
  window.PCParts = Object.assign(window.PCParts || {}, { Divider });
})();
