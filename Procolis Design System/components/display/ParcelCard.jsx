import React from 'react';
import { StatusBadge } from './StatusBadge.jsx';

/**
 * The product's signature card: one colis with route, status, tracking & price.
 * parcel: { tracking, from, to, status, price, weight, type, eta, express }
 */
export function ParcelCard({ parcel = {}, onClick, footer, style }) {
  const { tracking, from = '—', to = '—', status = 'pending', price, weight, type, eta, express } = parcel;
  const [hover, setHover] = React.useState(false);
  return (
    <div
      onClick={onClick}
      onMouseEnter={() => setHover(true)} onMouseLeave={() => setHover(false)}
      style={{
        background: 'var(--surface-card)', border: '1px solid var(--border-subtle)',
        borderRadius: 'var(--radius-lg)', padding: 'var(--space-4)',
        boxShadow: hover && onClick ? 'var(--shadow-md)' : 'var(--shadow-sm)',
        transform: hover && onClick ? 'translateY(-2px)' : 'none', cursor: onClick ? 'pointer' : 'default',
        transition: 'box-shadow var(--dur-base), transform var(--dur-base)', ...style,
      }}
    >
      {/* top row: tracking + status */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
          <span className="material-symbols-rounded" style={{ fontSize: 18, color: 'var(--text-faint)' }}>qr_code_2</span>
          <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 600, fontSize: 13, color: 'var(--text-body)', letterSpacing: '0.02em' }}>{tracking || '—'}</span>
          {express && <span style={{ fontFamily: 'var(--font-display)', fontWeight: 800, fontSize: 14, color: 'var(--red-400)', letterSpacing: '-1px' }}>»</span>}
        </span>
        <StatusBadge status={status} size="sm" />
      </div>

      {/* route */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, margin: '14px 0 12px' }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', color: 'var(--text-faint)', fontFamily: 'var(--font-display)' }}>Départ</div>
          <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 16, color: 'var(--text-strong)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{from}</div>
        </div>
        <span style={{ display: 'inline-flex', flexDirection: 'column', alignItems: 'center', color: 'var(--teal-400)', flex: 'none' }}>
          <span className="material-symbols-rounded" style={{ fontSize: 22 }}>local_shipping</span>
        </span>
        <div style={{ flex: 1, minWidth: 0, textAlign: 'right' }}>
          <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.07em', textTransform: 'uppercase', color: 'var(--text-faint)', fontFamily: 'var(--font-display)' }}>Arrivée</div>
          <div style={{ fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 16, color: 'var(--text-strong)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{to}</div>
        </div>
      </div>

      {/* meta strip */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 14, paddingTop: 12, borderTop: '1px solid var(--border-subtle)' }}>
        {weight && <Meta icon="weight" text={weight} />}
        {type && <Meta icon="category" text={type} />}
        {eta && <Meta icon="schedule" text={eta} />}
        {price != null && (
          <span style={{ marginLeft: 'auto', fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 16, color: 'var(--teal-600)' }}>{price}</span>
        )}
      </div>
      {footer && <div style={{ marginTop: 14 }}>{footer}</div>}
    </div>
  );
}

function Meta({ icon, text }) {
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontSize: 12.5, color: 'var(--text-muted)', fontWeight: 500 }}>
      <span className="material-symbols-rounded" style={{ fontSize: 16, color: 'var(--text-faint)' }}>{icon}</span>
      {text}
    </span>
  );
}
