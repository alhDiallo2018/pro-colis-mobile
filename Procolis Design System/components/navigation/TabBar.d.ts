import React from 'react';
export interface TabBarItem {
  key: string;
  label: string;
  /** Material Symbols glyph */
  icon: string;
  /** Optional notification count */
  badge?: number;
}
export interface TabBarProps {
  items: TabBarItem[];
  value?: string;
  onChange?: (key: string) => void;
  style?: React.CSSProperties;
}
/** Bottom navigation bar for the mobile app. */
export function TabBar(props: TabBarProps): JSX.Element;
