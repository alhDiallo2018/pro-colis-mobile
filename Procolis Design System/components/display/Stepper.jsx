import React from 'react';

/**
 * Vertical timeline of the parcel lifecycle / tracking events.
 * steps: [{ label, time, status: 'done'|'current'|'todo', icon, note }]
 */
export function Stepper({ steps = [], style }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', ...style }}>
      {steps.map((st, i) => {
        const last = i === steps.length - 1;
        const done = st.status === 'done';
        const current = st.status === 'current';
        const dotBg = done ? 'var(--green-500)' : current ? 'var(--color-primary)' : 'var(--surface-card)';
        const dotBorder = done ? 'var(--green-500)' : current ? 'var(--color-primary)' : 'var(--border-default)';
        const lineColor = done ? 'var(--green-300)' : 'var(--border-default)';
        return (
          <div key={i} style={{ display: 'flex', gap: 14, minHeight: last ? 'auto' : 56 }}>
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flex: 'none' }}>
              <span style={{
                display: 'inline-flex', alignItems: 'center', justifyContent: 'center', width: 30, height: 30,
                borderRadius: '50%', background: dotBg, border: `2px solid ${dotBorder}`,
                boxShadow: current ? 'var(--ring-focus)' : 'none', flex: 'none',
              }}>
                {(done || current) && (
                  <span className="material-symbols-rounded" style={{ fontSize: 17, color: '#fff', fontVariationSettings: "'wght' 600" }}>
                    {st.icon || (done ? 'check' : 'local_shipping')}
                  </span>
                )}
              </span>
              {!last && <span style={{ width: 2, flex: 1, minHeight: 22, background: lineColor, marginTop: 2, marginBottom: 2 }} />}
            </div>
            <div style={{ paddingBottom: last ? 0 : 16, paddingTop: 4 }}>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, flexWrap: 'wrap' }}>
                <span style={{ fontFamily: 'var(--font-display)', fontWeight: current ? 700 : 600, fontSize: 14.5, color: current || done ? 'var(--text-strong)' : 'var(--text-muted)' }}>{st.label}</span>
                {st.time && <span style={{ fontFamily: 'var(--font-mono)', fontSize: 11.5, color: 'var(--text-faint)' }}>{st.time}</span>}
              </div>
              {st.note && <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 3 }}>{st.note}</div>}
            </div>
          </div>
        );
      })}
    </div>
  );
}
