import React from 'react';

/** Status meta for the colis lifecycle. Keys match the spec's statuses. */
export const PARCEL_STATUS = {
  pending:    { label: 'En attente',   icon: 'schedule',       key: 'pending' },
  free:       { label: 'Libre service', icon: 'sell',          key: 'free' },
  confirmed:  { label: 'Confirmé',     icon: 'check_circle',   key: 'confirmed' },
  pickup:     { label: 'Ramassé',      icon: 'package_2',      key: 'pickup' },
  transit:    { label: 'En transit',   icon: 'local_shipping', key: 'transit' },
  arrived:    { label: 'Arrivé',       icon: 'pin_drop',       key: 'arrived' },
  delivering: { label: 'En livraison', icon: 'moving',         key: 'delivering' },
  delivered:  { label: 'Livré',        icon: 'task_alt',       key: 'delivered' },
  cancelled:  { label: 'Annulé',       icon: 'cancel',         key: 'cancelled' },
};

/** Pill badge for a parcel's lifecycle status. Colors come from --status-*. */
export function StatusBadge({ status = 'pending', size = 'md', showIcon = true, label, style }) {
  const meta = PARCEL_STATUS[status] || PARCEL_STATUS.pending;
  const k = meta.key;
  const sizes = { sm: { h: 22, fs: 10.5, px: 8, ic: 13, dot: 6 }, md: { h: 28, fs: 11.5, px: 11, ic: 15, dot: 7 } };
  const s = sizes[size] || sizes.md;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 6, height: s.h, padding: `0 ${s.px}px`,
      background: `var(--status-${k}-bg)`, color: `var(--status-${k}-fg)`,
      borderRadius: 'var(--radius-pill)',
      fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: s.fs,
      letterSpacing: '0.05em', textTransform: 'uppercase', whiteSpace: 'nowrap', ...style,
    }}>
      {showIcon
        ? <span className="material-symbols-rounded" style={{ fontSize: s.ic, fontVariationSettings: "'FILL' 1, 'wght' 500" }}>{meta.icon}</span>
        : <span style={{ width: s.dot, height: s.dot, borderRadius: '50%', background: `var(--status-${k}-dot)` }} />}
      {label || meta.label}
    </span>
  );
}
