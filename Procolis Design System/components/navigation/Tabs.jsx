import React from 'react';

/** Underline tabs for in-page sections (filters, detail panels). */
export function Tabs({ items = [], value, onChange, style }) {
  const norm = items.map((o) => (typeof o === 'string' ? { value: o, label: o } : o));
  return (
    <div style={{ display: 'flex', gap: 4, borderBottom: '1px solid var(--border-subtle)', ...style }}>
      {norm.map((it) => {
        const active = it.value === value;
        return (
          <button
            key={it.value} onClick={() => onChange && onChange(it.value)}
            style={{
              display: 'inline-flex', alignItems: 'center', gap: 6, padding: '10px 14px',
              border: 'none', background: 'transparent', cursor: 'pointer',
              fontFamily: 'var(--font-display)', fontWeight: active ? 700 : 600, fontSize: 14,
              color: active ? 'var(--color-primary)' : 'var(--text-muted)',
              borderBottom: `2px solid ${active ? 'var(--color-primary)' : 'transparent'}`,
              marginBottom: -1, transition: 'color var(--dur-fast)', whiteSpace: 'nowrap',
            }}
          >
            {it.label}
            {it.count != null && (
              <span style={{
                minWidth: 18, height: 18, padding: '0 5px', display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                background: active ? 'var(--color-primary-soft)' : 'var(--surface-sunken)',
                color: active ? 'var(--color-primary)' : 'var(--text-muted)',
                borderRadius: 'var(--radius-pill)', fontSize: 11, fontWeight: 700,
              }}>{it.count}</span>
            )}
          </button>
        );
      })}
    </div>
  );
}
