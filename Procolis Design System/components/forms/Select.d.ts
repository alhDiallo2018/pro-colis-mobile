import React from 'react';
export interface SelectOption { value: string; label: string; }
export interface SelectProps {
  label?: string;
  value?: string;
  onChange?: (e: React.ChangeEvent<HTMLSelectElement>) => void;
  /** Array of strings or {value,label} objects */
  options?: (string | SelectOption)[];
  placeholder?: string;
  icon?: string;
  error?: string;
  disabled?: boolean;
  id?: string;
  style?: React.CSSProperties;
}
/** Dropdown select styled to match Procolis inputs (city, parcel type…). */
export function Select(props: SelectProps): JSX.Element;
