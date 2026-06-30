import React from 'react';
export interface AvatarProps {
  name?: string;
  src?: string;
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl';
  /** Availability dot */
  status?: 'online' | 'busy' | 'offline';
  /** Rounded-square instead of circle @default false */
  square?: boolean;
  style?: React.CSSProperties;
}
/** User/driver avatar with initials fallback and availability dot. */
export function Avatar(props: AvatarProps): JSX.Element;
