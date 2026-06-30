import React from 'react';
export interface IconButtonProps {
  /** Material Symbols glyph name */
  icon: string;
  /** @default 'ghost' */
  variant?: 'ghost' | 'solid' | 'soft' | 'danger';
  /** @default 'md' */
  size?: 'sm' | 'md' | 'lg';
  /** Circular instead of rounded-square @default false */
  round?: boolean;
  disabled?: boolean;
  'aria-label'?: string;
  onClick?: (e: React.MouseEvent<HTMLButtonElement>) => void;
  style?: React.CSSProperties;
}
/** Icon-only button for app bars, list rows and toolbars. */
export function IconButton(props: IconButtonProps): JSX.Element;
