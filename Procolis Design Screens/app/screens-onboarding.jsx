/* PRO COLIS — onboarding: splash, welcome carousel, permissions. window.PCScreens.* */
(function () {
  const NS = window.ProcolisDesignSystem_1720b4;
  const { Button } = NS;
  const M = window.PCMock;
  const SH = window.PCShared;
  const e = React.createElement;

  // =====================================================================
  // SPLASH
  // =====================================================================
  function SplashScreen({ nav }) {
    return e('div', { style: { height: '100%', background: 'var(--gradient-brand)', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', position: 'relative', overflow: 'hidden' } },
      // faint chevron motif
      e('div', { 'aria-hidden': true, style: { position: 'absolute', inset: 0, opacity: .08, color: '#fff', fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 120, display: 'flex', alignItems: 'center', justifyContent: 'center', letterSpacing: '-.05em' } }, '»»»'),
      e('div', { className: 'pc-splash-in', style: { textAlign: 'center', zIndex: 1 } },
        e('img', { src: 'assets/logo-procolis.png', alt: 'Procolis', style: { width: 104, height: 104, objectFit: 'contain', filter: 'drop-shadow(0 8px 22px rgba(0,0,0,.3))' } }),
        e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 34, letterSpacing: '-.02em', marginTop: 16, color: '#fff' } }, 'PRO COLIS'),
        e('div', { style: { fontSize: 15, opacity: .9, marginTop: 4, color: '#fff' } }, 'Vos colis, de ville en ville'),
      ),
      e('div', { style: { position: 'absolute', bottom: 54, left: 0, right: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18, zIndex: 1 } },
        e('span', { className: 'material-symbols-rounded pc-spin', style: { color: 'rgba(255,255,255,.85)', fontSize: 30 } }, 'progress_activity'),
        e('div', { style: { width: 200 } }, e(Button, { block: true, variant: 'amber', size: 'lg', onClick: () => nav('welcome') }, 'Commencer')),
      ),
    );
  }

  // =====================================================================
  // WELCOME CAROUSEL
  // =====================================================================
  function WelcomeScreen({ nav }) {
    const [i, setI] = React.useState(0);
    const slides = M.onboarding;
    const s = slides[i];
    const last = i === slides.length - 1;
    return e('div', { style: { height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--surface-page)' } },
      // skip
      e('div', { style: { display: 'flex', justifyContent: 'flex-end', padding: '52px 18px 0' } },
        e('button', { onClick: () => nav('permissions'), style: { ...SH.linkBtn, color: 'var(--text-muted)' } }, 'Passer')),
      // illustration
      e('div', { style: { flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '0 28px', textAlign: 'center' } },
        e('div', { key: i, className: 'pc-fade-in', style: { width: 188, height: 188, borderRadius: '50%', background: 'var(--gradient-brand-soft)', display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', marginBottom: 32 } },
          e('span', { style: { position: 'absolute', inset: 22, borderRadius: '50%', background: 'var(--color-primary-soft)' } }),
          e('span', { className: 'material-symbols-rounded', style: { fontSize: 80, color: 'var(--color-primary)', zIndex: 1, fontVariationSettings: "'FILL' 1, 'wght' 500" } }, s.icon),
          s.glyphs.map((g, gi) => e('span', {
            key: gi, className: 'material-symbols-rounded',
            style: { position: 'absolute', fontSize: 24, color: 'var(--color-primary)', background: '#fff', borderRadius: '50%', padding: 8, boxShadow: 'var(--shadow-sm)', ...[{ top: 4, left: 14 }, { bottom: 12, right: -4 }, { bottom: -4, left: 30 }][gi] } }, g)),
        ),
        e('h2', { key: 'h' + i, className: 'pc-fade-in', style: { fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 26, lineHeight: 1.2, letterSpacing: '-.01em', color: 'var(--text-strong)', margin: 0, whiteSpace: 'pre-line' } }, s.title),
        e('p', { key: 'p' + i, className: 'pc-fade-in', style: { fontSize: 15, color: 'var(--text-muted)', lineHeight: 1.55, margin: '14px 0 0', maxWidth: 300 } }, s.body),
      ),
      // dots + cta
      e('div', { style: { padding: '0 28px 44px' } },
        e('div', { style: { display: 'flex', gap: 8, justifyContent: 'center', marginBottom: 24 } },
          slides.map((_, di) => e('span', { key: di, onClick: () => setI(di), style: { width: di === i ? 26 : 8, height: 8, borderRadius: 99, background: di === i ? 'var(--color-primary)' : 'var(--slate-300)', transition: 'all .25s', cursor: 'pointer' } }))),
        e(Button, { block: true, size: 'lg', iconTrailing: last ? undefined : 'arrow_forward', onClick: () => last ? nav('permissions') : setI(i + 1) }, last ? 'Créer mon compte' : 'Suivant'),
        last ? null : e('div', { style: { textAlign: 'center', marginTop: 12 } },
          e('button', { onClick: () => nav('login'), style: SH.linkBtn }, 'J’ai déjà un compte')),
      ),
    );
  }

  // =====================================================================
  // PERMISSIONS
  // =====================================================================
  function PermissionsScreen({ nav }) {
    const [loc, setLoc] = React.useState(null);   // null | true | false
    const [notif, setNotif] = React.useState(null);
    const perms = [
      { key: 'loc', icon: 'pin_drop', title: 'Localisation', body: 'Pour suivre vos colis en temps réel et proposer les trajets les plus proches.', val: loc, set: setLoc },
      { key: 'notif', icon: 'notifications', title: 'Notifications', body: 'Pour être alerté des offres reçues, du statut du colis et de la livraison.', val: notif, set: setNotif },
    ];
    return e('div', { style: { height: '100%', display: 'flex', flexDirection: 'column', background: 'var(--surface-page)' } },
      e('div', { style: { padding: '60px 26px 0' } },
        e('span', { className: 'material-symbols-rounded', style: { fontSize: 40, color: 'var(--color-primary)', fontVariationSettings: "'FILL' 1" } }, 'verified_user'),
        e('h2', { style: { ...SH.titleStyle, marginTop: 14 } }, 'Quelques autorisations'),
        e('p', { style: { ...SH.subStyle, fontSize: 14.5 } }, 'Procolis fonctionne mieux avec ces accès. Vous pourrez les modifier à tout moment dans les réglages.'),
      ),
      e('div', { style: { flex: 1, overflowY: 'auto', padding: '24px 20px', display: 'flex', flexDirection: 'column', gap: 14 } },
        perms.map((p) => e('div', { key: p.key, style: { background: 'var(--surface-card)', border: `1px solid ${p.val === true ? 'var(--color-primary)' : 'var(--border-subtle)'}`, borderRadius: 'var(--radius-lg)', padding: 16, boxShadow: 'var(--shadow-xs)' } },
          e('div', { style: { display: 'flex', gap: 14, alignItems: 'flex-start' } },
            e('span', { style: { flex: 'none', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 46, height: 46, borderRadius: 'var(--radius-md)', background: 'var(--color-primary-soft)' } },
              e('span', { className: 'material-symbols-rounded', style: { fontSize: 24, color: 'var(--color-primary)', fontVariationSettings: "'FILL' 1" } }, p.icon)),
            e('div', { style: { flex: 1, minWidth: 0 } },
              e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 16, color: 'var(--text-strong)' } }, p.title),
              e('div', { style: { fontSize: 13, color: 'var(--text-muted)', lineHeight: 1.5, marginTop: 3 } }, p.body)),
            p.val === true ? e('span', { className: 'material-symbols-rounded', style: { color: 'var(--color-success)', fontSize: 26, fontVariationSettings: "'FILL' 1" } }, 'check_circle') : null),
          p.val === true ? null : e('div', { style: { display: 'flex', gap: 8, marginTop: 14 } },
            e(Button, { block: true, size: 'sm', onClick: () => p.set(true) }, 'Autoriser'),
            e(Button, { variant: 'ghost', size: 'sm', onClick: () => p.set(false) }, 'Plus tard')),
        )),
      ),
      e('div', { style: { padding: '0 20px 44px' } },
        e(Button, { block: true, size: 'lg', onClick: () => nav('register') }, 'Continuer'),
      ),
    );
  }

  window.PCScreens = Object.assign(window.PCScreens || {}, { SplashScreen, WelcomeScreen, PermissionsScreen });
})();
