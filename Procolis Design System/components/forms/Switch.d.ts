import React from 'react';
export interface SwitchProps {
  checked?: boolean;
  onChange?: (next: boolean) => void;
  label?: string;
  description?: string;
  disabled?: boolean;
  id?: string;
  style?: React.CSSProperties;
}
/** On/off toggle for parcel options (assurance, urgence) and driver availability. */
export function Switch(props: SwitchProps): JSX.Element;
