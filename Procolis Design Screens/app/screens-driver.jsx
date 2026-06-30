/* PRO COLIS — chauffeur (driver) screens. window.PCScreens.* */
(function () {
  const NS = window.ProcolisDesignSystem_1720b4;
  const { AppBar, IconButton, Button, Input, Select, Textarea, Card, StatBox, Badge, StatusBadge, Tag,
          Avatar, ListRow, ParcelCard, Stepper, Switch, SegmentedControl, Tabs, EmptyState } = NS;
  const M = window.PCMock;
  const SH = window.PCShared;
  const { Body, SectionHeader, FormSection, colStyle } = SH;
  const Divider = () => React.createElement('div', { style: { height: 1, background: 'var(--border-subtle)', margin: '0 14px' } });
  const e = React.createElement;
  const D = M.driver;

  const notifDot = { position: 'absolute', top: 6, right: 6, minWidth: 16, height: 16, padding: '0 4px', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', background: 'var(--amber-400)', color: '#3a2600', borderRadius: '999px', fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 10, border: '2px solid #0a8c84' };

  // =====================================================================
  // TABLEAU DE BORD — driver home
  // =====================================================================
  function DriverHomeScreen({ nav, unread }) {
    const [online, setOnline] = React.useState(true);
    return e('div', { style: colStyle },
      e('div', { style: { background: 'var(--gradient-brand)', padding: '52px 16px 22px', color: '#fff' } },
        e('div', { style: { display: 'flex', alignItems: 'center', gap: 12 } },
          e(Avatar, { name: D.name, status: online ? 'online' : 'offline' }),
          e('div', { style: { flex: 1, minWidth: 0 } },
            e('div', { style: { fontSize: 12.5, opacity: .85 } }, 'Chauffeur'),
            e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 17 } }, D.name)),
          e('span', { style: { position: 'relative' } },
            e(IconButton, { icon: 'notifications', variant: 'ghost', style: { color: '#fff' }, onClick: () => nav('notifications') }),
            unread ? e('span', { style: notifDot }, unread) : null)),
        // availability toggle
        e('div', { style: { display: 'flex', alignItems: 'center', gap: 12, marginTop: 16, padding: 14, background: 'rgba(255,255,255,.14)', borderRadius: 'var(--radius-lg)', backdropFilter: 'blur(4px)' } },
          e('span', { style: { display: 'inline-flex', width: 44, height: 44, borderRadius: 'var(--radius-md)', background: 'rgba(255,255,255,.18)', alignItems: 'center', justifyContent: 'center' } },
            e('span', { className: 'material-symbols-rounded', style: { fontSize: 24, fontVariationSettings: "'FILL' 1" } }, online ? 'bolt' : 'bedtime')),
          e('div', { style: { flex: 1 } },
            e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 15 } }, online ? 'Vous êtes en ligne' : 'Hors ligne'),
            e('div', { style: { fontSize: 12, opacity: .85 } }, online ? 'Vous recevez les colis disponibles' : 'Vous ne recevez pas de colis')),
          e(Switch, { checked: online, onChange: setOnline })),
      ),
      e('div', { style: { flex: 1, overflowY: 'auto', padding: '18px 16px 96px', display: 'flex', flexDirection: 'column', gap: 22 } },
        // publish a trip CTA
        e('button', { onClick: () => nav('dtrip'), style: { display: 'flex', alignItems: 'center', gap: 12, width: '100%', textAlign: 'left', padding: 14, background: 'var(--teal-50)', border: '1px solid var(--teal-200)', borderRadius: 'var(--radius-lg)', cursor: 'pointer' } },
          e('span', { style: { display: 'inline-flex', width: 44, height: 44, flex: 'none', borderRadius: 'var(--radius-md)', background: 'var(--color-primary)', alignItems: 'center', justifyContent: 'center' } },
            e('span', { className: 'material-symbols-rounded', style: { fontSize: 24, color: '#fff', fontVariationSettings: "'FILL' 1" } }, 'campaign')),
          e('div', { style: { flex: 1, minWidth: 0 } },
            e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 15, color: 'var(--text-strong)' } }, 'Publier un voyage'),
            e('div', { style: { fontSize: 12.5, color: 'var(--text-muted)' } }, 'Annoncez votre trajet aux clients')),
          e('span', { className: 'material-symbols-rounded', style: { fontSize: 22, color: 'var(--color-primary)' } }, 'chevron_right')),
        e('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 } },
          e(StatBox, { icon: 'account_balance_wallet', tone: 'amber', value: D.points, label: 'Points gagnés' }),
          e(StatBox, { icon: 'local_shipping', tone: 'primary', value: '2', label: 'Missions actives' })),
        e('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 } },
          e(StatBox, { icon: 'task_alt', tone: 'green', value: String(D.deliveries), label: 'Livraisons' }),
          e(StatBox, { icon: 'star', tone: 'amber', value: D.rating, label: 'Note moyenne' })),
        // active mission
        e('div', null,
          e(SectionHeader, { title: 'Mission en cours', action: 'Voir tout', onAction: () => nav('dmissions') }),
          e(ParcelCard, { parcel: M.missions[0], onClick: () => nav('mission'),
            footer: e(Button, { block: true, size: 'sm', iconTrailing: 'arrow_forward', onClick: (ev) => { ev.stopPropagation(); nav('mission'); } }, 'Continuer la livraison') })),
        // available pool teaser
        e('div', null,
          e(SectionHeader, { title: 'Colis à prendre', action: 'Tout voir', onAction: () => nav('dpool') }),
          e('div', { style: { display: 'flex', flexDirection: 'column', gap: 12 } },
            M.freeParcels.slice(0, 2).map((p) => e(ParcelCard, { key: p.id, parcel: p,
              footer: e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between' } },
                e('span', { style: { fontSize: 12.5, color: 'var(--text-muted)' } }, e('span', { className: 'material-symbols-rounded', style: { fontSize: 15, verticalAlign: '-3px', marginRight: 3 } }, 'route'), p.distance),
                e(Button, { size: 'sm', icon: 'gavel', onClick: () => nav('offer') }, 'Faire une offre')) })))),
      ),
    );
  }

  // =====================================================================
  // COLIS À PRENDRE — libre service pool (driver)
  // =====================================================================
  function DriverPoolScreen({ nav }) {
    const [filter, setFilter] = React.useState('Tous');
    const filters = ['Tous', 'Abidjan →', 'Express', '< 10 kg', 'Aujourd’hui'];
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Colis à prendre', actions: e(IconButton, { icon: 'tune' }) }),
      e('div', { style: { display: 'flex', gap: 8, padding: '12px 16px 4px', overflowX: 'auto', background: 'var(--surface-card)', borderBottom: '1px solid var(--border-subtle)' } },
        filters.map((f) => e('button', { key: f, onClick: () => setFilter(f), style: { flex: 'none', cursor: 'pointer', border: 'none', background: 'transparent', padding: 0 } },
          e(Tag, { tone: filter === f ? 'primary' : 'neutral' }, f)))),
      e(Body, { style: { gap: 12 } },
        M.freeParcels.map((p) => e(ParcelCard, { key: p.id, parcel: p,
          footer: e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between' } },
            e('span', { style: { fontSize: 12.5, color: 'var(--text-muted)' } }, e('span', { className: 'material-symbols-rounded', style: { fontSize: 15, verticalAlign: '-3px', marginRight: 3 } }, 'route'), p.distance, ' · ', p.offers, ' offres'),
            e(Button, { size: 'sm', icon: 'gavel', onClick: () => nav('offer') }, 'Faire une offre')) })),
      ),
    );
  }

  // =====================================================================
  // FAIRE UNE OFFRE — price + message + voice note
  // =====================================================================
  function MakeOfferScreen({ nav }) {
    const p = M.freeParcels[1];
    const [price, setPrice] = React.useState('13 000');
    const [recording, setRecording] = React.useState(false);
    const [recorded, setRecorded] = React.useState(false);
    const [sent, setSent] = React.useState(false);
    if (sent) {
      return e('div', { style: { ...colStyle, alignItems: 'center', justifyContent: 'center', padding: 28, textAlign: 'center' } },
        e('div', { className: 'pc-pop', style: { width: 92, height: 92, borderRadius: '50%', background: 'var(--teal-50)', display: 'flex', alignItems: 'center', justifyContent: 'center' } },
          e('span', { className: 'material-symbols-rounded', style: { fontSize: 54, color: 'var(--color-primary)', fontVariationSettings: "'FILL' 1" } }, 'gavel')),
        e('h2', { style: { ...SH.titleStyle, marginTop: 22 } }, 'Offre envoyée !'),
        e('p', { style: { ...SH.subStyle, maxWidth: 290 } }, 'Le client a reçu votre proposition de ', e('span', { style: { fontFamily: 'var(--font-mono)', fontWeight: 600 } }, `${price} FCFA`), '. Vous serez notifié de sa réponse.'),
        e('div', { style: { display: 'flex', flexDirection: 'column', gap: 10, marginTop: 26, width: '100%', maxWidth: 280 } },
          e(Button, { block: true, size: 'lg', onClick: () => nav('dpool') }, 'Voir d’autres colis'),
          e(Button, { block: true, variant: 'ghost', onClick: () => nav('dhome') }, 'Tableau de bord')),
      );
    }
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Faire une offre', onBack: () => nav('dpool') }),
      e(Body, { style: { gap: 18 } },
        e(ParcelCard, { parcel: p }),
        e('div', null,
          e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 14, color: 'var(--text-strong)', marginBottom: 8 } }, 'Votre prix'),
          e('div', { style: { display: 'flex', alignItems: 'center', gap: 10, padding: '0 16px', height: 60, background: 'var(--surface-card)', border: '2px solid var(--color-primary)', borderRadius: 'var(--radius-md)' } },
            e('input', { value: price, onChange: (ev) => setPrice(ev.target.value), style: { flex: 1, border: 'none', outline: 'none', fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 28, color: 'var(--text-strong)', background: 'transparent', minWidth: 0 } }),
            e('span', { style: { fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 16, color: 'var(--text-muted)' } }, 'FCFA')),
          e('div', { style: { fontSize: 12, color: 'var(--text-muted)', marginTop: 6 } }, 'Prix proposé par le client : ', e('span', { style: { fontFamily: 'var(--font-mono)' } }, p.price))),
        e(Textarea, { label: 'Message au client (optionnel)', rows: 3, maxLength: 160, placeholder: 'Ex : Je pars cet après-midi, livraison ce soir.' }),
        // voice note recorder
        e('div', null,
          e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 14, color: 'var(--text-strong)', marginBottom: 8 } }, 'Note vocale (optionnel)'),
          recorded
            ? e('div', { style: { display: 'flex', alignItems: 'center', gap: 10, padding: 12, background: 'var(--surface-card)', border: '1px solid var(--border-subtle)', borderRadius: 'var(--radius-md)' } },
                e('span', { className: 'material-symbols-rounded', style: { fontSize: 28, color: 'var(--color-primary)' } }, 'play_circle'),
                e(SH.Waveform, { active: 9 }),
                e('span', { style: { fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--text-muted)', flex: 1 } }, '0:09'),
                e(IconButton, { icon: 'delete', variant: 'ghost', onClick: () => setRecorded(false) }))
            : e('button', { onClick: () => { if (recording) { setRecording(false); setRecorded(true); } else setRecording(true); }, style: { width: '100%', display: 'flex', alignItems: 'center', gap: 12, padding: 14, background: recording ? 'var(--red-50)' : 'var(--surface-card)', border: `1px solid ${recording ? 'var(--red-200)' : 'var(--border-subtle)'}`, borderRadius: 'var(--radius-md)', cursor: 'pointer' } },
                e('span', { className: 'material-symbols-rounded' + (recording ? ' pc-pulse' : ''), style: { fontSize: 26, color: recording ? 'var(--color-express)' : 'var(--color-primary)', fontVariationSettings: "'FILL' 1" } }, 'mic'),
                e('span', { style: { fontSize: 14, fontWeight: 600, color: recording ? 'var(--color-express)' : 'var(--text-body)' } }, recording ? 'Enregistrement… touchez pour arrêter' : 'Enregistrer une note vocale'))),
        e(Button, { block: true, size: 'lg', icon: 'send', onClick: () => setSent(true) }, 'Envoyer l’offre'),
      ),
    );
  }

  // =====================================================================
  // MES MISSIONS — driver
  // =====================================================================
  function DriverMissionsScreen({ nav }) {
    const [tab, setTab] = React.useState('actives');
    const map = { actives: ['pickup', 'transit', 'arrived', 'delivering', 'confirmed'], terminees: ['delivered'] };
    const list = M.missions.filter((m) => map[tab].includes(m.status));
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Mes missions' }),
      e('div', { style: { padding: '0 16px', background: 'var(--surface-card)', borderBottom: '1px solid var(--border-subtle)' } },
        e(Tabs, { value: tab, onChange: setTab, items: [{ value: 'actives', label: 'Actives', count: 2 }, { value: 'terminees', label: 'Terminées', count: 1 }] })),
      e(Body, null,
        list.length ? e('div', { style: { display: 'flex', flexDirection: 'column', gap: 12 } },
          list.map((m) => e(ParcelCard, { key: m.id, parcel: m, onClick: () => nav('mission'),
            footer: e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between' } },
              e('span', { style: { fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 13, color: 'var(--amber-600)' } }, m.points),
              e('span', { style: { fontSize: 12.5, color: 'var(--text-muted)' } }, 'Client · ', m.client)) })))
          : e(EmptyState, { icon: 'local_shipping', title: 'Aucune mission', message: 'Acceptez un colis en libre service pour démarrer.', action: e(Button, { icon: 'sell', onClick: () => nav('dpool') }, 'Voir les colis') }),
      ),
    );
  }

  // =====================================================================
  // DÉTAIL MISSION — driver steps
  // =====================================================================
  function MissionDetailScreen({ nav }) {
    const m = M.missions[0];
    const steps = ['Ramassage', 'En transit', 'Arrivée', 'Livraison'];
    const current = 1;
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Mission', onBack: () => nav('dmissions'), actions: e(IconButton, { icon: 'more_vert' }) }),
      e(Body, { style: { gap: 16 } },
        // route hero
        e('div', { style: { background: 'var(--gradient-brand)', borderRadius: 'var(--radius-lg)', padding: 18, color: '#fff', boxShadow: 'var(--shadow-brand)' } },
          e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between' } },
            e('span', { style: { fontFamily: 'var(--font-mono)', fontWeight: 600, fontSize: 14 } }, m.tracking),
            e(StatusBadge, { status: m.status, size: 'sm', style: { background: 'rgba(255,255,255,.92)' } })),
          e('div', { style: { display: 'flex', alignItems: 'center', gap: 12, marginTop: 14 } },
            e('div', null, e('div', { style: { fontSize: 10.5, opacity: .8, textTransform: 'uppercase', letterSpacing: '.06em', fontWeight: 700 } }, 'Départ'), e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 17 } }, m.from)),
            e('div', { style: { flex: 1, position: 'relative', height: 2, background: 'rgba(255,255,255,.4)' } }, e('span', { className: 'material-symbols-rounded', style: { position: 'absolute', left: '52%', top: -12, fontSize: 24, color: '#fff' } }, 'local_shipping')),
            e('div', { style: { textAlign: 'right' } }, e('div', { style: { fontSize: 10.5, opacity: .8, textTransform: 'uppercase', letterSpacing: '.06em', fontWeight: 700 } }, 'Arrivée'), e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 17 } }, m.to))),
          e('div', { style: { display: 'flex', gap: 16, marginTop: 14, fontSize: 12.5 } },
            e('div', null, e('div', { style: { opacity: .8 } }, 'Distance'), e('div', { style: { fontFamily: 'var(--font-mono)', fontWeight: 700, marginTop: 1 } }, m.distance)),
            e('div', null, e('div', { style: { opacity: .8 } }, 'Gain'), e('div', { style: { fontFamily: 'var(--font-mono)', fontWeight: 700, marginTop: 1 } }, m.points)),
            e('div', null, e('div', { style: { opacity: .8 } }, 'Prix'), e('div', { style: { fontFamily: 'var(--font-mono)', fontWeight: 700, marginTop: 1 } }, m.price)))),
        // step progress
        e(Card, { padding: 'md' },
          e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between' } },
            steps.map((s, i) => e(React.Fragment, { key: s },
              i ? e('div', { style: { flex: 1, height: 2, background: i <= current ? 'var(--color-primary)' : 'var(--border-subtle)', margin: '0 4px', marginBottom: 18 } }) : null,
              e('div', { style: { display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, flex: 'none' } },
                e('span', { style: { width: 30, height: 30, borderRadius: '50%', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', background: i < current ? 'var(--color-primary)' : i === current ? 'var(--color-primary-soft)' : 'var(--surface-sunken)', border: i === current ? '2px solid var(--color-primary)' : 'none' } },
                  e('span', { className: 'material-symbols-rounded', style: { fontSize: 17, color: i < current ? '#fff' : i === current ? 'var(--color-primary)' : 'var(--text-faint)' } }, i < current ? 'check' : ['inventory_2', 'local_shipping', 'pin_drop', 'task_alt'][i])),
                e('span', { style: { fontSize: 10, fontWeight: 600, color: i <= current ? 'var(--text-body)' : 'var(--text-faint)', textAlign: 'center' } }, s)))))),
        // recipient card
        e(Card, { padding: 'sm' },
          e(ListRow, { leading: e(Avatar, { name: m.recipient }), title: m.recipient, subtitle: m.recipientPhone,
            trailing: e('div', { style: { display: 'flex', gap: 6 } }, e(IconButton, { icon: 'call', variant: 'soft' }), e(IconButton, { icon: 'chat', variant: 'soft', onClick: () => nav('chat') })) })),
        // map placeholder
        e('div', { style: { height: 130, borderRadius: 'var(--radius-md)', background: 'var(--surface-sunken)', border: '1px solid var(--border-subtle)', display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', overflow: 'hidden' } },
          e('span', { className: 'material-symbols-rounded', style: { fontSize: 40, color: 'var(--slate-400)' } }, 'map'),
          e('span', { style: { position: 'absolute', bottom: 10, right: 10 } }, e(Button, { size: 'sm', variant: 'secondary', icon: 'navigation' }, 'Naviguer'))),
        // primary action by stage
        e(Button, { block: true, size: 'lg', icon: 'pin_drop', onClick: () => nav('confirm-driver') }, 'Marquer comme arrivé'),
        e(Button, { block: true, variant: 'ghost', icon: 'report', style: { color: 'var(--color-danger)' } }, 'Signaler un problème'),
      ),
    );
  }

  // =====================================================================
  // PUBLIER UN VOYAGE — driver announces a trip (route + optional voice note)
  // =====================================================================
  function PublishTripScreen({ nav }) {
    const [from, setFrom] = React.useState('Abidjan');
    const [to, setTo] = React.useState('');
    const [stops, setStops] = React.useState([]);
    const [recording, setRecording] = React.useState(false);
    const [recorded, setRecorded] = React.useState(false);
    const [published, setPublished] = React.useState(false);

    const stopOptions = M.cities.filter((c) => c !== from && c !== to && !stops.includes(c));
    const toggleStop = (c) => setStops((s) => s.includes(c) ? s.filter((x) => x !== c) : [...s, c]);

    if (published) {
      return e('div', { style: { ...colStyle, alignItems: 'center', justifyContent: 'center', padding: 28, textAlign: 'center' } },
        e('div', { className: 'pc-pop', style: { width: 92, height: 92, borderRadius: '50%', background: 'var(--teal-50)', display: 'flex', alignItems: 'center', justifyContent: 'center' } },
          e('span', { className: 'material-symbols-rounded', style: { fontSize: 54, color: 'var(--color-primary)', fontVariationSettings: "'FILL' 1" } }, 'route')),
        e('h2', { style: { ...SH.titleStyle, marginTop: 22 } }, 'Voyage publié !'),
        e('p', { style: { ...SH.subStyle, maxWidth: 290 } }, 'Votre trajet ', e('span', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, color: 'var(--text-strong)' } }, `${from} → ${to || '…'}`), ' est visible par les clients. Ils peuvent désormais vous proposer leurs colis.'),
        e('div', { style: { display: 'flex', flexDirection: 'column', gap: 10, marginTop: 26, width: '100%', maxWidth: 280 } },
          e(Button, { block: true, size: 'lg', icon: 'sell', onClick: () => nav('dpool') }, 'Voir les colis à prendre'),
          e(Button, { block: true, variant: 'ghost', onClick: () => nav('dhome') }, 'Tableau de bord')),
      );
    }

    return e('div', { style: colStyle },
      e(AppBar, { title: 'Publier un voyage', onBack: () => nav('dhome') }),
      e(Body, { style: { gap: 20 } },
        // intro hero
        e('div', { style: { background: 'var(--gradient-brand)', borderRadius: 'var(--radius-lg)', padding: 16, color: '#fff', display: 'flex', alignItems: 'center', gap: 12, boxShadow: 'var(--shadow-brand)' } },
          e('span', { style: { display: 'inline-flex', width: 44, height: 44, flex: 'none', borderRadius: 'var(--radius-md)', background: 'rgba(255,255,255,.18)', alignItems: 'center', justifyContent: 'center' } },
            e('span', { className: 'material-symbols-rounded', style: { fontSize: 26, fontVariationSettings: "'FILL' 1" } }, 'campaign')),
          e('div', null,
            e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 15 } }, 'Annoncez votre trajet'),
            e('div', { style: { fontSize: 12.5, opacity: .9, marginTop: 2, lineHeight: 1.4 } }, 'Les clients sur votre route vous enverront leurs colis directement.'))),

        // route
        e(FormSection, { title: 'Trajet', icon: 'route' },
          e('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 } },
            e(Select, { label: 'Départ', icon: 'trip_origin', options: M.cities, placeholder: 'Ville', value: from, onChange: (ev) => setFrom(ev.target ? ev.target.value : ev) }),
            e(Select, { label: 'Arrivée', icon: 'pin_drop', options: M.cities, placeholder: 'Ville', value: to, onChange: (ev) => setTo(ev.target ? ev.target.value : ev) })),
          // optional intermediate stops
          e('div', null,
            e('div', { style: { fontSize: 12.5, color: 'var(--text-muted)', marginBottom: 8 } }, 'Villes desservies en chemin (optionnel)'),
            e('div', { style: { display: 'flex', flexWrap: 'wrap', gap: 8 } },
              stops.map((c) => e('button', { key: c, onClick: () => toggleStop(c), style: { border: 'none', background: 'transparent', padding: 0, cursor: 'pointer' } },
                e(Tag, { tone: 'primary', icon: 'close' }, c))),
              stopOptions.slice(0, 4).map((c) => e('button', { key: c, onClick: () => toggleStop(c), style: { border: 'none', background: 'transparent', padding: 0, cursor: 'pointer' } },
                e(Tag, { tone: 'neutral', icon: 'add' }, c)))))),

        // schedule & capacity
        e(FormSection, { title: 'Départ & capacité', icon: 'event' },
          e('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 } },
            e(Input, { label: 'Date', icon: 'calendar_month', placeholder: 'Aujourd’hui', defaultValue: '27 juin' }),
            e(Input, { label: 'Heure', icon: 'schedule', placeholder: '14:00', mono: true, defaultValue: '14:00' })),
          e('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 } },
            e(Input, { label: 'Capacité dispo.', icon: 'inventory_2', suffix: 'kg', placeholder: '50', mono: true, defaultValue: '50' }),
            e(Input, { label: 'Prix indicatif', suffix: 'FCFA/kg', placeholder: '1 500', mono: true, defaultValue: '1 500' }))),

        // note for clients
        e(FormSection, { title: 'Note pour les clients', icon: 'edit_note' },
          e(Textarea, { rows: 3, maxLength: 160, placeholder: 'Ex : Camionnette réfrigérée, je peux prendre du volumineux. Contact direct possible.' }),
          // voice note recorder (optional)
          e('div', null,
            e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 13.5, color: 'var(--text-strong)', marginBottom: 8 } }, 'Note vocale (optionnel)'),
            recorded
              ? e('div', { style: { display: 'flex', alignItems: 'center', gap: 10, padding: 12, background: 'var(--surface-card)', border: '1px solid var(--border-subtle)', borderRadius: 'var(--radius-md)' } },
                  e('span', { className: 'material-symbols-rounded', style: { fontSize: 28, color: 'var(--color-primary)' } }, 'play_circle'),
                  e(SH.Waveform, { active: 9 }),
                  e('span', { style: { fontFamily: 'var(--font-mono)', fontSize: 12, color: 'var(--text-muted)', flex: 1 } }, '0:11'),
                  e(IconButton, { icon: 'delete', variant: 'ghost', onClick: () => setRecorded(false) }))
              : e('button', { onClick: () => { if (recording) { setRecording(false); setRecorded(true); } else setRecording(true); }, style: { width: '100%', display: 'flex', alignItems: 'center', gap: 12, padding: 14, background: recording ? 'var(--red-50)' : 'var(--surface-card)', border: `1px solid ${recording ? 'var(--red-200)' : 'var(--border-subtle)'}`, borderRadius: 'var(--radius-md)', cursor: 'pointer' } },
                  e('span', { className: 'material-symbols-rounded' + (recording ? ' pc-pulse' : ''), style: { fontSize: 26, color: recording ? 'var(--color-express)' : 'var(--color-primary)', fontVariationSettings: "'FILL' 1" } }, 'mic'),
                  e('span', { style: { fontSize: 14, fontWeight: 600, color: recording ? 'var(--color-express)' : 'var(--text-body)' } }, recording ? 'Enregistrement… touchez pour arrêter' : 'Enregistrer une note vocale')),
            e('div', { style: { fontSize: 11.5, color: 'var(--text-faint)', marginTop: 6, lineHeight: 1.4 } }, 'Les clients entendront ce message avant de vous confier un colis.'))),

        e(Button, { block: true, size: 'lg', icon: 'campaign', onClick: () => setPublished(true) }, 'Publier le voyage'),
      ),
    );
  }

  // =====================================================================
  // PROFIL CHAUFFEUR
  // =====================================================================
  function DriverProfileScreen({ nav }) {
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Profil', actions: e(IconButton, { icon: 'settings', onClick: () => nav('settings') }) }),
      e(Body, { style: { gap: 18 } },
        e('div', { style: { display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, paddingTop: 6 } },
          e(Avatar, { name: D.name, size: 'xl', status: 'online' }),
          e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 21, color: 'var(--text-strong)' } }, D.name),
          e('div', { style: { display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, color: 'var(--text-muted)' } },
            e('span', { className: 'material-symbols-rounded', style: { fontSize: 17, color: 'var(--amber-500)', fontVariationSettings: "'FILL' 1" } }, 'star'),
            e('span', { style: { fontWeight: 700, color: 'var(--text-body)' } }, D.rating), ' · ', `${D.deliveries} livraisons`),
          e(Badge, { tone: 'primary', icon: 'verified' }, 'Chauffeur vérifié')),
        e('div', { style: { display: 'flex', gap: 10 } },
          e(StatBox, { icon: 'account_balance_wallet', tone: 'amber', value: D.points, label: 'Points', style: { flex: 1 } }),
          e(StatBox, { icon: 'local_shipping', tone: 'primary', value: '2', label: 'En cours', style: { flex: 1 } })),
        e(Card, { padding: 'none' },
          e(ListRow, { icon: 'garage', iconTone: 'neutral', title: 'Garage', subtitle: D.garage, chevron: true }),
          e(Divider),
          e(ListRow, { icon: 'directions_car', iconTone: 'neutral', title: 'Véhicule', subtitle: `${D.vehicle} · ${D.plate}`, chevron: true }),
          e(Divider),
          e(ListRow, { icon: 'description', iconTone: 'neutral', title: 'Documents & permis', trailing: e(Badge, { tone: 'green', icon: 'check' }, 'À jour'), chevron: true }),
          e(Divider),
          e(ListRow, { icon: 'account_balance_wallet', iconTone: 'amber', title: 'Points & retraits', chevron: true, onClick: () => nav('wallet') })),
        e(Card, { padding: 'none' },
          e(ListRow, { icon: 'settings', iconTone: 'neutral', title: 'Paramètres', chevron: true, onClick: () => nav('settings') }),
          e(Divider),
          e(ListRow, { icon: 'help', iconTone: 'neutral', title: 'Aide & support', chevron: true, onClick: () => nav('help') }),
          e(Divider),
          e(ListRow, { icon: 'logout', iconTone: 'neutral', title: 'Se déconnecter', onClick: () => nav('login') })),
        e('div', { style: { textAlign: 'center', fontSize: 11.5, color: 'var(--text-faint)', fontFamily: 'var(--font-mono)' } }, 'PRO COLIS · v1.0.0'),
      ),
    );
  }

  window.PCScreens = Object.assign(window.PCScreens || {}, { DriverHomeScreen, DriverPoolScreen, MakeOfferScreen, DriverMissionsScreen, MissionDetailScreen, PublishTripScreen, DriverProfileScreen });
})();
