import React from 'react';

/** Compact metric tile for dashboards (colis en cours, chauffeurs dispo…). */
export function StatBox({ value, label, icon, tone = 'neutral', delta, style }) {
  const tones = {
    neutral: { bg: 'var(--surface-sunken)', fg: 'var(--text-muted)' },
    primary: { bg: 'var(--color-primary-soft)', fg: 'var(--color-primary)' },
    green:   { bg: 'var(--green-50)', fg: 'var(--green-700)' },
    amber:   { bg: 'var(--amber-50)', fg: 'var(--amber-600)' },
    red:     { bg: 'var(--red-50)', fg: 'var(--red-500)' },
  };
  const t = tones[tone] || tones.neutral;
  return (
    <div style={{
      display: 'flex', flexDirection: 'column', gap: 10, padding: 'var(--space-4)',
      background: 'var(--surface-card)', border: '1px solid var(--border-subtle)',
      borderRadius: 'var(--radius-md)', boxShadow: 'var(--shadow-xs)', ...style,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        {icon && (
          <span style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 36, height: 36, borderRadius: 'var(--radius-sm)', background: t.bg, color: t.fg }}>
            <span className="material-symbols-rounded" style={{ fontSize: 20, fontVariationSettings: "'FILL' 1" }}>{icon}</span>
          </span>
        )}
        {delta != null && (
          <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 600, fontSize: 12, color: delta >= 0 ? 'var(--green-600)' : 'var(--red-500)' }}>
            {delta >= 0 ? '▲' : '▼'} {Math.abs(delta)}%
          </span>
        )}
      </div>
      <div>
        <div style={{ fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 26, lineHeight: 1, color: 'var(--text-strong)' }}>{value}</div>
        <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 5, fontWeight: 500 }}>{label}</div>
      </div>
    </div>
  );
}
