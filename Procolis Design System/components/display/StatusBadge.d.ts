import React from 'react';
export type ParcelStatus =
  | 'pending' | 'free' | 'confirmed' | 'pickup' | 'transit'
  | 'arrived' | 'delivering' | 'delivered' | 'cancelled';
/**
 * Props for the parcel status badge.
 */
export interface StatusBadgeProps {
  /** Lifecycle state @default 'pending' */
  status?: ParcelStatus;
  size?: 'sm' | 'md';
  /** Show the status icon (true) or a colored dot (false) @default true */
  showIcon?: boolean;
  /** Override the default French label */
  label?: string;
  style?: React.CSSProperties;
}
/**
 * Pill badge for a parcel's lifecycle status — the canonical way to show colis state.
 */
export function StatusBadge(props: StatusBadgeProps): JSX.Element;
export const PARCEL_STATUS: Record<ParcelStatus, { label: string; icon: string; key: string }>;
