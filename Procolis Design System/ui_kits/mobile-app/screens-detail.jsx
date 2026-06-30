/* Procolis mobile UI kit — detail screens. window.PCScreens.* */
(function () {
  const NS = window.ProcolisDesignSystem_1720b4;
  const { AppBar, IconButton, Button, Input, Card, StatBox, Badge, StatusBadge, Tag,
          Avatar, ListRow, ParcelCard, Stepper, Toast, EmptyState, Tabs, Switch, SegmentedControl } = NS;
  const M = window.PCMock;
  const e = React.createElement;
  const Body = window.PCScreens.Body;
  const SectionHeader = window.PCScreens.SectionHeader;
  const colStyle = window.PCScreens.colStyle;

  // =====================================================================
  // TRACK / PARCEL DETAIL
  // =====================================================================
  function TrackScreen({ nav }) {
    const p = M.parcels[0];
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Suivi du colis', onBack: () => nav('home'), actions: e(IconButton, { icon: 'share' }) }),
      e(Body, { style: { gap: 16 } },
        // tracking hero
        e('div', { style: { background: 'var(--gradient-brand)', borderRadius: 'var(--radius-lg)', padding: 18, color: '#fff', boxShadow: 'var(--shadow-brand)' } },
          e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between' } },
            e('span', { style: { display: 'inline-flex', alignItems: 'center', gap: 6 } },
              e('span', { className: 'material-symbols-rounded', style: { fontSize: 18 } }, 'qr_code_2'),
              e('span', { style: { fontFamily: 'var(--font-mono)', fontWeight: 600, fontSize: 14 } }, p.tracking)),
            e(StatusBadge, { status: p.status, size: 'sm', style: { background: 'rgba(255,255,255,.9)' } })),
          e('div', { style: { display: 'flex', alignItems: 'center', gap: 12, marginTop: 16 } },
            e(RouteEnd, { label: 'Départ', city: p.from }),
            e('div', { style: { flex: 1, position: 'relative', height: 2, background: 'rgba(255,255,255,.4)' } },
              e('span', { className: 'material-symbols-rounded', style: { position: 'absolute', left: '55%', top: -12, fontSize: 24, color: '#fff', filter: 'drop-shadow(0 2px 4px rgba(0,0,0,.2))' } }, 'local_shipping')),
            e(RouteEnd, { label: 'Arrivée', city: p.to, right: true })),
          e('div', { style: { display: 'flex', gap: 16, marginTop: 16, fontSize: 12.5 } },
            e(HeroMeta, { label: 'Distance', value: '350 km' }),
            e(HeroMeta, { label: 'Temps restant', value: '~4 h' }),
            e(HeroMeta, { label: 'Prix', value: p.price })),
        ),
        // driver card
        e(Card, { padding: 'sm' },
          e(ListRow, { leading: e(Avatar, { name: p.driver, status: 'online' }), title: p.driver, subtitle: 'Garage de Cocody · 4,9 ★ · Toyota Hiace',
            trailing: e('div', { style: { display: 'flex', gap: 6 } }, e(IconButton, { icon: 'call', variant: 'soft' }), e(IconButton, { icon: 'chat', variant: 'soft' })) }),
        ),
        // timeline
        e('div', null,
          e(SectionHeader, { title: 'Historique' }),
          e(Card, { padding: 'md' }, e(Stepper, { steps: M.timeline })),
        ),
        e('div', { style: { display: 'flex', gap: 10 } },
          e(Button, { block: true, variant: 'secondary', icon: 'description' }, 'Voir le reçu'),
          e(Button, { block: true, variant: 'danger', icon: 'cancel' }, 'Annuler'),
        ),
      ),
    );
  }
  function RouteEnd({ label, city, right }) {
    return e('div', { style: { textAlign: right ? 'right' : 'left' } },
      e('div', { style: { fontSize: 10.5, opacity: .8, textTransform: 'uppercase', letterSpacing: '.07em', fontWeight: 700 } }, label),
      e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 17 } }, city));
  }
  function HeroMeta({ label, value }) {
    return e('div', null,
      e('div', { style: { opacity: .8 } }, label),
      e('div', { style: { fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 14, marginTop: 1 } }, value));
  }

  // =====================================================================
  // LIBRE SERVICE — client view: offers received on a parcel
  // =====================================================================
  function LibreServiceScreen({ nav }) {
    const [role, setRole] = React.useState('client');
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Libre service', actions: e(IconButton, { icon: 'tune' }) }),
      e('div', { style: { padding: '12px 16px 0', background: 'var(--surface-card)' } },
        e(SegmentedControl, { block: true, value: role, onChange: setRole, options: [{ value: 'client', label: 'Mes offres reçues', icon: 'inbox' }, { value: 'driver', label: 'Colis à prendre', icon: 'local_shipping' }] })),
      role === 'client' ? e(ClientOffers, { nav }) : e(DriverPool, { nav }),
    );
  }

  function ClientOffers({ nav }) {
    const p = M.parcels[1];
    const [accepted, setAccepted] = React.useState(null);
    return e(Body, { style: { gap: 14, paddingTop: 16 } },
      e(ParcelCard, { parcel: p }),
      e(SectionHeader, { title: `${M.offers.length} offres reçues` }),
      e('div', { style: { display: 'flex', flexDirection: 'column', gap: 12 } },
        M.offers.map((o) => e(Card, { key: o.id, padding: 'md', style: accepted === o.id ? { border: '2px solid var(--color-primary)' } : null },
          e('div', { style: { display: 'flex', gap: 12 } },
            e(Avatar, { name: o.driver, status: 'online' }),
            e('div', { style: { flex: 1, minWidth: 0 } },
              e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between' } },
                e('span', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 15, color: 'var(--text-strong)' } }, o.driver),
                e('span', { style: { fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 17, color: 'var(--teal-600)' } }, o.price)),
              e('div', { style: { fontSize: 12.5, color: 'var(--text-muted)', marginTop: 1 } }, `${o.garage} · ${o.rating} ★`),
              e('div', { style: { display: 'flex', alignItems: 'center', gap: 8, marginTop: 10, padding: '8px 10px', background: 'var(--surface-sunken)', borderRadius: 'var(--radius-sm)' } },
                o.hasAudio
                  ? e('span', { style: { display: 'inline-flex', alignItems: 'center', gap: 8, color: 'var(--color-primary)' } },
                      e('span', { className: 'material-symbols-rounded', style: { fontSize: 22 } }, 'play_circle'),
                      e(Waveform),
                      e('span', { style: { fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--text-muted)' } }, "0:08"))
                  : e('span', { style: { fontSize: 13, color: 'var(--text-body)', fontStyle: 'italic' } }, `“${o.message}”`)),
              e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 10 } },
                e('span', { style: { fontSize: 11.5, color: 'var(--text-faint)' } }, o.when),
                e('div', { style: { display: 'flex', gap: 8 } },
                  e(Button, { size: 'sm', variant: 'secondary' }, 'Négocier'),
                  e(Button, { size: 'sm', icon: 'check', onClick: () => setAccepted(o.id) }, 'Accepter'))),
            ),
          ),
        )),
      ),
    );
  }
  function Waveform() {
    const bars = [8, 14, 20, 12, 18, 24, 10, 16, 22, 9, 14, 18, 11];
    return e('span', { style: { display: 'inline-flex', alignItems: 'center', gap: 2, height: 24 } },
      bars.map((h, i) => e('span', { key: i, style: { width: 2.5, height: h, borderRadius: 2, background: i < 5 ? 'var(--color-primary)' : 'var(--teal-200)' } })));
  }

  function DriverPool({ nav }) {
    return e(Body, { style: { gap: 12, paddingTop: 16 } },
      e('div', { style: { display: 'flex', gap: 8, marginBottom: 4, overflowX: 'auto' } },
        ['Tous', 'Abidjan →', 'Express', '< 10 kg', 'Aujourd’hui'].map((f, i) =>
          e(Tag, { key: i, tone: i === 0 ? 'primary' : 'neutral' }, f))),
      M.freeParcels.map((p) => e(ParcelCard, {
        key: p.id, parcel: p,
        footer: e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between' } },
          e('span', { style: { fontSize: 12.5, color: 'var(--text-muted)' } }, e('span', { className: 'material-symbols-rounded', style: { fontSize: 15, verticalAlign: '-3px', marginRight: 3 } }, 'route'), p.distance, ' · ', p.offers, ' offres'),
          e(Button, { size: 'sm', icon: 'gavel' }, 'Faire une offre')),
      })),
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
          e(ListRow, {
            icon: n.icon, iconTone: n.tone, title: n.title, subtitle: n.body,
            trailing: e('span', { style: { fontSize: 11.5, color: 'var(--text-faint)', whiteSpace: 'nowrap' } }, n.when),
            style: n.unread ? { background: 'var(--color-primary-soft)' } : null,
          }),
          n.unread ? e('span', { style: { position: 'absolute', left: 4, top: '50%', width: 6, height: 6, borderRadius: '50%', background: 'var(--color-primary)' } }) : null,
        )),
      ),
    );
  }

  // =====================================================================
  // PROFILE
  // =====================================================================
  function ProfileScreen({ nav }) {
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Profil', actions: e(IconButton, { icon: 'edit' }) }),
      e(Body, { style: { gap: 18 } },
        e('div', { style: { display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, paddingTop: 6 } },
          e(Avatar, { name: M.user.name, size: 'xl', status: 'online' }),
          e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 21, color: 'var(--text-strong)' } }, M.user.name),
          e('div', { style: { fontFamily: 'var(--font-mono)', fontSize: 13, color: 'var(--text-muted)' } }, M.user.phone),
          e(Badge, { tone: 'primary', icon: 'verified' }, 'Compte vérifié')),
        // points strip
        e('div', { style: { display: 'flex', gap: 10 } },
          e(StatBox, { icon: 'account_balance_wallet', tone: 'amber', value: '2 450', label: 'Points', style: { flex: 1 } }),
          e(StatBox, { icon: 'package_2', tone: 'primary', value: '31', label: 'Colis envoyés', style: { flex: 1 } })),
        e(Card, { padding: 'sm' },
          e(ListRow, { icon: 'person', iconTone: 'neutral', title: 'Informations personnelles', chevron: true }),
          e(Divider),
          e(ListRow, { icon: 'location_on', iconTone: 'neutral', title: 'Adresses', subtitle: `${M.user.city}, Côte d’Ivoire`, chevron: true }),
          e(Divider),
          e(ListRow, { icon: 'account_balance_wallet', iconTone: 'amber', title: 'Points & paiements', trailing: e(Badge, { tone: 'amber' }, '2 450 pts'), chevron: true }),
          e(Divider),
          e(ListRow, { icon: 'pin', iconTone: 'neutral', title: 'Code PIN', subtitle: 'Connexion rapide activée', chevron: true }),
        ),
        e(Card, { padding: 'sm' },
          e(ListRow, { icon: 'notifications', iconTone: 'neutral', title: 'Notifications', trailing: e(Switch, { checked: true, onChange: () => {} }) }),
          e(Divider),
          e(ListRow, { icon: 'help', iconTone: 'neutral', title: 'Aide & support', chevron: true }),
          e(Divider),
          e(ListRow, { icon: 'logout', iconTone: 'neutral', title: 'Se déconnecter', onClick: () => nav('login') }),
        ),
        e('div', { style: { textAlign: 'center', fontSize: 11.5, color: 'var(--text-faint)', fontFamily: 'var(--font-mono)' } }, 'PRO COLIS · v1.0.0'),
      ),
    );
  }
  function Divider() { return e('div', { style: { height: 1, background: 'var(--border-subtle)', margin: '0 14px' } }); }

  window.PCScreens = Object.assign(window.PCScreens || {}, { TrackScreen, LibreServiceScreen, NotificationsScreen, ProfileScreen });
})();
