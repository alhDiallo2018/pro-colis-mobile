import React from 'react';

/**
 * Props for the primary action button.
 */
export interface ButtonProps {
  children?: React.ReactNode;
  /** Visual style. @default 'primary' */
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger' | 'amber';
  /** @default 'md' */
  size?: 'sm' | 'md' | 'lg';
  /** Material Symbols glyph name, shown before the label */
  icon?: string;
  /** Material Symbols glyph name, shown after the label */
  iconTrailing?: string;
  /** Full-width button @default false */
  block?: boolean;
  /** Shows a spinner and disables the button @default false */
  loading?: boolean;
  disabled?: boolean;
  type?: 'button' | 'submit' | 'reset';
  onClick?: (e: React.MouseEvent<HTMLButtonElement>) => void;
  style?: React.CSSProperties;
}

/**
 * Primary action button for Procolis. Imperative French labels.
 */
export function Button(props: ButtonProps): JSX.Element;
