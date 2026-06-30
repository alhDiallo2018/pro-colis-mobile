import React from 'react';
export interface TabItem { value: string; label: string; count?: number; }
export interface TabsProps {
  items: (string | TabItem)[];
  value?: string;
  onChange?: (value: string) => void;
  style?: React.CSSProperties;
}
/** Underline tabs for in-page sections, with optional counts. */
export function Tabs(props: TabsProps): JSX.Element;
