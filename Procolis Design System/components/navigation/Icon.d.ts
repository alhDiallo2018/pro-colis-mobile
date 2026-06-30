import React from 'react';
export interface IconProps {
  /** Material Symbols Rounded glyph name */
  name: string;
  size?: number;
  /** Filled variant @default false */
  fill?: boolean;
  weight?: number;
  color?: string;
  style?: React.CSSProperties;
}
/** Material Symbols Rounded icon — matches the Flutter app's Material icon set. */
export function Icon(props: IconProps): JSX.Element;
