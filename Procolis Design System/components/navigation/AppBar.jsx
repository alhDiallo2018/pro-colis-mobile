import React from 'react';

/** Mobile top app bar. Optional brand-gradient hero variant. */
export function AppBar({ title, subtitle, leading, actions, variant = 'default', onBack, style }) {
  const gradient = variant === 'brand';
  return (
    <header style={{
      display: 'flex', alignItems: 'center', gap: 10, height: 56, padding: '0 8px 0 6px',
      background: gradient ? 'var(--gradient-brand)' : 'var(--surface-card)',
      borderBottom: gradient ? 'none' : '1px solid var(--border-subtle)',
      color: gradient ? '#fff' : 'var(--text-strong)', ...style,
    }}>
      {onBack ? (
        <button onClick={onBack} aria-label="Retour" style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 44, height: 44, border: 'none', background: 'transparent', color: 'inherit', cursor: 'pointer', borderRadius: 'var(--radius-sm)' }}>
          <span className="material-symbols-rounded" style={{ fontSize: 24 }}>arrow_back</span>
        </button>
      ) : leading || <span style={{ width: 8 }} />}
      <div style={{ flex: 1, minWidth: 0, paddingLeft: onBack || leading ? 0 : 8 }}>
        <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 18, lineHeight: 1.1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{title}</div>
        {subtitle && <div style={{ fontSize: 12.5, opacity: gradient ? 0.85 : 1, color: gradient ? '#fff' : 'var(--text-muted)', marginTop: 1 }}>{subtitle}</div>}
      </div>
      {actions && <div style={{ display: 'flex', alignItems: 'center', gap: 2, flex: 'none' }}>{actions}</div>}
    </header>
  );
}
