import React from 'react';

/** Checkbox with label (terms, multi-select filters). */
export function Checkbox({ checked = false, onChange, label, disabled = false, id, style }) {
  const fid = id || React.useId();
  return (
    <label htmlFor={fid} style={{ display: 'inline-flex', alignItems: 'center', gap: 10, cursor: disabled ? 'not-allowed' : 'pointer', opacity: disabled ? 0.5 : 1, ...style }}>
      <button
        id={fid} role="checkbox" aria-checked={checked} disabled={disabled}
        onClick={() => onChange && onChange(!checked)}
        style={{
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center', flex: 'none',
          width: 22, height: 22, padding: 0,
          background: checked ? 'var(--color-primary)' : 'var(--surface-card)',
          border: `2px solid ${checked ? 'var(--color-primary)' : 'var(--border-strong)'}`,
          borderRadius: 7, cursor: disabled ? 'not-allowed' : 'pointer',
          transition: 'background var(--dur-fast), border-color var(--dur-fast)',
        }}
      >
        {checked && <span className="material-symbols-rounded" style={{ fontSize: 16, color: '#fff', fontVariationSettings: "'wght' 700" }}>check</span>}
      </button>
      {label && <span style={{ fontFamily: 'var(--font-body)', fontWeight: 500, fontSize: 14, color: 'var(--text-body)' }}>{label}</span>}
    </label>
  );
}
