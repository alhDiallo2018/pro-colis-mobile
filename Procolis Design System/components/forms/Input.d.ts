import React from 'react';
export interface InputProps {
  label?: string;
  value?: string;
  onChange?: (e: React.ChangeEvent<HTMLInputElement>) => void;
  placeholder?: string;
  type?: string;
  /** Material Symbols leading glyph */
  icon?: string;
  /** Trailing suffix text, e.g. "kg" or "FCFA" */
  suffix?: string;
  /** Error message (also turns the field red) */
  error?: string;
  /** Helper text under the field */
  help?: string;
  disabled?: boolean;
  /** Monospace input — for tracking numbers, prices, PIN @default false */
  mono?: boolean;
  id?: string;
  style?: React.CSSProperties;
}
/** Single-line text field. */
export function Input(props: InputProps): JSX.Element;
