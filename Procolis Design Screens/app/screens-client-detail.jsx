/* PRO COLIS — client screens (detail, libre, wallet, preuve, confirmation, réglages, aide, chat). */
(function () {
  const NS = window.ProcolisDesignSystem_1720b4;
  const { AppBar, IconButton, Button, Input, Card, StatBox, Badge, StatusBadge, Tag,
          Avatar, ListRow, ParcelCard, Stepper, Switch, SegmentedControl, EmptyState } = NS;
  const M = window.PCMock;
  const SH = window.PCShared;
  const { Body, SectionHeader, colStyle } = SH;
  const Divider = () => React.createElement('div', { style: { height: 1, background: 'var(--border-subtle)', margin: '0 14px' } });
  const e = React.createElement;

  function RouteEnd({ label, city, right }) {
    return e('div', { style: { textAlign: right ? 'right' : 'left' } },
      e('div', { style: { fontSize: 10.5, opacity: .8, textTransform: 'uppercase', letterSpacing: '.07em', fontWeight: 700 } }, label),
      e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 17 } }, city));
  }
  function HeroMeta({ label, value }) {
    return e('div', { style: { whiteSpace: 'nowrap' } },
      e('div', { style: { opacity: .8 } }, label),
      e('div', { style: { fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 14, marginTop: 1 } }, value));
  }

  // =====================================================================
  // DÉTAIL COLIS COMPLET (suivi + infos)
  // =====================================================================
  function DetailScreen({ nav, home }) {
    const p = M.parcels[0];
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Détail du colis', onBack: () => nav(home || 'home'), actions: e(IconButton, { icon: 'share' }) }),
      e(Body, { style: { gap: 16 } },
        // tracking hero
        e('div', { style: { background: 'var(--gradient-brand)', borderRadius: 'var(--radius-lg)', padding: 18, color: '#fff', boxShadow: 'var(--shadow-brand)' } },
          e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between' } },
            e('span', { style: { display: 'inline-flex', alignItems: 'center', gap: 6 } },
              e('span', { className: 'material-symbols-rounded', style: { fontSize: 18 } }, 'qr_code_2'),
              e('span', { style: { fontFamily: 'var(--font-mono)', fontWeight: 600, fontSize: 14 } }, p.tracking)),
            e(StatusBadge, { status: p.status, size: 'sm', style: { background: 'rgba(255,255,255,.92)' } })),
          e('div', { style: { display: 'flex', alignItems: 'center', gap: 12, marginTop: 16 } },
            e(RouteEnd, { label: 'Départ', city: p.from }),
            e('div', { style: { flex: 1, position: 'relative', height: 2, background: 'rgba(255,255,255,.4)' } },
              e('span', { className: 'material-symbols-rounded', style: { position: 'absolute', left: '55%', top: -12, fontSize: 24, color: '#fff', filter: 'drop-shadow(0 2px 4px rgba(0,0,0,.2))' } }, 'local_shipping')),
            e(RouteEnd, { label: 'Arrivée', city: p.to, right: true })),
          e('div', { style: { display: 'flex', gap: 16, marginTop: 16, fontSize: 12.5 } },
            e(HeroMeta, { label: 'Distance', value: p.distance }),
            e(HeroMeta, { label: 'Reste', value: p.eta }),
            e(HeroMeta, { label: 'Prix', value: p.price }))),
        // express tag
        p.express ? e('div', null, e(Tag, { express: true })) : null,
        // driver card
        e(Card, { padding: 'sm' },
          e(ListRow, { leading: e(Avatar, { name: p.driver, status: 'online' }), title: p.driver, subtitle: `${p.garage} · ${p.rating} ★ · ${p.vehicle}`,
            trailing: e('div', { style: { display: 'flex', gap: 6 } }, e(IconButton, { icon: 'call', variant: 'soft' }), e(IconButton, { icon: 'chat', variant: 'soft', onClick: () => nav('chat') })) })),
        // parcel info
        e(Card, { padding: 'none' },
          e(InfoRow, { icon: 'category', label: 'Type', value: p.type }),
          e(Divider),
          e(InfoRow, { icon: 'scale', label: 'Poids', value: p.weight, mono: true }),
          e(Divider),
          e(InfoRow, { icon: 'person_pin', label: 'Destinataire', value: p.recipient }),
          e(Divider),
          e(InfoRow, { icon: 'call', label: 'Téléphone', value: p.recipientPhone, mono: true })),
        // timeline
        e('div', null, e(SectionHeader, { title: 'Suivi' }), e(Card, { padding: 'md' }, e(Stepper, { steps: M.timeline }))),
        e('div', { style: { display: 'flex', gap: 10 } },
          e(Button, { block: true, variant: 'secondary', icon: 'receipt_long' }, 'Voir le reçu'),
          e(Button, { block: true, variant: 'danger', icon: 'cancel' }, 'Annuler')),
      ),
    );
  }
  function InfoRow({ icon, label, value, mono }) {
    return e('div', { style: { display: 'flex', alignItems: 'center', gap: 12, padding: '13px 16px' } },
      e('span', { className: 'material-symbols-rounded', style: { fontSize: 20, color: 'var(--text-muted)' } }, icon),
      e('span', { style: { fontSize: 13.5, color: 'var(--text-muted)', flex: 'none', width: 96 } }, label),
      e('span', { style: { flex: 1, textAlign: 'right', fontSize: 14, fontWeight: 600, color: 'var(--text-strong)', fontFamily: mono ? 'var(--font-mono)' : 'var(--font-body)' } }, value));
  }

  // =====================================================================
  // LIBRE SERVICE — client: offres reçues
  // =====================================================================
  function LibreServiceScreen({ nav }) {
    const p = M.parcels[1];
    const [accepted, setAccepted] = React.useState(null);
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Libre service', actions: e(IconButton, { icon: 'tune' }) }),
      e(Body, { style: { gap: 14, paddingTop: 16 } },
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
                        e('span', { className: 'material-symbols-rounded', style: { fontSize: 22 } }, 'play_circle'), e(SH.Waveform),
                        e('span', { style: { fontFamily: 'var(--font-mono)', fontSize: 11, color: 'var(--text-muted)' } }, o.audioLen))
                    : e('span', { style: { fontSize: 13, color: 'var(--text-body)', fontStyle: 'italic' } }, `“${o.message}”`)),
                e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 10 } },
                  e('span', { style: { fontSize: 11.5, color: 'var(--text-faint)' } }, o.when),
                  accepted === o.id
                    ? e(Badge, { tone: 'green', icon: 'check' }, 'Acceptée')
                    : e('div', { style: { display: 'flex', gap: 8 } },
                        e(Button, { size: 'sm', variant: 'secondary' }, 'Négocier'),
                        e(Button, { size: 'sm', icon: 'check', onClick: () => setAccepted(o.id) }, 'Accepter')))))))),
      ),
    );
  }

  // =====================================================================
  // PORTEFEUILLE — points & recharge
  // =====================================================================
  function WalletScreen({ nav }) {
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Points & paiements', onBack: () => nav('profile') }),
      e(Body, { style: { gap: 18 } },
        // balance hero (amber)
        e('div', { style: { background: 'var(--gradient-amber)', borderRadius: 'var(--radius-lg)', padding: 20, color: '#3a2600', boxShadow: 'var(--shadow-amber)' } },
          e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between' } },
            e('span', { style: { fontSize: 12, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '.07em', opacity: .8 } }, 'Solde de points'),
            e('span', { className: 'material-symbols-rounded', style: { fontSize: 26, fontVariationSettings: "'FILL' 1" } }, 'account_balance_wallet')),
          e('div', { style: { fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 38, marginTop: 6 } }, M.user.points, e('span', { style: { fontSize: 18 } }, ' pts')),
          e('div', { style: { fontSize: 12.5, marginTop: 2, opacity: .8 } }, '≈ 24 500 FCFA de réductions disponibles')),
        e('div', { style: { display: 'flex', gap: 10 } },
          e(Button, { block: true, size: 'lg', icon: 'add_card', onClick: () => nav('topup') }, 'Recharger'),
          e(Button, { block: true, size: 'lg', variant: 'secondary', icon: 'redeem' }, 'Utiliser')),
        e('div', null,
          e(SectionHeader, { title: 'Historique' }),
          e(Card, { padding: 'none' },
            M.txns.map((t, i) => e(React.Fragment, { key: t.id },
              i ? e(Divider) : null,
              e(ListRow, { icon: t.icon, iconTone: t.tone, title: t.title, subtitle: t.when,
                trailing: e('span', { style: { fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 14, color: t.positive ? 'var(--color-success)' : 'var(--text-muted)' } }, t.amount) }))))),
      ),
    );
  }

  // =====================================================================
  // RECHARGE (top-up sheet-like screen)
  // =====================================================================
  function TopUpScreen({ nav }) {
    const [amount, setAmount] = React.useState('1000');
    const [method, setMethod] = React.useState('om');
    const presets = ['500', '1000', '2500', '5000'];
    const methods = [
      { key: 'om', icon: 'smartphone', title: 'Orange Money', sub: '+221 76 516 27 96' },
      { key: 'momo', icon: 'smartphone', title: 'MTN MoMo', sub: 'Compte lié' },
      { key: 'card', icon: 'credit_card', title: 'Carte bancaire', sub: 'Visa · Mastercard' },
    ];
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Recharger', onBack: () => nav('wallet') }),
      e(Body, { style: { gap: 20 } },
        e('div', null,
          e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 14, color: 'var(--text-strong)', marginBottom: 10 } }, 'Montant'),
          e('div', { style: { display: 'grid', gridTemplateColumns: 'repeat(4,1fr)', gap: 10 } },
            presets.map((a) => { const sel = amount === a; return e('button', { key: a, onClick: () => setAmount(a), style: { padding: '14px 0', borderRadius: 'var(--radius-md)', border: `2px solid ${sel ? 'var(--color-primary)' : 'var(--border-subtle)'}`, background: sel ? 'var(--teal-50)' : 'var(--surface-card)', cursor: 'pointer', fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 15, color: sel ? 'var(--teal-700)' : 'var(--text-body)' } }, a); }))),
        e('div', null,
          e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 14, color: 'var(--text-strong)', marginBottom: 10 } }, 'Moyen de paiement'),
          e('div', { style: { display: 'flex', flexDirection: 'column', gap: 10 } },
            methods.map((m) => { const sel = method === m.key; return e('button', { key: m.key, onClick: () => setMethod(m.key), style: { display: 'flex', alignItems: 'center', gap: 12, padding: 14, borderRadius: 'var(--radius-md)', border: `2px solid ${sel ? 'var(--color-primary)' : 'var(--border-subtle)'}`, background: sel ? 'var(--teal-50)' : 'var(--surface-card)', cursor: 'pointer', textAlign: 'left' } },
              e('span', { className: 'material-symbols-rounded', style: { fontSize: 24, color: 'var(--color-primary)' } }, m.icon),
              e('div', { style: { flex: 1 } },
                e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 14.5, color: 'var(--text-strong)' } }, m.title),
                e('div', { style: { fontSize: 12, color: 'var(--text-muted)' } }, m.sub)),
              e('span', { style: { width: 20, height: 20, borderRadius: '50%', border: `2px solid ${sel ? 'var(--color-primary)' : 'var(--border-default)'}`, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' } },
                sel ? e('span', { style: { width: 10, height: 10, borderRadius: '50%', background: 'var(--color-primary)' } }) : null)); }))),
        e(Card, { padding: 'md', style: { background: 'var(--surface-sunken)' } },
          e('div', { style: { display: 'flex', justifyContent: 'space-between', fontSize: 14 } },
            e('span', { style: { color: 'var(--text-muted)' } }, 'Total à payer'),
            e('span', { style: { fontFamily: 'var(--font-mono)', fontWeight: 700, color: 'var(--text-strong)' } }, `${Number(amount).toLocaleString('fr-FR')} FCFA`))),
        e(Button, { block: true, size: 'lg', icon: 'lock', onClick: () => nav('wallet') }, 'Payer maintenant'),
      ),
    );
  }

  // =====================================================================
  // CONFIRMATION DE LIVRAISON — PIN destinataire
  // =====================================================================
  function ConfirmDeliveryScreen({ nav, home }) {
    const p = M.parcels[0];
    const [pin, setPin] = React.useState('');
    const [done, setDone] = React.useState(false);
    const push = (k) => { if (k === 'del') return setPin(pin.slice(0, -1)); if (pin.length >= 4) return; const n = pin + k; setPin(n); if (n.length === 4) setTimeout(() => setDone(true), 200); };
    if (done) {
      return e('div', { style: { ...colStyle, alignItems: 'center', justifyContent: 'center', padding: 28, textAlign: 'center' } },
        e('div', { className: 'pc-pop', style: { width: 92, height: 92, borderRadius: '50%', background: 'var(--green-50)', display: 'flex', alignItems: 'center', justifyContent: 'center' } },
          e('span', { className: 'material-symbols-rounded', style: { fontSize: 56, color: 'var(--color-success)', fontVariationSettings: "'FILL' 1" } }, 'task_alt')),
        e('h2', { style: { ...SH.titleStyle, marginTop: 22 } }, 'Colis livré !'),
        e('p', { style: { ...SH.subStyle, maxWidth: 280 } }, e('span', { style: { fontFamily: 'var(--font-mono)', fontWeight: 600 } }, p.tracking), ' a bien été remis à ', p.recipient, '.'),
        e('div', { style: { background: 'var(--amber-50)', color: 'var(--amber-700)', borderRadius: 'var(--radius-md)', padding: '10px 16px', marginTop: 20, fontWeight: 700, fontFamily: 'var(--font-mono)' } }, '+150 pts crédités'),
        e('div', { style: { display: 'flex', flexDirection: 'column', gap: 10, marginTop: 26, width: '100%', maxWidth: 280 } },
          e(Button, { block: true, size: 'lg', icon: 'photo_camera', onClick: () => nav('proof') }, 'Ajouter une preuve'),
          e(Button, { block: true, variant: 'ghost', onClick: () => nav(home || 'home') }, 'Retour à l’accueil')),
      );
    }
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Confirmer la livraison', onBack: () => nav('detail') }),
      e('div', { style: { flex: 1, overflowY: 'auto', padding: '20px 24px 24px', display: 'flex', flexDirection: 'column', alignItems: 'center' } },
        e('span', { style: { display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 56, height: 56, borderRadius: 'var(--radius-lg)', background: 'var(--color-primary-soft)', marginTop: 6 } },
          e('span', { className: 'material-symbols-rounded', style: { fontSize: 30, color: 'var(--color-primary)', fontVariationSettings: "'FILL' 1" } }, 'lock_open')),
        e('h2', { style: { ...SH.titleStyle, marginTop: 14, textAlign: 'center' } }, 'Code du destinataire'),
        e('p', { style: { ...SH.subStyle, textAlign: 'center', maxWidth: 300 } }, 'Demandez à ', e('span', { style: { fontWeight: 600, color: 'var(--text-body)' } }, p.recipient), ' le code PIN à 4 chiffres reçu par SMS pour valider la remise du colis.'),
        e('div', { style: { margin: '26px 0 6px' } }, e(SH.OtpBoxes, { value: pin })),
        e('div', { style: { fontSize: 12.5, color: 'var(--text-faint)', marginBottom: 4 } }, e('span', { className: 'material-symbols-rounded', style: { fontSize: 15, verticalAlign: '-3px', marginRight: 4 } }, 'info'), 'Indice démo : ', e('span', { style: { fontFamily: 'var(--font-mono)' } }, p.pin)),
        e('div', { style: { marginTop: 'auto', width: '100%' } }, e(SH.Keypad, { onKey: push })),
      ),
    );
  }

  // =====================================================================
  // PREUVE DE LIVRAISON
  // =====================================================================
  function ProofScreen({ nav, home }) {
    const [sig, setSig] = React.useState(false);
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Preuve de livraison', onBack: () => nav(home || 'home') }),
      e(Body, { style: { gap: 18 } },
        e('div', { style: { display: 'flex', alignItems: 'center', gap: 8, background: 'var(--green-50)', color: 'var(--green-700)', padding: '12px 14px', borderRadius: 'var(--radius-md)', fontSize: 13.5, fontWeight: 600 } },
          e('span', { className: 'material-symbols-rounded', style: { fontVariationSettings: "'FILL' 1" } }, 'verified'), 'Colis remis · PIN destinataire validé'),
        e('div', null,
          e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 14, color: 'var(--text-strong)', marginBottom: 10 } }, 'Photo du colis remis'),
          e('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 } },
            e('div', { style: { aspectRatio: '1', borderRadius: 'var(--radius-md)', background: 'var(--surface-sunken)', border: '1px solid var(--border-subtle)', display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', overflow: 'hidden' } },
              e('span', { className: 'material-symbols-rounded', style: { fontSize: 44, color: 'var(--slate-400)' } }, 'image'),
              e('span', { style: { position: 'absolute', bottom: 8, left: 8, fontSize: 11, fontFamily: 'var(--font-mono)', color: 'var(--text-muted)', background: 'rgba(255,255,255,.85)', padding: '2px 6px', borderRadius: 6 } }, 'Auj. 14:22')),
            e('button', { style: { aspectRatio: '1', borderRadius: 'var(--radius-md)', background: 'var(--color-primary-soft)', border: '1.5px dashed var(--teal-200)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 6, cursor: 'pointer', color: 'var(--color-primary)' } },
              e('span', { className: 'material-symbols-rounded', style: { fontSize: 32 } }, 'add_a_photo'),
              e('span', { style: { fontSize: 12, fontWeight: 600 } }, 'Ajouter')))),
        e('div', null,
          e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 14, color: 'var(--text-strong)', marginBottom: 10 } }, 'Signature du destinataire'),
          e('button', { onClick: () => setSig(true), style: { width: '100%', height: 130, borderRadius: 'var(--radius-md)', background: 'var(--surface-card)', border: `1.5px ${sig ? 'solid var(--color-primary)' : 'dashed var(--border-default)'}`, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', color: sig ? 'var(--color-primary)' : 'var(--text-faint)', fontFamily: sig ? 'cursive' : 'var(--font-body)', fontSize: sig ? 34 : 14 } },
            sig ? 'M. Traoré' : 'Touchez pour signer')),
        e(Input, { label: 'Remarque (optionnel)', icon: 'edit_note', placeholder: 'Ex : remis au gardien' }),
        e(Button, { block: true, size: 'lg', icon: 'check', onClick: () => nav(home || 'home') }, 'Valider la preuve'),
      ),
    );
  }

  // =====================================================================
  // CHAT / MESSAGERIE CHAUFFEUR
  // =====================================================================
  function ChatScreen({ nav, home }) {
    const p = M.parcels[0];
    return e('div', { style: colStyle },
      e(AppBar, { onBack: () => nav('detail'),
        leading: null,
        title: e('div', { style: { display: 'flex', alignItems: 'center', gap: 10 } },
          e(Avatar, { name: p.driver, size: 'sm', status: 'online' }),
          e('div', null,
            e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 15, color: 'var(--text-strong)' } }, p.driver),
            e('div', { style: { fontSize: 11.5, color: 'var(--color-success)', fontWeight: 600 } }, 'En ligne'))),
        actions: e(IconButton, { icon: 'call', variant: 'soft' }) }),
      // pinned parcel chip
      e('div', { onClick: () => nav('detail'), style: { display: 'flex', alignItems: 'center', gap: 10, padding: '10px 16px', background: 'var(--color-primary-soft)', borderBottom: '1px solid var(--teal-100)', cursor: 'pointer' } },
        e('span', { className: 'material-symbols-rounded', style: { fontSize: 20, color: 'var(--color-primary)' } }, 'package_2'),
        e('span', { style: { flex: 1, fontFamily: 'var(--font-mono)', fontSize: 13, fontWeight: 600, color: 'var(--teal-700)' } }, p.tracking),
        e(StatusBadge, { status: p.status, size: 'sm' })),
      // messages
      e('div', { style: { flex: 1, overflowY: 'auto', padding: '16px 14px', display: 'flex', flexDirection: 'column', gap: 10, background: 'var(--surface-page)' } },
        e('div', { style: { textAlign: 'center', fontSize: 11.5, color: 'var(--text-faint)', margin: '2px 0 6px' } }, 'Aujourd’hui'),
        M.chat.map((m) => {
          const mine = m.from === 'me';
          return e('div', { key: m.id, style: { display: 'flex', justifyContent: mine ? 'flex-end' : 'flex-start' } },
            e('div', { style: { maxWidth: '78%', padding: '9px 13px', borderRadius: 16, borderBottomRightRadius: mine ? 4 : 16, borderBottomLeftRadius: mine ? 16 : 4, background: mine ? 'var(--color-primary)' : 'var(--surface-card)', color: mine ? '#fff' : 'var(--text-body)', boxShadow: 'var(--shadow-xs)' } },
              m.audio
                ? e('span', { style: { display: 'inline-flex', alignItems: 'center', gap: 8 } },
                    e('span', { className: 'material-symbols-rounded', style: { fontSize: 24, color: mine ? '#fff' : 'var(--color-primary)' } }, 'play_circle'),
                    e(SH.Waveform), e('span', { style: { fontFamily: 'var(--font-mono)', fontSize: 11, opacity: .8 } }, m.audioLen))
                : e('span', { style: { fontSize: 14, lineHeight: 1.4 } }, m.text),
              e('span', { style: { display: 'block', fontSize: 10, opacity: .6, marginTop: 4, textAlign: 'right', fontFamily: 'var(--font-mono)' } }, m.time)));
        })),
      // composer
      e('div', { style: { flex: 'none', display: 'flex', alignItems: 'center', gap: 8, padding: '10px 12px', background: 'var(--surface-card)', borderTop: '1px solid var(--border-subtle)' } },
        e(IconButton, { icon: 'add', variant: 'ghost' }),
        e('div', { style: { flex: 1, display: 'flex', alignItems: 'center', gap: 8, padding: '0 14px', height: 42, background: 'var(--surface-sunken)', borderRadius: 999 } },
          e('span', { style: { flex: 1, fontSize: 14, color: 'var(--text-faint)' } }, 'Votre message…'),
          e('span', { className: 'material-symbols-rounded', style: { fontSize: 22, color: 'var(--text-muted)' } }, 'mic')),
        e(IconButton, { icon: 'send', variant: 'solid' })),
    );
  }

  // =====================================================================
  // PARAMÈTRES
  // =====================================================================
  function SettingsScreen({ nav }) {
    const [push, setPush] = React.useState(true);
    const [email, setEmail] = React.useState(false);
    const [bio, setBio] = React.useState(true);
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Paramètres', onBack: () => nav('profile') }),
      e(Body, { style: { gap: 18 } },
        e(Group, { title: 'Compte' },
          e(ListRow, { icon: 'person', iconTone: 'neutral', title: 'Informations personnelles', chevron: true }),
          e(Divider), e(ListRow, { icon: 'pin', iconTone: 'neutral', title: 'Modifier le code PIN', chevron: true }),
          e(Divider), e(ListRow, { icon: 'language', iconTone: 'neutral', title: 'Langue', trailing: e('span', { style: { fontSize: 13, color: 'var(--text-muted)' } }, 'Français'), chevron: true })),
        e(Group, { title: 'Notifications' },
          e(ListRow, { icon: 'notifications', iconTone: 'neutral', title: 'Notifications push', trailing: e(Switch, { checked: push, onChange: setPush }) }),
          e(Divider), e(ListRow, { icon: 'mail', iconTone: 'neutral', title: 'E-mails', trailing: e(Switch, { checked: email, onChange: setEmail }) })),
        e(Group, { title: 'Sécurité' },
          e(ListRow, { icon: 'fingerprint', iconTone: 'neutral', title: 'Déverrouillage biométrique', trailing: e(Switch, { checked: bio, onChange: setBio }) }),
          e(Divider), e(ListRow, { icon: 'devices', iconTone: 'neutral', title: 'Appareils connectés', chevron: true })),
        e(Group, { title: 'À propos' },
          e(ListRow, { icon: 'description', iconTone: 'neutral', title: 'Conditions d’utilisation', chevron: true }),
          e(Divider), e(ListRow, { icon: 'shield', iconTone: 'neutral', title: 'Confidentialité', chevron: true }),
          e(Divider), e(ListRow, { icon: 'help', iconTone: 'neutral', title: 'Aide & support', chevron: true, onClick: () => nav('help') })),
        e(Button, { block: true, variant: 'danger', icon: 'logout', onClick: () => nav('login') }, 'Se déconnecter'),
        e('div', { style: { textAlign: 'center', fontSize: 11.5, color: 'var(--text-faint)', fontFamily: 'var(--font-mono)' } }, 'PRO COLIS · v1.0.0'),
      ),
    );
  }
  function Group({ title, children }) {
    return e('div', null,
      e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 12, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '.06em', margin: '0 2px 8px' } }, title),
      e(Card, { padding: 'none' }, children));
  }

  // =====================================================================
  // AIDE & SUPPORT
  // =====================================================================
  function HelpScreen({ nav }) {
    return e('div', { style: colStyle },
      e(AppBar, { title: 'Aide & support', onBack: () => nav('profile') }),
      e(Body, { style: { gap: 18 } },
        e('div', { style: { display: 'flex', alignItems: 'center', gap: 10, padding: '0 14px', height: 48, background: 'var(--surface-card)', border: '1px solid var(--border-subtle)', borderRadius: 'var(--radius-md)' } },
          e('span', { className: 'material-symbols-rounded', style: { color: 'var(--text-muted)' } }, 'search'),
          e('span', { style: { fontSize: 14, color: 'var(--text-faint)' } }, 'Rechercher une question…')),
        e('div', null,
          e(SectionHeader, { title: 'Catégories' }),
          e('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 } },
            M.helpTopics.map((t, i) => e('button', { key: i, style: { textAlign: 'left', cursor: 'pointer', background: 'var(--surface-card)', border: '1px solid var(--border-subtle)', borderRadius: 'var(--radius-md)', padding: 14, boxShadow: 'var(--shadow-xs)' } },
              e('span', { style: { display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 40, height: 40, borderRadius: 'var(--radius-sm)', background: 'var(--color-primary-soft)' } },
                e('span', { className: 'material-symbols-rounded', style: { fontSize: 22, color: 'var(--color-primary)' } }, t.icon)),
              e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 13.5, color: 'var(--text-strong)', marginTop: 8, lineHeight: 1.3 } }, t.title))))),
        e('div', null,
          e(SectionHeader, { title: 'Questions fréquentes' }),
          e(Card, { padding: 'none' }, M.faq.map((f, i) => e(Faq, { key: i, item: f, divider: i > 0 })))),
        e(Card, { padding: 'md', style: { background: 'var(--color-primary-soft)', border: '1px solid var(--teal-100)' } },
          e('div', { style: { display: 'flex', alignItems: 'center', gap: 12 } },
            e('span', { className: 'material-symbols-rounded', style: { fontSize: 30, color: 'var(--color-primary)' } }, 'support_agent'),
            e('div', { style: { flex: 1 } },
              e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 15, color: 'var(--text-strong)' } }, 'Besoin d’aide ?'),
              e('div', { style: { fontSize: 12.5, color: 'var(--text-muted)' } }, 'Notre équipe répond 7j/7')),
            e(Button, { size: 'sm', icon: 'chat' }, 'Contacter'))),
      ),
    );
  }
  function Faq({ item, divider }) {
    const [open, setOpen] = React.useState(false);
    return e('div', null,
      divider ? e(Divider) : null,
      e('button', { onClick: () => setOpen(!open), style: { width: '100%', display: 'flex', alignItems: 'center', gap: 10, padding: '14px 16px', background: 'transparent', border: 'none', cursor: 'pointer', textAlign: 'left' } },
        e('span', { style: { flex: 1, fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 14, color: 'var(--text-strong)' } }, item.q),
        e('span', { className: 'material-symbols-rounded', style: { fontSize: 22, color: 'var(--text-muted)', transform: open ? 'rotate(180deg)' : 'none', transition: 'transform .2s' } }, 'expand_more')),
      open ? e('div', { style: { padding: '0 16px 14px', fontSize: 13.5, color: 'var(--text-muted)', lineHeight: 1.55 } }, item.a) : null);
  }

  window.PCScreens = Object.assign(window.PCScreens || {}, { DetailScreen, LibreServiceScreen, WalletScreen, TopUpScreen, ConfirmDeliveryScreen, ProofScreen, ChatScreen, SettingsScreen, HelpScreen });
})();
