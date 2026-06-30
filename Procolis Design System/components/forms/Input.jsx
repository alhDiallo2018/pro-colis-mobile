import React from 'react';

/** Labeled text field with optional leading icon, suffix, error/help. */
export function Input({
  label,
  value,
  onChange,
  placeholder,
  type = 'text',
  icon,
  suffix,
  error,
  help,
  disabled = false,
  mono = false,
  id,
  style,
  ...rest
}) {
  const [focus, setFocus] = React.useState(false);
  const fid = id || React.useId();
  const borderColor = error ? 'var(--color-danger)' : (focus ? 'var(--border-focus)' : 'var(--border-default)');
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6, ...style }}>
      {label && (
        <label htmlFor={fid} style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 13, color: 'var(--text-body)' }}>{label}</label>
      )}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        height: 48, padding: '0 14px',
        background: disabled ? 'var(--surface-sunken)' : 'var(--surface-card)',
        border: `1px solid ${borderColor}`,
        borderRadius: 'var(--radius-md)',
        boxShadow: focus && !error ? 'var(--ring-focus)' : 'none',
        transition: 'border-color var(--dur-fast), box-shadow var(--dur-fast)',
      }}>
        {icon && <span className="material-symbols-rounded" style={{ fontSize: 20, color: focus ? 'var(--color-primary)' : 'var(--text-faint)' }}>{icon}</span>}
        <input
          id={fid}
          type={type}
          value={value}
          onChange={onChange}
          placeholder={placeholder}
          disabled={disabled}
          onFocus={() => setFocus(true)}
          onBlur={() => setFocus(false)}
          style={{
            flex: 1, minWidth: 0, border: 'none', outline: 'none', background: 'transparent',
            fontFamily: mono ? 'var(--font-mono)' : 'var(--font-body)',
            fontWeight: mono ? 600 : 500, fontSize: 15, color: 'var(--text-strong)',
            letterSpacing: mono ? '0.02em' : 0,
          }}
          {...rest}
        />
        {suffix && <span style={{ fontFamily: 'var(--font-mono)', fontSize: 13, color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>{suffix}</span>}
      </div>
      {(error || help) && (
        <span style={{ fontSize: 12, color: error ? 'var(--color-danger)' : 'var(--text-muted)' }}>{error || help}</span>
      )}
    </div>
  );
}
