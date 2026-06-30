import React from 'react';
export interface CardProps {
  children?: React.ReactNode;
  /** @default 'md' */
  padding?: 'none' | 'sm' | 'md' | 'lg';
  /** Lift on hover + pointer cursor @default false */
  interactive?: boolean;
  /** @default 'sm' */
  elevation?: 'none' | 'xs' | 'sm' | 'md';
  /** Optional left accent edge color (e.g. a status dot color) */
  accent?: string;
  onClick?: (e: React.MouseEvent) => void;
  style?: React.CSSProperties;
}
/** Generic white surface container. */
export function Card(props: CardProps): JSX.Element;
