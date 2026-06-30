import React from 'react';
export interface ToastProps {
  tone?: 'success' | 'error' | 'info' | 'warning';
  title?: React.ReactNode;
  message?: React.ReactNode;
  onClose?: () => void;
  style?: React.CSSProperties;
}
/** Snackbar/toast for action feedback. */
export function Toast(props: ToastProps): JSX.Element;
