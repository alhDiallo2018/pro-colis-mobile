import React from 'react';

/** User avatar with initials fallback, optional online/availability dot. */
export function Avatar({ name = '', src, size = 'md', status, square = false, style }) {
  const sizes = { xs: 28, sm: 36, md: 44, lg: 56, xl: 72 };
  const d = sizes[size] || sizes.md;
  const initials = name.split(' ').filter(Boolean).slice(0, 2).map((p) => p[0]).join('').toUpperCase();
  const hue = [...name].reduce((a, c) => a + c.charCodeAt(0), 0) % 4;
  const palettes = [
    ['var(--teal-100)', 'var(--teal-700)'],
    ['var(--green-100)', 'var(--green-800)'],
    ['var(--amber-100)', 'var(--amber-700)'],
    ['var(--color-info-soft)', 'var(--deep-700)'],
  ][hue];
  const statusColors = { online: 'var(--green-500)', busy: 'var(--amber-400)', offline: 'var(--slate-300)' };
  return (
    <span style={{ position: 'relative', display: 'inline-flex', flex: 'none', width: d, height: d, ...style }}>
      <span style={{
        width: d, height: d, borderRadius: square ? 'var(--radius-md)' : '50%', overflow: 'hidden',
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        background: src ? 'var(--surface-sunken)' : palettes[0], color: palettes[1],
        fontFamily: 'var(--font-display)', fontWeight: 700, fontSize: d * 0.38,
      }}>
        {src ? <img src={src} alt={name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : initials}
      </span>
      {status && (
        <span style={{
          position: 'absolute', right: -1, bottom: -1, width: d * 0.28, height: d * 0.28,
          minWidth: 9, minHeight: 9, borderRadius: '50%', background: statusColors[status] || 'var(--slate-300)',
          border: '2px solid var(--surface-card)',
        }} />
      )}
    </span>
  );
}
