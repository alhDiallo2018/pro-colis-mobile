import React from 'react';
export interface EmptyStateProps {
  /** Material Symbols glyph @default 'inbox' */
  icon?: string;
  title?: React.ReactNode;
  message?: React.ReactNode;
  /** Next-action node (a Button) — empty states should always offer one */
  action?: React.ReactNode;
  tone?: 'neutral' | 'primary' | 'amber';
  style?: React.CSSProperties;
}
/** Empty / error / no-results placeholder with a call to action. */
export function EmptyState(props: EmptyStateProps): JSX.Element;
