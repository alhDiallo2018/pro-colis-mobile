import React from 'react';
export interface ListRowProps {
  /** Material Symbols glyph for the leading tile */
  icon?: string;
  iconTone?: 'neutral' | 'primary' | 'green' | 'amber';
  /** Custom leading node (e.g. an Avatar), overrides icon */
  leading?: React.ReactNode;
  title: React.ReactNode;
  subtitle?: React.ReactNode;
  /** Trailing node (badge, amount, switch…) */
  trailing?: React.ReactNode;
  /** Show a chevron affordance @default false */
  chevron?: boolean;
  onClick?: (e: React.MouseEvent) => void;
  style?: React.CSSProperties;
}
/** Settings/notification/parcel list row. */
export function ListRow(props: ListRowProps): JSX.Element;
