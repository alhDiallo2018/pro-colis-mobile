import React from 'react';
export interface TagProps {
  children?: React.ReactNode;
  tone?: 'neutral' | 'primary' | 'amber' | 'green';
  icon?: string;
  /** Red "» Express" urgency chip echoing the brand chevrons @default false */
  express?: boolean;
  style?: React.CSSProperties;
}
/** Outlined chip for parcel type, route options and filters. */
export function Tag(props: TagProps): JSX.Element;
