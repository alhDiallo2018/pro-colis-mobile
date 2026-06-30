import React from 'react';
export interface CheckboxProps {
  checked?: boolean;
  onChange?: (next: boolean) => void;
  label?: string;
  disabled?: boolean;
  id?: string;
  style?: React.CSSProperties;
}
/** Checkbox for terms acceptance and multi-select filters. */
export function Checkbox(props: CheckboxProps): JSX.Element;
