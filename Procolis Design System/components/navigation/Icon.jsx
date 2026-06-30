import React from 'react';

/** Material Symbols Rounded icon wrapper. */
export function Icon({ name, size = 24, fill = false, weight = 400, color = 'currentColor', style, ...rest }) {
  return (
    <span
      className="material-symbols-rounded"
      style={{
        fontSize: size, color, lineHeight: 1, flex: 'none',
        fontVariationSettings: `'FILL' ${fill ? 1 : 0}, 'wght' ${weight}, 'GRAD' 0, 'opsz' 24`,
        ...style,
      }}
      {...rest}
    >
      {name}
    </span>
  );
}
