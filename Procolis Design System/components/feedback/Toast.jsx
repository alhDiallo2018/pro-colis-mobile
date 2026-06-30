import React from 'react';

/** Toast / snackbar. tone drives the accent + icon. */
export function Toast({ tone = 'success', title, message, onClose, style }) {
  const tones = {
    success: { c: 'var(--green-600)', bg: 'var(--green-50)', icon: 'check_circle' },
    error:   { c: 'var(--red-400)', bg: 'var(--red-50)', icon: 'error' },
    info:    { c: 'var(--deep-500)', bg: 'var(--color-info-soft)', icon: 'info' },
    warning: { c: 'var(--amber-500)', bg: 'var(--amber-50)', icon: 'warning' },
  };
  const t = tones[tone] || tones.success;
  return (
    <div style={{
      display: 'flex', alignItems: 'flex-start', gap: 12, padding: '12px 14px',
      background: 'var(--surface-card)', border: '1px solid var(--border-subtle)',
      borderLeft: `3px solid ${t.c}`, borderRadius: 'var(--radius-md)', boxShadow: 'var(--shadow-md)',
      maxWidth: 420, ...style,
    }}>
      <span style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 30, height: 30, flex: 'none', borderRadius: 'var(--radius-sm)', background: t.bg, color: t.c }}>
        <span className="material-symbols-rounded" style={{ fontSize: 20, fontVariationSettings: "'FILL' 1" }}>{t.icon}</span>
      </span>
      <div style={{ flex: 1, minWidth: 0, paddingTop: 1 }}>
        {title && <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 14, color: 'var(--text-strong)' }}>{title}</div>}
        {message && <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: title ? 2 : 0 }}>{message}</div>}
      </div>
      {onClose && (
        <button onClick={onClose} aria-label="Fermer" style={{ display: 'inline-flex', border: 'none', background: 'transparent', color: 'var(--text-faint)', cursor: 'pointer', padding: 2, flex: 'none' }}>
          <span className="material-symbols-rounded" style={{ fontSize: 18 }}>close</span>
        </button>
      )}
    </div>
  );
}
