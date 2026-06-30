import React from 'react';
export interface FabProps {
  /** Material Symbols glyph @default 'add' */
  icon?: string;
  /** When set, renders an extended pill FAB with this label */
  label?: string;
  onClick?: (e: React.MouseEvent) => void;
  tone?: 'primary' | 'amber';
  style?: React.CSSProperties;
}
/** Floating action button — primary screen action ("Nouveau colis"). */
export function Fab(props: FabProps): JSX.Element;
