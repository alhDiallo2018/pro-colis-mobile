import React from 'react';

/** Native select styled to match Procolis inputs. */
export function Select({ label, value, onChange, options = [], placeholder, icon, error, disabled = false, id, style, ...rest }) {
  const [focus, setFocus] = React.useState(false);
  const fid = id || React.useId();
  const borderColor = error ? 'var(--color-danger)' : (focus ? 'var(--border-focus)' : 'var(--border-default)');
  const norm = options.map((o) => (typeof o === 'string' ? { value: o, label: o } : o));
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6, ...style }}>
      {label && <label htmlFor={fid} style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 13, color: 'var(--text-body)' }}>{label}</label>}
      <div style={{
        position: 'relative', display: 'flex', alignItems: 'center', gap: 8, height: 48, padding: '0 14px',
        background: disabled ? 'var(--surface-sunken)' : 'var(--surface-card)',
        border: `1px solid ${borderColor}`, borderRadius: 'var(--radius-md)',
        boxShadow: focus && !error ? 'var(--ring-focus)' : 'none',
        transition: 'border-color var(--dur-fast), box-shadow var(--dur-fast)',
      }}>
        {icon && <span className="material-symbols-rounded" style={{ fontSize: 20, color: focus ? 'var(--color-primary)' : 'var(--text-faint)' }}>{icon}</span>}
        <select
          id={fid} value={value} onChange={onChange} disabled={disabled}
          onFocus={() => setFocus(true)} onBlur={() => setFocus(false)}
          style={{
            flex: 1, minWidth: 0, appearance: 'none', WebkitAppearance: 'none', border: 'none', outline: 'none', background: 'transparent',
            fontFamily: 'var(--font-body)', fontWeight: 500, fontSize: 15,
            color: value ? 'var(--text-strong)' : 'var(--text-faint)', cursor: disabled ? 'not-allowed' : 'pointer',
          }}
          {...rest}
        >
          {placeholder && <option value="" disabled>{placeholder}</option>}
          {norm.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
        <span className="material-symbols-rounded" style={{ fontSize: 22, color: 'var(--text-muted)', pointerEvents: 'none' }}>expand_more</span>
      </div>
      {error && <span style={{ fontSize: 12, color: 'var(--color-danger)' }}>{error}</span>}
    </div>
  );
}
