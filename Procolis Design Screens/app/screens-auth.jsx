/* PRO COLIS — auth: connexion, inscription, OTP, PIN, oubli. window.PCScreens.* */
(function () {
  const NS = window.ProcolisDesignSystem_1720b4;
  const { Button, Input, Checkbox } = NS;
  const M = window.PCMock;
  const SH = window.PCShared;
  const e = React.createElement;

  function AuthHero({ sub }) {
    return e('div', { style: { background: 'var(--gradient-brand)', padding: '52px 24px 28px', color: '#fff', textAlign: 'center' } },
      e(SH.BrandMark, { size: 70, sub: sub || 'Vos colis, de ville en ville' }));
  }
  function PhonePrefix() {
    return e('div', { style: { display: 'flex', alignItems: 'center', gap: 6, padding: '0 12px', height: 48, border: '1px solid var(--border-default)', borderRadius: 'var(--radius-md)', background: 'var(--surface-card)', fontWeight: 600, color: 'var(--text-body)', fontSize: 15, whiteSpace: 'nowrap' } }, '🇨🇮 +225');
  }
  const scroll = { flex: 1, overflowY: 'auto', padding: '26px 24px 32px' };

  // =====================================================================
  // CONNEXION (login)
  // =====================================================================
  function LoginScreen({ nav }) {
    const [phone, setPhone] = React.useState('07 11 45 90');
    return e('div', { style: { display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--surface-page)' } },
      e(AuthHero, null),
      e('div', { style: scroll },
        e('h2', { style: SH.titleStyle }, 'Connexion'),
        e('p', { style: SH.subStyle }, 'Entrez votre numéro pour recevoir un code de vérification.'),
        e('div', { style: { display: 'flex', gap: 10, marginTop: 18 } },
          e(PhonePrefix),
          e('div', { style: { flex: 1 } }, e(Input, { value: phone, onChange: (ev) => setPhone(ev.target.value), placeholder: '07 00 00 00', mono: true, icon: 'call' }))),
        e('div', { style: { marginTop: 22 } }, e(Button, { block: true, size: 'lg', onClick: () => nav('otp'), iconTrailing: 'arrow_forward' }, 'Recevoir le code')),
        e('div', { style: { display: 'flex', alignItems: 'center', gap: 12, margin: '22px 0' } },
          e('span', { style: { flex: 1, height: 1, background: 'var(--border-subtle)' } }),
          e('span', { style: { fontSize: 12, color: 'var(--text-faint)' } }, 'ou'),
          e('span', { style: { flex: 1, height: 1, background: 'var(--border-subtle)' } })),
        e(Button, { block: true, variant: 'secondary', size: 'lg', icon: 'pin', onClick: () => nav('pin-entry') }, 'Se connecter avec un code PIN'),
        e('p', { style: { ...SH.subStyle, textAlign: 'center', marginTop: 26, fontSize: 13 } }, 'Pas encore de compte ? ',
          e('button', { onClick: () => nav('register'), style: { ...SH.linkBtn, fontWeight: 700, padding: 0 } }, 'Créer un compte')),
      ),
    );
  }

  // =====================================================================
  // INSCRIPTION (register) — with role selection
  // =====================================================================
  function RegisterScreen({ nav, setRole }) {
    const [role, setLocalRole] = React.useState('client');
    const [terms, setTerms] = React.useState(false);
    const roles = [
      { key: 'client', icon: 'package_2', title: 'Expéditeur', body: 'J’envoie des colis' },
      { key: 'driver', icon: 'local_shipping', title: 'Chauffeur', body: 'Je transporte des colis' },
    ];
    return e('div', { style: { display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--surface-page)' } },
      e('div', { style: { background: 'var(--gradient-brand)', padding: '46px 22px 22px', color: '#fff' } },
        e('button', { onClick: () => nav('login'), style: { border: 'none', background: 'rgba(255,255,255,.18)', color: '#fff', width: 38, height: 38, borderRadius: 'var(--radius-md)', cursor: 'pointer', display: 'inline-flex', alignItems: 'center', justifyContent: 'center' } },
          e('span', { className: 'material-symbols-rounded' }, 'arrow_back')),
        e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 24, marginTop: 14, letterSpacing: '-.01em' } }, 'Créer un compte'),
        e('div', { style: { fontSize: 13.5, opacity: .9, marginTop: 2 } }, 'Rejoignez Procolis en moins d’une minute.'),
      ),
      e('div', { style: scroll },
        e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 14, color: 'var(--text-strong)', marginBottom: 10 } }, 'Je suis…'),
        e('div', { style: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 22 } },
          roles.map((r) => {
            const sel = role === r.key;
            return e('button', { key: r.key, onClick: () => setLocalRole(r.key), style: { textAlign: 'left', cursor: 'pointer', padding: 14, borderRadius: 'var(--radius-lg)', border: `2px solid ${sel ? 'var(--color-primary)' : 'var(--border-subtle)'}`, background: sel ? 'var(--teal-50)' : 'var(--surface-card)' } },
              e('span', { className: 'material-symbols-rounded', style: { fontSize: 28, color: sel ? 'var(--color-primary)' : 'var(--text-muted)', fontVariationSettings: sel ? "'FILL' 1" : "'FILL' 0" } }, r.icon),
              e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 15, color: 'var(--text-strong)', marginTop: 6 } }, r.title),
              e('div', { style: { fontSize: 12, color: 'var(--text-muted)', marginTop: 1 } }, r.body));
          })),
        e('div', { style: { display: 'flex', flexDirection: 'column', gap: 12 } },
          e(Input, { label: 'Nom complet', icon: 'badge', placeholder: 'Ex : Awa Diallo' }),
          e('div', null,
            e('label', { style: { display: 'block', fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 13, color: 'var(--text-body)', marginBottom: 6 } }, 'Téléphone'),
            e('div', { style: { display: 'flex', gap: 10 } }, e(PhonePrefix), e('div', { style: { flex: 1 } }, e(Input, { placeholder: '07 00 00 00', mono: true })))),
          role === 'driver' ? e(Input, { label: 'Garage de rattachement', icon: 'garage', placeholder: 'Ex : Garage de Cocody' }) : null,
          role === 'driver' ? e(Input, { label: 'Immatriculation du véhicule', icon: 'directions_car', placeholder: 'Ex : 4821 CI 01', mono: true }) : null,
        ),
        e('div', { style: { marginTop: 18 } }, e(Checkbox, { checked: terms, onChange: setTerms, label: 'J’accepte les conditions d’utilisation et la politique de confidentialité.' })),
        e('div', { style: { marginTop: 18 } }, e(Button, { block: true, size: 'lg', disabled: !terms, iconTrailing: 'arrow_forward', onClick: () => { setRole(role); nav('otp-reg'); } }, 'Recevoir le code')),
      ),
    );
  }

  // =====================================================================
  // OTP — shared verification (next varies by entry point)
  // =====================================================================
  function OtpScreen({ nav, next, onBack }) {
    const [otp, setOtp] = React.useState('');
    const [secs, setSecs] = React.useState(42);
    React.useEffect(() => { const t = setInterval(() => setSecs((s) => s > 0 ? s - 1 : 0), 1000); return () => clearInterval(t); }, []);
    const push = (k) => { if (k === 'del') setOtp(otp.slice(0, -1)); else if (otp.length < 4) { const n = otp + k; setOtp(n); if (n.length === 4) setTimeout(() => nav(next), 220); } };
    return e('div', { style: { display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--surface-page)' } },
      e('div', { style: { padding: '56px 24px 0' } },
        e('button', { onClick: onBack, style: { border: '1px solid var(--border-subtle)', background: 'var(--surface-card)', color: 'var(--text-body)', width: 40, height: 40, borderRadius: 'var(--radius-md)', cursor: 'pointer', display: 'inline-flex', alignItems: 'center', justifyContent: 'center' } },
          e('span', { className: 'material-symbols-rounded' }, 'arrow_back')),
        e('h2', { style: { ...SH.titleStyle, marginTop: 18 } }, 'Vérification'),
        e('p', { style: SH.subStyle }, 'Saisissez le code à 4 chiffres envoyé au ', e('span', { style: { fontFamily: 'var(--font-mono)', color: 'var(--text-body)', fontWeight: 600 } }, '+221 76 516 27 96'), '.'),
      ),
      e('div', { style: { flex: 1, overflowY: 'auto', padding: '28px 24px 24px', display: 'flex', flexDirection: 'column' } },
        e(SH.OtpBoxes, { value: otp }),
        e('p', { style: { textAlign: 'center', fontSize: 13, color: 'var(--text-muted)', margin: '20px 0 0' } },
          secs > 0 ? e(React.Fragment, null, 'Renvoyer le code dans ', e('span', { style: { fontFamily: 'var(--font-mono)', color: 'var(--text-body)' } }, `00:${String(secs).padStart(2, '0')}`))
            : e('button', { onClick: () => setSecs(42), style: { ...SH.linkBtn, padding: 0 } }, 'Renvoyer le code')),
        e('div', { style: { marginTop: 'auto' } }, e(SH.Keypad, { onKey: push })),
      ),
    );
  }

  // =====================================================================
  // DÉFINIR LE CODE PIN (set) — confirm twice
  // =====================================================================
  function PinSetScreen({ nav, home }) {
    const [stage, setStage] = React.useState('create'); // create | confirm
    const [pin, setPin] = React.useState('');
    const [first, setFirst] = React.useState('');
    const [err, setErr] = React.useState(false);
    const push = (k) => {
      setErr(false);
      if (k === 'del') return setPin(pin.slice(0, -1));
      if (pin.length >= 4) return;
      const n = pin + k;
      setPin(n);
      if (n.length === 4) setTimeout(() => {
        if (stage === 'create') { setFirst(n); setPin(''); setStage('confirm'); }
        else if (n === first) home();
        else { setErr(true); setPin(''); }
      }, 180);
    };
    return e('div', { style: { display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--surface-page)' } },
      e('div', { style: { padding: '60px 24px 0', textAlign: 'center' } },
        e('span', { style: { display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 56, height: 56, borderRadius: 'var(--radius-lg)', background: 'var(--color-primary-soft)' } },
          e('span', { className: 'material-symbols-rounded', style: { fontSize: 30, color: 'var(--color-primary)', fontVariationSettings: "'FILL' 1" } }, 'lock')),
        e('h2', { style: { ...SH.titleStyle, marginTop: 14 } }, stage === 'create' ? 'Créez votre code PIN' : 'Confirmez le code'),
        e('p', { style: SH.subStyle }, stage === 'create' ? 'Choisissez un code à 4 chiffres pour vous connecter rapidement.' : 'Saisissez à nouveau votre code PIN.'),
      ),
      e('div', { style: { flex: 1, overflowY: 'auto', padding: '30px 24px 24px', display: 'flex', flexDirection: 'column', alignItems: 'center' } },
        e(SH.PinDots, { length: 4, filled: pin.length }),
        e('div', { style: { height: 20, marginTop: 12, fontSize: 13, color: 'var(--color-danger)', fontWeight: 600 } }, err ? 'Les codes ne correspondent pas. Réessayez.' : ''),
        e('div', { style: { marginTop: 'auto', width: '100%' } }, e(SH.Keypad, { onKey: push })),
      ),
    );
  }

  // =====================================================================
  // CODE PIN (entry) — quick login
  // =====================================================================
  function PinEntryScreen({ nav, home }) {
    const [pin, setPin] = React.useState('');
    const push = (k) => {
      if (k === 'bio') return home();
      if (k === 'del') return setPin(pin.slice(0, -1));
      if (pin.length >= 4) return;
      const n = pin + k; setPin(n);
      if (n.length === 4) setTimeout(home, 200);
    };
    return e('div', { style: { display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--surface-page)' } },
      e('div', { style: { padding: '64px 24px 0', textAlign: 'center' } },
        e(NS.Avatar, { name: M.user.name, size: 'xl', status: 'online' }),
        e('h2', { style: { ...SH.titleStyle, marginTop: 14 } }, `Bonjour, ${M.user.name.split(' ')[0]}`),
        e('p', { style: SH.subStyle }, 'Entrez votre code PIN pour continuer.'),
      ),
      e('div', { style: { flex: 1, overflowY: 'auto', padding: '30px 24px 24px', display: 'flex', flexDirection: 'column', alignItems: 'center' } },
        e(SH.PinDots, { length: 4, filled: pin.length }),
        e('div', { style: { marginTop: 18 } },
          e('button', { onClick: () => nav('forgot'), style: { ...SH.linkBtn, padding: 0 } }, 'Code PIN oublié ?')),
        e('div', { style: { marginTop: 'auto', width: '100%' } }, e(SH.Keypad, { onKey: push, biometric: true })),
        e('div', { style: { marginTop: 14 } },
          e('button', { onClick: () => nav('login'), style: { ...SH.linkBtn, color: 'var(--text-muted)' } }, 'Utiliser le numéro de téléphone')),
      ),
    );
  }

  // =====================================================================
  // PIN / MOT DE PASSE OUBLIÉ
  // =====================================================================
  function ForgotScreen({ nav }) {
    const [phone, setPhone] = React.useState('07 11 45 90');
    return e('div', { style: { display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--surface-page)' } },
      e('div', { style: { padding: '56px 24px 0' } },
        e('button', { onClick: () => nav('pin-entry'), style: { border: '1px solid var(--border-subtle)', background: 'var(--surface-card)', color: 'var(--text-body)', width: 40, height: 40, borderRadius: 'var(--radius-md)', cursor: 'pointer', display: 'inline-flex', alignItems: 'center', justifyContent: 'center' } },
          e('span', { className: 'material-symbols-rounded' }, 'arrow_back')),
        e('span', { className: 'material-symbols-rounded', style: { display: 'block', fontSize: 38, color: 'var(--color-primary)', marginTop: 18, fontVariationSettings: "'FILL' 1" } }, 'lock_reset'),
        e('h2', { style: { ...SH.titleStyle, marginTop: 10 } }, 'Code PIN oublié'),
        e('p', { style: SH.subStyle }, 'Nous vous enverrons un code de vérification pour réinitialiser votre code PIN.'),
      ),
      e('div', { style: scroll },
        e('div', { style: { display: 'flex', gap: 10 } },
          e(PhonePrefix),
          e('div', { style: { flex: 1 } }, e(Input, { value: phone, onChange: (ev) => setPhone(ev.target.value), placeholder: '07 00 00 00', mono: true, icon: 'call' }))),
        e('div', { style: { marginTop: 22 } }, e(Button, { block: true, size: 'lg', iconTrailing: 'arrow_forward', onClick: () => nav('otp-forgot') }, 'Envoyer le code')),
      ),
    );
  }

  window.PCScreens = Object.assign(window.PCScreens || {}, { LoginScreen, RegisterScreen, OtpScreen, PinSetScreen, PinEntryScreen, ForgotScreen });
})();
