import React from 'react';

/**
 * Bottom tab bar for the mobile app.
 * items: [{ key, label, icon, badge }]
 */
export function TabBar({ items = [], value, onChange, style }) {
  return (
    <nav style={{
      display: 'flex', alignItems: 'stretch', height: 64, padding: '0 6px',
      background: 'var(--surface-card)', borderTop: '1px solid var(--border-subtle)',
      boxShadow: '0 -2px 10px rgba(11,70,79,0.05)', ...style,
    }}>
      {items.map((it) => {
        const active = it.key === value;
        return (
          <button
            key={it.key} onClick={() => onChange && onChange(it.key)}
            style={{
              flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 3,
              border: 'none', background: 'transparent', cursor: 'pointer', position: 'relative', padding: '6px 0',
              color: active ? 'var(--color-primary)' : 'var(--text-faint)',
            }}
          >
            <span style={{ position: 'relative' }}>
              <span className="material-symbols-rounded" style={{ fontSize: 25, fontVariationSettings: `'FILL' ${active ? 1 : 0}, 'wght' ${active ? 600 : 400}` }}>{it.icon}</span>
              {it.badge != null && it.badge !== 0 && (
                <span style={{
                  position: 'absolute', top: -4, right: -8, minWidth: 16, height: 16, padding: '0 4px',
                  display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                  background: 'var(--red-400)', color: '#fff', borderRadius: 'var(--radius-pill)',
                  fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 10, border: '2px solid var(--surface-card)',
                }}>{it.badge}</span>
              )}
            </span>
            <span style={{ fontFamily: 'var(--font-display)', fontWeight: active ? 700 : 500, fontSize: 11 }}>{it.label}</span>
          </button>
        );
      })}
    </nav>
  );
}
