import React from 'react';
export interface SegmentOption { value: string; label: string; icon?: string; }
export interface SegmentedControlProps {
  options: (string | SegmentOption)[];
  value?: string;
  onChange?: (value: string) => void;
  size?: 'sm' | 'md';
  block?: boolean;
  style?: React.CSSProperties;
}
/** Inline segmented toggle for filters and mode switches. */
export function SegmentedControl(props: SegmentedControlProps): JSX.Element;
