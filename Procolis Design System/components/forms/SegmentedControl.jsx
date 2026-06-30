import React from 'react';

/** Segmented control — role switch, status filters, mode toggles. */
export function SegmentedControl({ options = [], value, onChange, size = 'md', block = false, style }) {
  const norm = options.map((o) => (typeof o === 'string' ? { value: o, label: o } : o));
  const sizes = { sm: { h: 34, fs: 12.5, px: 12 }, md: { h: 42, fs: 14, px: 16 } };
  const s = sizes[size] || sizes.md;
  return (
    <div style={{
      display: block ? 'flex' : 'inline-flex', width: block ? '100%' : 'auto',
      padding: 4, gap: 4, background: 'var(--surface-sunken)', borderRadius: 'var(--radius-md)', ...style,
    }}>
      {norm.map((o) => {
        const active = o.value === value;
        return (
          <button
            key={o.value} onClick={() => onChange && onChange(o.value)}
            style={{
              flex: block ? 1 : 'none', display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 6,
              height: s.h, padding: `0 ${s.px}px`,
              fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: s.fs,
              color: active ? 'var(--color-primary)' : 'var(--text-muted)',
              background: active ? 'var(--surface-card)' : 'transparent',
              border: 'none', borderRadius: 'var(--radius-sm)',
              boxShadow: active ? 'var(--shadow-xs)' : 'none', cursor: 'pointer',
              transition: 'background var(--dur-fast), color var(--dur-fast)', whiteSpace: 'nowrap',
            }}
          >
            {o.icon && <span className="material-symbols-rounded" style={{ fontSize: 18 }}>{o.icon}</span>}
            {o.label}
          </button>
        );
      })}
    </div>
  );
}
