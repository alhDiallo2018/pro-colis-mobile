import React from 'react';
export interface StepperStep {
  label: string;
  time?: string;
  status: 'done' | 'current' | 'todo';
  /** Material Symbols glyph override */
  icon?: string;
  note?: string;
}
export interface StepperProps {
  steps: StepperStep[];
  style?: React.CSSProperties;
}
/** Vertical parcel-tracking timeline (suivi). */
export function Stepper(props: StepperProps): JSX.Element;
