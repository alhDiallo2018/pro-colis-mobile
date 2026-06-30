/* PRO COLIS — shared helpers & layout primitives. window.PCShared */
(function () {
  const NS = window.ProcolisDesignSystem_1720b4;
  const e = React.createElement;

  const colStyle = { display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--surface-page)' };

  const Body = (props) => e('div', { style: { flex: 1, overflowY: 'auto', padding: '16px 16px 96px', display: 'flex', flexDirection: 'column', ...props.style } }, props.children);

  function SectionHeader({ title, action, onAction }) {
    return e('div', { style: { display: 'flex', alignItems: 'center', justifyContent: 'space-between', margin: '4px 2px 10px' } },
      e('span', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 16, color: 'var(--text-strong)' } }, title),
      action && e('button', { onClick: onAction, style: { border: 'none', background: 'transparent', color: 'var(--text-link)', fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 13, cursor: 'pointer' } }, action),
    );
  }

  function FormSection({ title, icon, children }) {
    return e('div', null,
      e('div', { style: { display: 'flex', alignItems: 'center', gap: 7, marginBottom: 12 } },
        e('span', { className: 'material-symbols-rounded', style: { fontSize: 19, color: 'var(--color-primary)' } }, icon),
        e('span', { style: { fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 14.5, color: 'var(--text-strong)' } }, title)),
      e('div', { style: { display: 'flex', flexDirection: 'column', gap: 12 } }, children));
  }

  // Brand wordmark lockup used on splash/auth heroes
  function BrandMark({ size = 76, label = true, sub }) {
    return e('div', { style: { textAlign: 'center' } },
      e('img', { src: 'assets/logo-procolis.png', alt: 'Procolis', style: { width: size, height: size, objectFit: 'contain', filter: 'drop-shadow(0 6px 14px rgba(0,0,0,.25))' } }),
      label && e('div', { style: { fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: size * 0.34, letterSpacing: '-.02em', marginTop: 10, color: '#fff' } }, 'PRO COLIS'),
      sub && e('div', { style: { fontSize: 14, opacity: .9, marginTop: 2, color: '#fff' } }, sub),
    );
  }

  // Pin-dot row (filled circles), used by OTP/PIN
  function PinDots({ length, filled }) {
    return e('div', { style: { display: 'flex', gap: 14, justifyContent: 'center' } },
      Array.from({ length }).map((_, i) => e('span', { key: i, style: { width: 16, height: 16, borderRadius: '50%', background: i < filled ? 'var(--color-primary)' : 'var(--slate-200)', border: i < filled ? 'none' : '1px solid var(--border-default)', transition: 'background .15s' } })));
  }

  // Numeric keypad
  function Keypad({ onKey, biometric }) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', biometric ? 'bio' : '', '0', 'del'];
    return e('div', { style: { display: 'grid', gridTemplateColumns: 'repeat(3,1fr)', gap: 10, maxWidth: 264, margin: '0 auto' } },
      keys.map((k, i) => k === '' ? e('span', { key: i }) : e('button', {
        key: i, onClick: () => onKey(k),
        style: { height: 56, borderRadius: 'var(--radius-md)', border: '1px solid var(--border-subtle)', background: 'var(--surface-card)', fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 22, color: 'var(--text-strong)', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center' },
      }, k === 'del' ? e('span', { className: 'material-symbols-rounded', style: { fontSize: 24 } }, 'backspace')
        : k === 'bio' ? e('span', { className: 'material-symbols-rounded', style: { fontSize: 26, color: 'var(--color-primary)' } }, 'fingerprint')
        : k)),
    );
  }

  // OTP boxes
  function OtpBoxes({ value, length = 4 }) {
    return e('div', { style: { display: 'flex', gap: 12, justifyContent: 'center' } },
      Array.from({ length }).map((_, i) => e('div', {
        key: i,
        style: { width: 54, height: 64, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 26, color: 'var(--text-strong)', border: `2px solid ${value[i] ? 'var(--color-primary)' : 'var(--border-default)'}`, borderRadius: 'var(--radius-md)', background: 'var(--surface-card)', transition: 'border-color .15s' },
      }, value[i] || '')));
  }

  // small inline "voice note" waveform
  function Waveform({ active = 5 }) {
    const bars = [8, 14, 20, 12, 18, 24, 10, 16, 22, 9, 14, 18, 11];
    return e('span', { style: { display: 'inline-flex', alignItems: 'center', gap: 2, height: 24 } },
      bars.map((h, i) => e('span', { key: i, style: { width: 2.5, height: h, borderRadius: 2, background: i < active ? 'var(--color-primary)' : 'var(--teal-200)' } })));
  }

  const titleStyle = { fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 24, color: 'var(--text-strong)', margin: 0, letterSpacing: '-.01em' };
  const subStyle = { fontSize: 14, color: 'var(--text-muted)', margin: '6px 0 0', lineHeight: 1.5 };
  const linkBtn = { border: 'none', background: 'transparent', color: 'var(--text-link)', fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 13.5, cursor: 'pointer' };

  window.PCShared = { colStyle, Body, SectionHeader, FormSection, BrandMark, PinDots, Keypad, OtpBoxes, Waveform, titleStyle, subStyle, linkBtn };
})();
