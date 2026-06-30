/* Procolis mobile UI kit — primary screens. window.PCScreens.* */
(function () {
  const NS = window.ProcolisDesignSystem_1720b4;
  const { AppBar, TabBar, Fab, IconButton, Button, Input, Select, Switch, Checkbox,
          SegmentedControl, Card, StatBox, Badge, StatusBadge, Tag, Avatar, ListRow,
          ParcelCard, Stepper, Toast, EmptyState, Tabs } = NS;
  const M = window.PCMock;
  const e = React.createElement;

  // ---- small shared bits ----------------------------------------
  function SectionHeader({ title, action, onAction }) {
    return e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', margin: '4px 2px 10px' } },
      e('span', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 16, color: 'var(--text-strong)' } }, title),
      action && e('button', { onClick: onAction, style: { border: 'none', background: 'transparent', color: 'var(--text-link)', fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 13, cursor: 'pointer' } }, action),
    );
  }
  const Body = (props) => e('div', { style: { flex: 1, overflowY: 'auto', padding: '16px 16px 96px', display: 'flex', flexDirection: 'column', ...props.style } }, props.children);

  // =====================================================================
  // LOGIN — phone + OTP / PIN
  // =====================================================================
  function LoginScreen({ nav }) {
    const [mode, setMode] = React.useState('phone'); // phone | otp | pin
    const [phone, setPhone] = React.useState('07 11 45 90');
    const [otp, setOtp] = React.useState(['', '', '', '']);
    const [pin, setPin] = React.useState('');

    const Hero = e('div', { style: { background: 'var(--gradient-brand)', padding: '56px 24px 30px', color: '#fff', textAlign: 'center' } },
      e('img', { src: '../../assets/logo-procolis.png', alt: 'Procolis', style: { width: 76, height: 76, objectFit: 'contain', filter: 'drop-shadow(0 6px 14px rgba(0,0,0,.25))' } }),
      e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 26, letterSpacing: '-.02em', marginTop: 10 } }, 'PRO COLIS'),
      e('div', { style: { fontSize: 14, opacity: .9, marginTop: 2 } }, 'Vos colis, de ville en ville'),
    );

    let form;
    if (mode === 'phone') {
      form = e(React.Fragment, null,
        e('h2', { style: titleStyle }, 'Connexion'),
        e('p', { style: subStyle }, 'Entrez votre numéro pour recevoir un code de vérification.'),
        e('div', { style: { display: 'flex', gap: 10, marginTop: 18 } },
          e('div', { style: { display: 'flex', alignItems: 'center', gap: 6, padding: '0 12px', height: 48, border: '1px solid var(--border-default)', borderRadius: 'var(--radius-md)', background: 'var(--surface-card)', fontWeight: 600, color: 'var(--text-body)', fontSize: 15 } }, '🇨🇮 +225'),
          e('div', { style: { flex: 1 } }, e(Input, { value: phone, onChange: (ev) => setPhone(ev.target.value), placeholder: '07 00 00 00', mono: true })),
        ),
        e('div', { style: { marginTop: 22 } }, e(Button, { block: true, size: 'lg', onClick: () => setMode('otp'), iconTrailing: 'arrow_forward' }, 'Recevoir le code')),
        e('div', { style: { textAlign: 'center', marginTop: 16 } },
          e('button', { onClick: () => setMode('pin'), style: linkBtn }, 'Se connecter avec un code PIN')),
        e('p', { style: { ...subStyle, textAlign: 'center', marginTop: 24, fontSize: 12.5 } }, 'Pas encore de compte ? ',
          e('span', { style: { color: 'var(--text-link)', fontWeight: 700 } }, 'Créer un compte')),
      );
    } else if (mode === 'otp') {
      form = e(React.Fragment, null,
        e('h2', { style: titleStyle }, 'Vérification'),
        e('p', { style: subStyle }, `Code envoyé au +225 ${phone}.`),
        e('div', { style: { display: 'flex', gap: 12, justifyContent: 'center', margin: '24px 0 8px' } },
          [0, 1, 2, 3].map((i) => e('input', {
            key: i, value: otp[i], maxLength: 1, inputMode: 'numeric',
            onChange: (ev) => { const n = [...otp]; n[i] = ev.target.value.slice(-1); setOtp(n); },
            style: { width: 56, height: 64, textAlign: 'center', fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 26, color: 'var(--text-strong)', border: `2px solid ${otp[i] ? 'var(--color-primary)' : 'var(--border-default)'}`, borderRadius: 'var(--radius-md)', outline: 'none', background: 'var(--surface-card)' },
          })),
        ),
        e('p', { style: { ...subStyle, textAlign: 'center' } }, 'Renvoyer le code dans ', e('span', { style: { fontFamily: 'var(--font-mono)', color: 'var(--text-body)' } }, '00:42')),
        e('div', { style: { marginTop: 22 } }, e(Button, { block: true, size: 'lg', onClick: () => nav('home') }, 'Vérifier')),
        e('div', { style: { textAlign: 'center', marginTop: 14 } }, e('button', { onClick: () => setMode('phone'), style: linkBtn }, 'Modifier le numéro')),
      );
    } else {
      form = e(React.Fragment, null,
        e('h2', { style: titleStyle }, 'Code PIN'),
        e('p', { style: subStyle }, 'Entrez votre code à 4 chiffres pour Awa Diallo.'),
        e('div', { style: { display: 'flex', gap: 14, justifyContent: 'center', margin: '26px 0' } },
          [0, 1, 2, 3].map((i) => e('span', { key: i, style: { width: 18, height: 18, borderRadius: '50%', background: i < pin.length ? 'var(--color-primary)' : 'var(--slate-200)', border: i < pin.length ? 'none' : '1px solid var(--border-default)' } }))),
        e(Keypad, { onKey: (k) => { if (k === 'del') setPin(pin.slice(0, -1)); else if (pin.length < 4) { const np = pin + k; setPin(np); if (np.length === 4) setTimeout(() => nav('home'), 180); } } }),
        e('div', { style: { textAlign: 'center', marginTop: 12 } }, e('button', { onClick: () => setMode('phone'), style: linkBtn }, 'Utiliser le numéro de téléphone')),
      );
    }

    return e('div', { style: { display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--surface-page)' } },
      Hero,
      e('div', { style: { flex: 1, overflowY: 'auto', padding: '26px 24px' } }, form),
    );
  }
  const titleStyle = { fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 24, color: 'var(--text-strong)', margin: 0, letterSpacing: '-.01em' };
  const subStyle = { fontSize: 14, color: 'var(--text-muted)', margin: '6px 0 0', lineHeight: 1.5 };
  const linkBtn = { border: 'none', background: 'transparent', color: 'var(--text-link)', fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 13.5, cursor: 'pointer' };

  function Keypad({ onKey }) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];
    return e('div', { style: { display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 10, maxWidth: 260, margin: '0 auto' } },
      keys.map((k, i) => k === '' ? e('span', { key: i }) : e('button', {
        key: i, onClick: () => onKey(k),
        style: { height: 56, borderRadius: 'var(--radius-md)', border: '1px solid var(--border-subtle)', background: 'var(--surface-card)', fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 22, color: 'var(--text-strong)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' },
      }, k === 'del' ? e('span', { className: 'material-symbols-rounded', style: { fontSize: 24 } }, 'backspace') : k)),
    );
  }

  // =====================================================================
  // HOME — client dashboard
  // =====================================================================
  function HomeScreen({ nav, unread }) {
    return e('div', { style: colStyle },
      // brand hero with points
      e('div', { style: { background: 'var(--gradient-brand)', padding: '52px 16px 22px', color: '#fff' } },
        e('div', { style: { display: 'flex', alignItems: 'center', gap: 12 } },
          e(Avatar, { name: M.user.name, status: 'online' }),
          e('div', { style: { flex: 1, minWidth: 0 } },
            e('div', { style: { fontSize: 12.5, opacity: .85 } }, 'Bonjour,'),
            e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 17 } }, M.user.name)),
          e(IconButton, { icon: 'search', variant: 'ghost', style: { color: '#fff' } }),
          e('span', { style: { position: 'relative' } },
            e(IconButton, { icon: 'notifications', variant: 'ghost', style: { color: '#fff' }, onClick: () => nav('notifications') }),
            unread ? e('span', { style: notifDot }, unread) : null),
        ),
        // points card
        e('div', { style: { display: 'flex', alignItems: 'center', gap: 14, marginTop: 16, padding: 14, background: 'rgba(255,255,255,.14)', borderRadius: 'var(--radius-lg)', backdropFilter: 'blur(4px)' } },
          e('span', { style: { display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 44, height: 44, borderRadius: 'var(--radius-md)', background: 'rgba(255,255,255,.18)' } },
            e('span', { className: 'material-symbols-rounded', style: { fontSize: 24, fontVariationSettings: "'FILL' 1" } }, 'account_balance_wallet')),
          e('div', { style: { flex: 1 } },
            e('div', { style: { fontSize: 11.5, opacity: .85, textTransform: 'uppercase', letterSpacing: '.07em', fontWeight: 700 } }, 'Solde de points'),
            e('div', { style: { fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 23, marginTop: 1 } }, M.user.points, e('span', { style: { fontSize: 14, opacity: .8 } }, ' pts'))),
          e(Button, { variant: 'amber', size: 'sm', icon: 'add' }, 'Recharger'),
        ),
      ),
      e('div', { style: { flex: 1, overflowY: 'auto', padding: '18px 16px 96px' } },
        // quick actions
        e('div', { style: { display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 10, marginBottom: 22 } },
          [['add_box', 'Nouveau', () => nav('new')], ['sell', 'Libre service', () => nav('libre')], ['qr_code_2', 'Suivre', () => nav('track')], ['history', 'Historique', () => nav('colis')]].map(([ic, lb, fn], i) =>
            e('button', { key: i, onClick: fn, style: quickBtn },
              e('span', { style: quickIcon }, e('span', { className: 'material-symbols-rounded', style: { fontSize: 24, color: 'var(--color-primary)', fontVariationSettings: "'FILL' 1" } }, ic)),
              e('span', { style: { fontSize: 11.5, fontWeight: 600, color: 'var(--text-body)' } }, lb)))),
        // KPI row
        e('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, marginBottom: 22 } },
          e(StatBox, { icon: 'package_2', tone: 'primary', value: '3', label: 'Colis en cours' }),
          e(StatBox, { icon: 'task_alt', tone: 'green', value: '28', label: 'Colis livrés' }),
        ),
        e(SectionHeader, { title: 'Mes colis récents', action: 'Tout voir', onAction: () => nav('colis') }),
        e('div', { style: { display: 'flex', flexDirection: 'column', gap: 12 } },
          M.parcels.slice(0, 2).map((p) => e(ParcelCard, {
            key: p.id, parcel: p, onClick: () => nav('track'),
            footer: p.status === 'free' ? e(Button, { block: true, variant: 'secondary', size: 'sm', iconTrailing: 'chevron_right' }, `${p.offers} offres reçues`) : null,
          })),
        ),
      ),
    );
  }

  // =====================================================================
  // MES COLIS — list with filter tabs
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
          list.map((p) => e(ParcelCard, { key: p.id, parcel: p, onClick: () => nav('track') })))
          : e(EmptyState, { icon: 'inbox', title: 'Aucun colis ici', message: 'Vos colis de cette catégorie apparaîtront ici.', action: e(Button, { icon: 'add', onClick: () => nav('new') }, 'Nouveau colis') }),
      ),
    );
  }

  // =====================================================================
  // NEW PARCEL — creation form
  // =====================================================================
  function NewParcelScreen({ nav, onCreate }) {
    const [insurance, setInsurance] = React.useState(true);
    const [urgent, setUrgent] = React.useState(false);
    const [terms, setTerms] = React.useState(false);
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Nouveau colis', subtitle: 'Étape 1 sur 2', onBack: () => nav('home') }),
      e(Body, { style: { gap: 18 } },
        e(FormSection, { title: 'Trajet', icon: 'route' },
          e('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 } },
            e(Select, { label: 'Départ', icon: 'trip_origin', options: M.cities, placeholder: 'Ville' }),
            e(Select, { label: 'Arrivée', icon: 'pin_drop', options: M.cities, placeholder: 'Ville' })),
        ),
        e(FormSection, { title: 'Destinataire', icon: 'person_pin' },
          e(Input, { label: 'Nom complet', icon: 'badge', placeholder: 'Ex : Moussa Traoré' }),
          e(Input, { label: 'Téléphone', icon: 'call', placeholder: '07 00 00 00', mono: true }),
        ),
        e(FormSection, { title: 'Colis', icon: 'package_2' },
          e('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 } },
            e(Select, { label: 'Type', icon: 'category', options: M.parcelTypes, placeholder: 'Type' }),
            e(Input, { label: 'Poids', suffix: 'kg', placeholder: '8', mono: true })),
          e(Input, { label: 'Description (optionnel)', icon: 'description', placeholder: 'Contenu du colis' }),
        ),
        e(FormSection, { title: 'Options', icon: 'tune' },
          e('div', { style: { display: 'flex', flexDirection: 'column', gap: 14 } },
            e(Switch, { checked: insurance, onChange: setInsurance, label: 'Assurance', description: 'Couvre jusqu’à 200 000 FCFA' }),
            e(Switch, { checked: urgent, onChange: setUrgent, label: 'Livraison urgente (express)', description: 'Priorité haute, supplément 2 000 FCFA' })),
        ),
        // price summary
        e(Card, { padding: 'md', style: { background: 'var(--color-primary-soft)', border: '1px solid var(--teal-100)' } },
          e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between' } },
            e('div', null,
              e('div', { style: { fontSize: 12.5, color: 'var(--teal-700)', fontWeight: 600 } }, 'Prix estimé'),
              e('div', { style: { fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 24, color: 'var(--teal-700)' } }, urgent ? '14 500 FCFA' : '12 500 FCFA')),
            e(Tag, { express: urgent ? true : undefined }, urgent ? undefined : 'Standard')),
        ),
        e(Checkbox, { checked: terms, onChange: setTerms, label: 'J’accepte les conditions de transport.' }),
        e(Button, { block: true, size: 'lg', disabled: !terms, onClick: () => { onCreate && onCreate(); nav('libre'); }, icon: 'sell' }, 'Publier en libre service'),
        e(Button, { block: true, variant: 'ghost', onClick: () => nav('home') }, 'Enregistrer comme brouillon'),
      ),
    );
  }
  function FormSection({ title, icon, children }) {
    return e('div', null,
      e('div', { style: { display: 'flex', alignItems: 'center', gap: 7, marginBottom: 12 } },
        e('span', { className: 'material-symbols-rounded', style: { fontSize: 19, color: 'var(--color-primary)' } }, icon),
        e('span', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 14.5, color: 'var(--text-strong)' } }, title)),
      e('div', { style: { display: 'flex', flexDirection: 'column', gap: 12 } }, children));
  }

  const colStyle = { display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--surface-page)' };
  const notifDot = { position: 'absolute', top: 6, right: 6, minWidth: 16, height: 16, padding: '0 4px', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', background: 'var(--amber-400)', color: '#3a2600', borderRadius: '999px', fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 10, border: '2px solid #0a8c84' };
  const quickBtn = { display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, border: 'none', background: 'transparent', cursor: 'pointer', padding: 0 };
  const quickIcon = { display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 52, height: 52, borderRadius: 'var(--radius-md)', background: 'var(--color-primary-soft)' };

  window.PCScreens = Object.assign(window.PCScreens || {}, { LoginScreen, HomeScreen, MesColisScreen, NewParcelScreen, SectionHeader, Body, colStyle });
})();
