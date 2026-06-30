import React from 'react';

/** Surface container. Optional padding, interactive hover, accent edge. */
export function Card({ children, padding = 'md', interactive = false, elevation = 'sm', accent, onClick, style, ...rest }) {
  const pads = { none: 0, sm: 'var(--space-3)', md: 'var(--space-4)', lg: 'var(--space-5)' };
  const shadows = { none: 'none', xs: 'var(--shadow-xs)', sm: 'var(--shadow-sm)', md: 'var(--shadow-md)' };
  const [hover, setHover] = React.useState(false);
  return (
    <div
      onClick={onClick}
      onMouseEnter={() => interactive && setHover(true)}
      onMouseLeave={() => interactive && setHover(false)}
      style={{
        background: 'var(--surface-card)',
        border: '1px solid var(--border-subtle)',
        borderLeft: accent ? `3px solid ${accent}` : '1px solid var(--border-subtle)',
        borderRadius: 'var(--radius-md)',
        padding: pads[padding] ?? pads.md,
        boxShadow: hover ? 'var(--shadow-md)' : (shadows[elevation] ?? shadows.sm),
        transform: hover ? 'translateY(-2px)' : 'none',
        cursor: interactive ? 'pointer' : 'default',
        transition: 'box-shadow var(--dur-base) var(--ease-standard), transform var(--dur-base) var(--ease-standard)',
        ...style,
      }}
      {...rest}
    >
      {children}
    </div>
  );
}
