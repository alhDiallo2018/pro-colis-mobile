import React from 'react';
export interface DialogProps {
  open?: boolean;
  title?: React.ReactNode;
  /** Material Symbols glyph in the header circle */
  icon?: string;
  iconTone?: 'primary' | 'danger' | 'green' | 'amber';
  children?: React.ReactNode;
  /** Action buttons row (usually two Buttons) */
  actions?: React.ReactNode;
  /** Called on backdrop click */
  onClose?: () => void;
  style?: React.CSSProperties;
}
/** Centered confirmation/alert modal. */
export function Dialog(props: DialogProps): JSX.Element | null;
