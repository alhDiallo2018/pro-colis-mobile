import React from 'react';

/** Multi-line text area (parcel notes, offer messages). */
export function Textarea({ label, value, onChange, placeholder, rows = 3, error, help, maxLength, disabled = false, id, style, ...rest }) {
  const [focus, setFocus] = React.useState(false);
  const fid = id || React.useId();
  const borderColor = error ? 'var(--color-danger)' : (focus ? 'var(--border-focus)' : 'var(--border-default)');
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6, ...style }}>
      {label && <label htmlFor={fid} style={{ fontFamily: 'var(--font-display)', fontWeight: 600, fontSize: 13, color: 'var(--text-body)' }}>{label}</label>}
      <textarea
        id={fid} value={value} onChange={onChange} placeholder={placeholder} rows={rows} maxLength={maxLength} disabled={disabled}
        onFocus={() => setFocus(true)} onBlur={() => setFocus(false)}
        style={{
          resize: 'vertical', padding: '12px 14px',
          background: disabled ? 'var(--surface-sunken)' : 'var(--surface-card)',
          border: `1px solid ${borderColor}`, borderRadius: 'var(--radius-md)',
          boxShadow: focus && !error ? 'var(--ring-focus)' : 'none',
          fontFamily: 'var(--font-body)', fontWeight: 500, fontSize: 15, lineHeight: 1.5,
          color: 'var(--text-strong)', outline: 'none',
          transition: 'border-color var(--dur-fast), box-shadow var(--dur-fast)',
        }}
        {...rest}
      />
      <div style={{ display: 'flex', justifyContent: 'space-between' }}>
        <span style={{ fontSize: 12, color: error ? 'var(--color-danger)' : 'var(--text-muted)' }}>{error || help || ''}</span>
        {maxLength != null && <span style={{ fontSize: 12, color: 'var(--text-faint)', fontFamily: 'var(--font-mono)' }}>{(value || '').length}/{maxLength}</span>}
      </div>
    </div>
  );
}
