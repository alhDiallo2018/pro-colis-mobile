import React from 'react';

/** Outlined tag/chip — parcel type, route options, filters. The "express"
 *  tone echoes the brand red chevrons (»). */
export function Tag({ children, tone = 'neutral', icon, express = false, style }) {
  if (express) {
    return (
      <span style={{
        display: 'inline-flex', alignItems: 'center', gap: 4, height: 24, padding: '0 9px',
        background: 'var(--red-50)', color: 'var(--red-500)', border: '1px solid var(--red-100)',
        borderRadius: 'var(--radius-sm)', fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: 11.5,
        letterSpacing: '0.04em', textTransform: 'uppercase', ...style,
      }}>
        <span style={{ fontWeight: 800, letterSpacing: '-1px' }}>»</span>
        {children || 'Express'}
      </span>
    );
  }
  const tones = {
    neutral: 'var(--text-body)', primary: 'var(--color-primary)', amber: 'var(--amber-600)', green: 'var(--green-700)',
  };
  const fg = tones[tone] || tones.neutral;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5, height: 26, padding: '0 10px',
      background: 'var(--surface-card)', color: fg, border: '1px solid var(--border-default)',
      borderRadius: 'var(--radius-sm)', fontFamily: 'var(--font-body)', fontWeight: 600, fontSize: 12.5, ...style,
    }}>
      {icon && <span className="material-symbols-rounded" style={{ fontSize: 15 }}>{icon}</span>}
      {children}
    </span>
  );
}
