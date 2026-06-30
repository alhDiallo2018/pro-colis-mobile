import React from 'react';

/** Floating action button — "Nouveau colis". */
export function Fab({ icon = 'add', label, onClick, tone = 'primary', style }) {
  const [hover, setHover] = React.useState(false);
  const [press, setPress] = React.useState(false);
  const tones = {
    primary: { bg: 'var(--color-primary)', fg: '#fff', sh: 'var(--shadow-brand)', hb: 'var(--color-primary-hover)' },
    amber:   { bg: 'var(--color-accent)', fg: '#3a2600', sh: 'var(--shadow-amber)', hb: 'var(--color-accent-hover)' },
  };
  const t = tones[tone] || tones.primary;
  const extended = !!label;
  return (
    <button
      onClick={onClick} aria-label={label || 'Action'}
      onMouseEnter={() => setHover(true)} onMouseLeave={() => { setHover(false); setPress(false); }}
      onMouseDown={() => setPress(true)} onMouseUp={() => setPress(false)}
      style={{
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        height: 56, width: extended ? 'auto' : 56, padding: extended ? '0 22px 0 18px' : 0,
        background: hover ? t.hb : t.bg, color: t.fg, border: 'none',
        borderRadius: extended ? 'var(--radius-pill)' : '50%',
        boxShadow: press ? 'var(--shadow-sm)' : t.sh, cursor: 'pointer',
        transform: press ? 'scale(0.96)' : 'scale(1)',
        transition: 'background var(--dur-fast), transform var(--dur-fast), box-shadow var(--dur-fast)',
        fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 15, ...style,
      }}
    >
      <span className="material-symbols-rounded" style={{ fontSize: 26, fontVariationSettings: "'wght' 500" }}>{icon}</span>
      {label}
    </button>
  );
}
