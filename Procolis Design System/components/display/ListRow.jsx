import React from 'react';

/** Tappable list row: leading icon/avatar, title + subtitle, trailing meta. */
export function ListRow({ icon, iconTone = 'neutral', leading, title, subtitle, trailing, chevron = false, onClick, style }) {
  const tones = {
    neutral: ['var(--surface-sunken)', 'var(--text-muted)'],
    primary: ['var(--color-primary-soft)', 'var(--color-primary)'],
    green:   ['var(--green-50)', 'var(--green-700)'],
    amber:   ['var(--amber-50)', 'var(--amber-600)'],
  };
  const [bg, fg] = tones[iconTone] || tones.neutral;
  const [hover, setHover] = React.useState(false);
  const clickable = !!onClick;
  return (
    <div
      onClick={onClick}
      onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}
      style={{
        display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', minHeight: 60,
        background: hover && clickable ? 'var(--surface-sunken)' : 'transparent',
        borderRadius: 'var(--radius-md)', cursor: clickable ? 'pointer' : 'default',
        transition: 'background var(--dur-fast)', ...style,
      }}
    >
      {leading || (icon && (
        <span style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 40, height: 40, flex: 'none', borderRadius: 'var(--radius-sm)', background: bg, color: fg }}>
          <span className="material-symbols-rounded" style={{ fontSize: 22, fontVariationSettings: "'FILL' 1" }}>{icon}</span>
        </span>
      ))}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 15, color: 'var(--text-strong)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{title}</div>
        {subtitle && <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{subtitle}</div>}
      </div>
      {trailing && <div style={{ flex: 'none', display: 'flex', alignItems: 'center', gap: 8 }}>{trailing}</div>}
      {chevron && <span className="material-symbols-rounded" style={{ fontSize: 22, color: 'var(--text-faint)', flex: 'none' }}>chevron_right</span>}
    </div>
  );
}
