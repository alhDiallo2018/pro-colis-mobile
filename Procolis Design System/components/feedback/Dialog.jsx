import React from 'react';

/** Centered modal dialog / confirmation (cancel parcel, accept offer). */
export function Dialog({ open = true, title, icon, iconTone = 'primary', children, actions, onClose, style }) {
  if (!open) return null;
  const tones = {
    primary: ['var(--color-primary-soft)', 'var(--color-primary)'],
    danger:  ['var(--color-danger-soft)', 'var(--color-danger)'],
    green:   ['var(--green-50)', 'var(--green-600)'],
    amber:   ['var(--amber-50)', 'var(--amber-600)'],
  };
  const [bg, fg] = tones[iconTone] || tones.primary;
  return (
    <div
      onClick={onClose}
      style={{
        position: 'fixed', inset: 0, zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center',
        padding: 20, background: 'rgba(10,58,67,0.45)', backdropFilter: 'blur(2px)',
        animation: 'pc-fade var(--dur-base) var(--ease-out)',
      }}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        role="dialog" aria-modal="true"
        style={{
          width: '100%', maxWidth: 380, background: 'var(--surface-card)', borderRadius: 'var(--radius-lg)',
          boxShadow: 'var(--shadow-lg)', padding: 'var(--space-6)', textAlign: 'center',
          animation: 'pc-pop var(--dur-base) var(--ease-out)', ...style,
        }}
      >
        {icon && (
          <span style={{ display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 56, height: 56, borderRadius: '50%', background: bg, color: fg, marginBottom: 14 }}>
            <span className="material-symbols-rounded" style={{ fontSize: 30, fontVariationSettings: "'FILL' 1" }}>{icon}</span>
          </span>
        )}
        {title && <h3 style={{ margin: '0 0 8px', fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 19, color: 'var(--text-strong)' }}>{title}</h3>}
        {children && <div style={{ fontSize: 14.5, color: 'var(--text-muted)', lineHeight: 1.5 }}>{children}</div>}
        {actions && <div style={{ display: 'flex', gap: 10, marginTop: 22 }}>{actions}</div>}
      </div>
      <style>{`@keyframes pc-fade{from{opacity:0}to{opacity:1}}@keyframes pc-pop{from{opacity:0;transform:translateY(8px) scale(0.97)}to{opacity:1;transform:none}}`}</style>
    </div>
  );
}
