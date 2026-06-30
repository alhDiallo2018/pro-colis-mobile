import React from 'react';
import type { ParcelStatus } from './StatusBadge';
export interface Parcel {
  tracking?: string;
  from?: string;
  to?: string;
  status?: ParcelStatus;
  /** Pre-formatted price string, e.g. "12 500 FCFA" */
  price?: string;
  /** Pre-formatted weight, e.g. "8 kg" */
  weight?: string;
  type?: string;
  eta?: string;
  express?: boolean;
}
/**
 * Props for the signature parcel card.
 */
export interface ParcelCardProps {
  parcel: Parcel;
  onClick?: (e: React.MouseEvent) => void;
  /** Optional footer slot for actions (e.g. a Button or offer count) */
  footer?: React.ReactNode;
  style?: React.CSSProperties;
}
/**
 * Signature card showing one parcel: route, status, tracking, price.
 */
export function ParcelCard(props: ParcelCardProps): JSX.Element;
