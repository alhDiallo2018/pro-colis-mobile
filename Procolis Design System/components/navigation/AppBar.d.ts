import React from 'react';
export interface AppBarProps {
  title: React.ReactNode;
  subtitle?: React.ReactNode;
  /** Custom leading node (ignored when onBack is set) */
  leading?: React.ReactNode;
  /** Trailing action nodes (IconButtons) */
  actions?: React.ReactNode;
  /** 'brand' paints the gradient hero variant @default 'default' */
  variant?: 'default' | 'brand';
  /** Show a back arrow and handle its press */
  onBack?: () => void;
  style?: React.CSSProperties;
}
/** Mobile top app bar with default and brand-gradient variants. */
export function AppBar(props: AppBarProps): JSX.Element;
