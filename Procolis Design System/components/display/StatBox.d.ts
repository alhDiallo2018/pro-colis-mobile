import React from 'react';
export interface StatBoxProps {
  value: React.ReactNode;
  label: string;
  /** Material Symbols glyph */
  icon?: string;
  tone?: 'neutral' | 'primary' | 'green' | 'amber' | 'red';
  /** Percentage delta; positive green, negative red */
  delta?: number;
  style?: React.CSSProperties;
}
/** KPI tile for garage/admin dashboards. */
export function StatBox(props: StatBoxProps): JSX.Element;
