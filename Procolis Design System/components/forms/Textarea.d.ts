import React from 'react';
export interface TextareaProps {
  label?: string;
  value?: string;
  onChange?: (e: React.ChangeEvent<HTMLTextAreaElement>) => void;
  placeholder?: string;
  rows?: number;
  error?: string;
  help?: string;
  maxLength?: number;
  disabled?: boolean;
  id?: string;
  style?: React.CSSProperties;
}
/** Multi-line input with optional character counter. */
export function Textarea(props: TextareaProps): JSX.Element;
