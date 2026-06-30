import React from 'react';

/** Small inline badge for counts, generic labels, semantic states. */
export function Badge({ children, tone = 'neutral', variant = 'soft', icon, style }) {
  const map = {
    neutral: { soft: ['var(--surface-sunken)', 'var(--text-body)'], solid: ['var(--slate-700)', '#fff'] },
    primary: { soft: ['var(--color-primary-soft)', 'var(--color-primary)'], solid: ['var(--color-primary)', '#fff'] },
    green:   { soft: ['var(--green-50)', 'var(--green-700)'], solid: ['var(--green-600)', '#fff'] },
    amber:   { soft: ['var(--amber-50)', 'var(--amber-600)'], solid: ['var(--amber-400)', '#3a2600'] },
    red:     { soft: ['var(--red-50)', 'var(--red-500)'], solid: ['var(--red-400)', '#fff'] },
  };
  const [bg, fg] = (map[tone] || map.neutral)[variant] || (map[tone] || map.neutral).soft;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 4, height: 22, padding: '0 8px',
      background: bg, color: fg, borderRadius: 'var(--radius-pill)',
      fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 11.5, letterSpacing: '0.01em', whiteSpace: 'nowrap', ...style,
    }}>
      {icon && <span className="material-symbols-rounded" style={{ fontSize: 14 }}>{icon}</span>}
      {children}
    </span>
  );
}
