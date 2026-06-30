import React from 'react';
export interface BadgeProps {
  children?: React.ReactNode;
  tone?: 'neutral' | 'primary' | 'green' | 'amber' | 'red';
  variant?: 'soft' | 'solid';
  icon?: string;
  style?: React.CSSProperties;
}
/** Small count/label badge. For parcel lifecycle states use StatusBadge instead. */
export function Badge(props: BadgeProps): JSX.Element;
