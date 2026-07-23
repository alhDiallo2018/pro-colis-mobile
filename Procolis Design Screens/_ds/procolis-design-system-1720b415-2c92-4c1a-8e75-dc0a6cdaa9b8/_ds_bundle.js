/* @ds-bundle: {"format":3,"namespace":"ProcolisDesignSystem_1720b4","components":[{"name":"Avatar","sourcePath":"components/display/Avatar.jsx"},{"name":"Badge","sourcePath":"components/display/Badge.jsx"},{"name":"Card","sourcePath":"components/display/Card.jsx"},{"name":"ListRow","sourcePath":"components/display/ListRow.jsx"},{"name":"ParcelCard","sourcePath":"components/display/ParcelCard.jsx"},{"name":"StatBox","sourcePath":"components/display/StatBox.jsx"},{"name":"PARCEL_STATUS","sourcePath":"components/display/StatusBadge.jsx"},{"name":"StatusBadge","sourcePath":"components/display/StatusBadge.jsx"},{"name":"Stepper","sourcePath":"components/display/Stepper.jsx"},{"name":"Tag","sourcePath":"components/display/Tag.jsx"},{"name":"Dialog","sourcePath":"components/feedback/Dialog.jsx"},{"name":"EmptyState","sourcePath":"components/feedback/EmptyState.jsx"},{"name":"Toast","sourcePath":"components/feedback/Toast.jsx"},{"name":"Button","sourcePath":"components/forms/Button.jsx"},{"name":"Checkbox","sourcePath":"components/forms/Checkbox.jsx"},{"name":"IconButton","sourcePath":"components/forms/IconButton.jsx"},{"name":"Input","sourcePath":"components/forms/Input.jsx"},{"name":"SegmentedControl","sourcePath":"components/forms/SegmentedControl.jsx"},{"name":"Select","sourcePath":"components/forms/Select.jsx"},{"name":"Switch","sourcePath":"components/forms/Switch.jsx"},{"name":"Textarea","sourcePath":"components/forms/Textarea.jsx"},{"name":"AppBar","sourcePath":"components/navigation/AppBar.jsx"},{"name":"Fab","sourcePath":"components/navigation/Fab.jsx"},{"name":"Icon","sourcePath":"components/navigation/Icon.jsx"},{"name":"TabBar","sourcePath":"components/navigation/TabBar.jsx"},{"name":"Tabs","sourcePath":"components/navigation/Tabs.jsx"}],"sourceHashes":{"components/display/Avatar.jsx":"4b978eb1181d","components/display/Badge.jsx":"6ff3dcd2d84b","components/display/Card.jsx":"c60b7aae843b","components/display/ListRow.jsx":"3cbbdfe72a8e","components/display/ParcelCard.jsx":"1739aca52afc","components/display/StatBox.jsx":"66b17fa2204e","components/display/StatusBadge.jsx":"76f932334f86","components/display/Stepper.jsx":"b14a5f0848b8","components/display/Tag.jsx":"0d3741e0d624","components/feedback/Dialog.jsx":"d786f8c8074d","components/feedback/EmptyState.jsx":"ad61edb4b533","components/feedback/Toast.jsx":"efedbe99eb74","components/forms/Button.jsx":"e7c42e6aedbe","components/forms/Checkbox.jsx":"7c8ad06148c5","components/forms/IconButton.jsx":"56fc9a22017e","components/forms/Input.jsx":"b87734ee1f42","components/forms/SegmentedControl.jsx":"9d5f65d5744c","components/forms/Select.jsx":"36333122dbd0","components/forms/Switch.jsx":"a7705a67bc0c","components/forms/Textarea.jsx":"b97bd1cf27de","components/navigation/AppBar.jsx":"bbb793e8e062","components/navigation/Fab.jsx":"1da6d5705746","components/navigation/Icon.jsx":"3b83969dbd5c","components/navigation/TabBar.jsx":"acbfd83e8b41","components/navigation/Tabs.jsx":"e98885ded2b3","ui_kits/admin/mock.js":"2cf3e499a9a8","ui_kits/mobile-app/mock.js":"531a7493e5b2","ui_kits/mobile-app/screens-detail.jsx":"06fd3cd7b18b","ui_kits/mobile-app/screens-main.jsx":"6c62eb421440"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.ProcolisDesignSystem_1720b4 = window.ProcolisDesignSystem_1720b4 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/display/Avatar.jsx
try { (() => {
/** User avatar with initials fallback, optional online/availability dot. */
function Avatar({
  name = '',
  src,
  size = 'md',
  status,
  square = false,
  style
}) {
  const sizes = {
    xs: 28,
    sm: 36,
    md: 44,
    lg: 56,
    xl: 72
  };
  const d = sizes[size] || sizes.md;
  const initials = name.split(' ').filter(Boolean).slice(0, 2).map(p => p[0]).join('').toUpperCase();
  const hue = [...name].reduce((a, c) => a + c.charCodeAt(0), 0) % 4;
  const palettes = [['var(--teal-100)', 'var(--teal-700)'], ['var(--green-100)', 'var(--green-800)'], ['var(--amber-100)', 'var(--amber-700)'], ['var(--color-info-soft)', 'var(--deep-700)']][hue];
  const statusColors = {
    online: 'var(--green-500)',
    busy: 'var(--amber-400)',
    offline: 'var(--slate-300)'
  };
  return /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'relative',
      display: 'inline-flex',
      flex: 'none',
      width: d,
      height: d,
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: d,
      height: d,
      borderRadius: square ? 'var(--radius-md)' : '50%',
      overflow: 'hidden',
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      background: src ? 'var(--surface-sunken)' : palettes[0],
      color: palettes[1],
      fontFamily: 'var(--font-display)',
      fontWeight: 700,
      fontSize: d * 0.38
    }
  }, src ? /*#__PURE__*/React.createElement("img", {
    src: src,
    alt: name,
    style: {
      width: '100%',
      height: '100%',
      objectFit: 'cover'
    }
  }) : initials), status && /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      right: -1,
      bottom: -1,
      width: d * 0.28,
      height: d * 0.28,
      minWidth: 9,
      minHeight: 9,
      borderRadius: '50%',
      background: statusColors[status] || 'var(--slate-300)',
      border: '2px solid var(--surface-card)'
    }
  }));
}
Object.assign(__ds_scope, { Avatar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/Avatar.jsx", error: String((e && e.message) || e) }); }

// components/display/Badge.jsx
try { (() => {
/** Small inline badge for counts, generic labels, semantic states. */
function Badge({
  children,
  tone = 'neutral',
  variant = 'soft',
  icon,
  style
}) {
  const map = {
    neutral: {
      soft: ['var(--surface-sunken)', 'var(--text-body)'],
      solid: ['var(--slate-700)', '#fff']
    },
    primary: {
      soft: ['var(--color-primary-soft)', 'var(--color-primary)'],
      solid: ['var(--color-primary)', '#fff']
    },
    green: {
      soft: ['var(--green-50)', 'var(--green-700)'],
      solid: ['var(--green-600)', '#fff']
    },
    amber: {
      soft: ['var(--amber-50)', 'var(--amber-600)'],
      solid: ['var(--amber-400)', '#3a2600']
    },
    red: {
      soft: ['var(--red-50)', 'var(--red-500)'],
      solid: ['var(--red-400)', '#fff']
    }
  };
  const [bg, fg] = (map[tone] || map.neutral)[variant] || (map[tone] || map.neutral).soft;
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 4,
      height: 22,
      padding: '0 8px',
      background: bg,
      color: fg,
      borderRadius: 'var(--radius-pill)',
      fontFamily: 'var(--font-display)',
      fontWeight: 700,
      fontSize: 11.5,
      letterSpacing: '0.01em',
      whiteSpace: 'nowrap',
      ...style
    }
  }, icon && /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 14
    }
  }, icon), children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/Badge.jsx", error: String((e && e.message) || e) }); }

// components/display/Card.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/** Surface container. Optional padding, interactive hover, accent edge. */
function Card({
  children,
  padding = 'md',
  interactive = false,
  elevation = 'sm',
  accent,
  onClick,
  style,
  ...rest
}) {
  const pads = {
    none: 0,
    sm: 'var(--space-3)',
    md: 'var(--space-4)',
    lg: 'var(--space-5)'
  };
  const shadows = {
    none: 'none',
    xs: 'var(--shadow-xs)',
    sm: 'var(--shadow-sm)',
    md: 'var(--shadow-md)'
  };
  const [hover, setHover] = React.useState(false);
  return /*#__PURE__*/React.createElement("div", _extends({
    onClick: onClick,
    onMouseEnter: () => interactive && setHover(true),
    onMouseLeave: () => interactive && setHover(false),
    style: {
      background: 'var(--surface-card)',
      border: '1px solid var(--border-subtle)',
      borderLeft: accent ? `3px solid ${accent}` : '1px solid var(--border-subtle)',
      borderRadius: 'var(--radius-md)',
      padding: pads[padding] ?? pads.md,
      boxShadow: hover ? 'var(--shadow-md)' : shadows[elevation] ?? shadows.sm,
      transform: hover ? 'translateY(-2px)' : 'none',
      cursor: interactive ? 'pointer' : 'default',
      transition: 'box-shadow var(--dur-base) var(--ease-standard), transform var(--dur-base) var(--ease-standard)',
      ...style
    }
  }, rest), children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/Card.jsx", error: String((e && e.message) || e) }); }

// components/display/ListRow.jsx
try { (() => {
/** Tappable list row: leading icon/avatar, title + subtitle, trailing meta. */
function ListRow({
  icon,
  iconTone = 'neutral',
  leading,
  title,
  subtitle,
  trailing,
  chevron = false,
  onClick,
  style
}) {
  const tones = {
    neutral: ['var(--surface-sunken)', 'var(--text-muted)'],
    primary: ['var(--color-primary-soft)', 'var(--color-primary)'],
    green: ['var(--green-50)', 'var(--green-700)'],
    amber: ['var(--amber-50)', 'var(--amber-600)']
  };
  const [bg, fg] = tones[iconTone] || tones.neutral;
  const [hover, setHover] = React.useState(false);
  const clickable = !!onClick;
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      padding: '12px 14px',
      minHeight: 60,
      background: hover && clickable ? 'var(--surface-sunken)' : 'transparent',
      borderRadius: 'var(--radius-md)',
      cursor: clickable ? 'pointer' : 'default',
      transition: 'background var(--dur-fast)',
      ...style
    }
  }, leading || icon && /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      width: 40,
      height: 40,
      flex: 'none',
      borderRadius: 'var(--radius-sm)',
      background: bg,
      color: fg
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 22,
      fontVariationSettings: "'FILL' 1"
    }
  }, icon)), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontWeight: 600,
      fontSize: 15,
      color: 'var(--text-strong)',
      overflow: 'hidden',
      textOverflow: 'ellipsis',
      whiteSpace: 'nowrap'
    }
  }, title), subtitle && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--text-muted)',
      marginTop: 2,
      overflow: 'hidden',
      textOverflow: 'ellipsis',
      whiteSpace: 'nowrap'
    }
  }, subtitle)), trailing && /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 'none',
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, trailing), chevron && /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 22,
      color: 'var(--text-faint)',
      flex: 'none'
    }
  }, "chevron_right"));
}
Object.assign(__ds_scope, { ListRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/ListRow.jsx", error: String((e && e.message) || e) }); }

// components/display/StatBox.jsx
try { (() => {
/** Compact metric tile for dashboards (colis en cours, chauffeurs dispo…). */
function StatBox({
  value,
  label,
  icon,
  tone = 'neutral',
  delta,
  style
}) {
  const tones = {
    neutral: {
      bg: 'var(--surface-sunken)',
      fg: 'var(--text-muted)'
    },
    primary: {
      bg: 'var(--color-primary-soft)',
      fg: 'var(--color-primary)'
    },
    green: {
      bg: 'var(--green-50)',
      fg: 'var(--green-700)'
    },
    amber: {
      bg: 'var(--amber-50)',
      fg: 'var(--amber-600)'
    },
    red: {
      bg: 'var(--red-50)',
      fg: 'var(--red-500)'
    }
  };
  const t = tones[tone] || tones.neutral;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 10,
      padding: 'var(--space-4)',
      background: 'var(--surface-card)',
      border: '1px solid var(--border-subtle)',
      borderRadius: 'var(--radius-md)',
      boxShadow: 'var(--shadow-xs)',
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between'
    }
  }, icon && /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      width: 36,
      height: 36,
      borderRadius: 'var(--radius-sm)',
      background: t.bg,
      color: t.fg
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 20,
      fontVariationSettings: "'FILL' 1"
    }
  }, icon)), delta != null && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontWeight: 600,
      fontSize: 12,
      color: delta >= 0 ? 'var(--green-600)' : 'var(--red-500)'
    }
  }, delta >= 0 ? '▲' : '▼', " ", Math.abs(delta), "%")), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontWeight: 800,
      fontSize: 26,
      lineHeight: 1,
      color: 'var(--text-strong)'
    }
  }, value), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--text-muted)',
      marginTop: 5,
      fontWeight: 500
    }
  }, label)));
}
Object.assign(__ds_scope, { StatBox });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/StatBox.jsx", error: String((e && e.message) || e) }); }

// components/display/StatusBadge.jsx
try { (() => {
/** Status meta for the colis lifecycle. Keys match the spec's statuses. */
const PARCEL_STATUS = {
  pending: {
    label: 'En attente',
    icon: 'schedule',
    key: 'pending'
  },
  free: {
    label: 'Libre service',
    icon: 'sell',
    key: 'free'
  },
  confirmed: {
    label: 'Confirmé',
    icon: 'check_circle',
    key: 'confirmed'
  },
  pickup: {
    label: 'Ramassé',
    icon: 'package_2',
    key: 'pickup'
  },
  transit: {
    label: 'En transit',
    icon: 'local_shipping',
    key: 'transit'
  },
  arrived: {
    label: 'Arrivé',
    icon: 'pin_drop',
    key: 'arrived'
  },
  delivering: {
    label: 'En livraison',
    icon: 'moving',
    key: 'delivering'
  },
  delivered: {
    label: 'Livré',
    icon: 'task_alt',
    key: 'delivered'
  },
  cancelled: {
    label: 'Annulé',
    icon: 'cancel',
    key: 'cancelled'
  }
};

/** Pill badge for a parcel's lifecycle status. Colors come from --status-*. */
function StatusBadge({
  status = 'pending',
  size = 'md',
  showIcon = true,
  label,
  style
}) {
  const meta = PARCEL_STATUS[status] || PARCEL_STATUS.pending;
  const k = meta.key;
  const sizes = {
    sm: {
      h: 22,
      fs: 10.5,
      px: 8,
      ic: 13,
      dot: 6
    },
    md: {
      h: 28,
      fs: 11.5,
      px: 11,
      ic: 15,
      dot: 7
    }
  };
  const s = sizes[size] || sizes.md;
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      height: s.h,
      padding: `0 ${s.px}px`,
      background: `var(--status-${k}-bg)`,
      color: `var(--status-${k}-fg)`,
      borderRadius: 'var(--radius-pill)',
      fontFamily: 'var(--font-display)',
      fontWeight: 700,
      fontSize: s.fs,
      letterSpacing: '0.05em',
      textTransform: 'uppercase',
      whiteSpace: 'nowrap',
      ...style
    }
  }, showIcon ? /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: s.ic,
      fontVariationSettings: "'FILL' 1, 'wght' 500"
    }
  }, meta.icon) : /*#__PURE__*/React.createElement("span", {
    style: {
      width: s.dot,
      height: s.dot,
      borderRadius: '50%',
      background: `var(--status-${k}-dot)`
    }
  }), label || meta.label);
}
Object.assign(__ds_scope, { PARCEL_STATUS, StatusBadge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/StatusBadge.jsx", error: String((e && e.message) || e) }); }

// components/display/ParcelCard.jsx
try { (() => {
/**
 * The product's signature card: one colis with route, status, tracking & price.
 * parcel: { tracking, from, to, status, price, weight, type, eta, express }
 */
function ParcelCard({
  parcel = {},
  onClick,
  footer,
  style
}) {
  const {
    tracking,
    from = '—',
    to = '—',
    status = 'pending',
    price,
    weight,
    type,
    eta,
    express
  } = parcel;
  const [hover, setHover] = React.useState(false);
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      background: 'var(--surface-card)',
      border: '1px solid var(--border-subtle)',
      borderRadius: 'var(--radius-lg)',
      padding: 'var(--space-4)',
      boxShadow: hover && onClick ? 'var(--shadow-md)' : 'var(--shadow-sm)',
      transform: hover && onClick ? 'translateY(-2px)' : 'none',
      cursor: onClick ? 'pointer' : 'default',
      transition: 'box-shadow var(--dur-base), transform var(--dur-base)',
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 18,
      color: 'var(--text-faint)'
    }
  }, "qr_code_2"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontWeight: 600,
      fontSize: 13,
      color: 'var(--text-body)',
      letterSpacing: '0.02em'
    }
  }, tracking || '—'), express && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-display)',
      fontWeight: 800,
      fontSize: 14,
      color: 'var(--red-400)',
      letterSpacing: '-1px'
    }
  }, "\xBB")), /*#__PURE__*/React.createElement(__ds_scope.StatusBadge, {
    status: status,
    size: "sm"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      margin: '14px 0 12px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      fontWeight: 700,
      letterSpacing: '0.07em',
      textTransform: 'uppercase',
      color: 'var(--text-faint)',
      fontFamily: 'var(--font-display)'
    }
  }, "D\xE9part"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontWeight: 700,
      fontSize: 16,
      color: 'var(--text-strong)',
      overflow: 'hidden',
      textOverflow: 'ellipsis',
      whiteSpace: 'nowrap'
    }
  }, from)), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      flexDirection: 'column',
      alignItems: 'center',
      color: 'var(--teal-400)',
      flex: 'none'
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 22
    }
  }, "local_shipping")), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0,
      textAlign: 'right'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      fontWeight: 700,
      letterSpacing: '0.07em',
      textTransform: 'uppercase',
      color: 'var(--text-faint)',
      fontFamily: 'var(--font-display)'
    }
  }, "Arriv\xE9e"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontWeight: 700,
      fontSize: 16,
      color: 'var(--text-strong)',
      overflow: 'hidden',
      textOverflow: 'ellipsis',
      whiteSpace: 'nowrap'
    }
  }, to))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 14,
      paddingTop: 12,
      borderTop: '1px solid var(--border-subtle)'
    }
  }, weight && /*#__PURE__*/React.createElement(Meta, {
    icon: "weight",
    text: weight
  }), type && /*#__PURE__*/React.createElement(Meta, {
    icon: "category",
    text: type
  }), eta && /*#__PURE__*/React.createElement(Meta, {
    icon: "schedule",
    text: eta
  }), price != null && /*#__PURE__*/React.createElement("span", {
    style: {
      marginLeft: 'auto',
      fontFamily: 'var(--font-mono)',
      fontWeight: 700,
      fontSize: 16,
      color: 'var(--teal-600)'
    }
  }, price)), footer && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 14
    }
  }, footer));
}
function Meta({
  icon,
  text
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 4,
      fontSize: 12.5,
      color: 'var(--text-muted)',
      fontWeight: 500
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 16,
      color: 'var(--text-faint)'
    }
  }, icon), text);
}
Object.assign(__ds_scope, { ParcelCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/ParcelCard.jsx", error: String((e && e.message) || e) }); }

// components/display/Stepper.jsx
try { (() => {
/**
 * Vertical timeline of the parcel lifecycle / tracking events.
 * steps: [{ label, time, status: 'done'|'current'|'todo', icon, note }]
 */
function Stepper({
  steps = [],
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      ...style
    }
  }, steps.map((st, i) => {
    const last = i === steps.length - 1;
    const done = st.status === 'done';
    const current = st.status === 'current';
    const dotBg = done ? 'var(--green-500)' : current ? 'var(--color-primary)' : 'var(--surface-card)';
    const dotBorder = done ? 'var(--green-500)' : current ? 'var(--color-primary)' : 'var(--border-default)';
    const lineColor = done ? 'var(--green-300)' : 'var(--border-default)';
    return /*#__PURE__*/React.createElement("div", {
      key: i,
      style: {
        display: 'flex',
        gap: 14,
        minHeight: last ? 'auto' : 56
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        flex: 'none'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        width: 30,
        height: 30,
        borderRadius: '50%',
        background: dotBg,
        border: `2px solid ${dotBorder}`,
        boxShadow: current ? 'var(--ring-focus)' : 'none',
        flex: 'none'
      }
    }, (done || current) && /*#__PURE__*/React.createElement("span", {
      className: "material-symbols-rounded",
      style: {
        fontSize: 17,
        color: '#fff',
        fontVariationSettings: "'wght' 600"
      }
    }, st.icon || (done ? 'check' : 'local_shipping'))), !last && /*#__PURE__*/React.createElement("span", {
      style: {
        width: 2,
        flex: 1,
        minHeight: 22,
        background: lineColor,
        marginTop: 2,
        marginBottom: 2
      }
    })), /*#__PURE__*/React.createElement("div", {
      style: {
        paddingBottom: last ? 0 : 16,
        paddingTop: 4
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        alignItems: 'baseline',
        gap: 10,
        flexWrap: 'wrap'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: current ? 700 : 600,
        fontSize: 14.5,
        color: current || done ? 'var(--text-strong)' : 'var(--text-muted)'
      }
    }, st.label), st.time && /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 11.5,
        color: 'var(--text-faint)'
      }
    }, st.time)), st.note && /*#__PURE__*/React.createElement("div", {
      style: {
        fontSize: 13,
        color: 'var(--text-muted)',
        marginTop: 3
      }
    }, st.note)));
  }));
}
Object.assign(__ds_scope, { Stepper });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/Stepper.jsx", error: String((e && e.message) || e) }); }

// components/display/Tag.jsx
try { (() => {
/** Outlined tag/chip — parcel type, route options, filters. The "express"
 *  tone echoes the brand red chevrons (»). */
function Tag({
  children,
  tone = 'neutral',
  icon,
  express = false,
  style
}) {
  if (express) {
    return /*#__PURE__*/React.createElement("span", {
      style: {
        display: 'inline-flex',
        alignItems: 'center',
        gap: 4,
        height: 24,
        padding: '0 9px',
        background: 'var(--red-50)',
        color: 'var(--red-500)',
        border: '1px solid var(--red-100)',
        borderRadius: 'var(--radius-sm)',
        fontFamily: 'var(--font-display)',
        fontWeight: 700,
        fontSize: 11.5,
        letterSpacing: '0.04em',
        textTransform: 'uppercase',
        ...style
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        fontWeight: 800,
        letterSpacing: '-1px'
      }
    }, "\xBB"), children || 'Express');
  }
  const tones = {
    neutral: 'var(--text-body)',
    primary: 'var(--color-primary)',
    amber: 'var(--amber-600)',
    green: 'var(--green-700)'
  };
  const fg = tones[tone] || tones.neutral;
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 5,
      height: 26,
      padding: '0 10px',
      background: 'var(--surface-card)',
      color: fg,
      border: '1px solid var(--border-default)',
      borderRadius: 'var(--radius-sm)',
      fontFamily: 'var(--font-body)',
      fontWeight: 600,
      fontSize: 12.5,
      ...style
    }
  }, icon && /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 15
    }
  }, icon), children);
}
Object.assign(__ds_scope, { Tag });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/display/Tag.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Dialog.jsx
try { (() => {
/** Centered modal dialog / confirmation (cancel parcel, accept offer). */
function Dialog({
  open = true,
  title,
  icon,
  iconTone = 'primary',
  children,
  actions,
  onClose,
  style
}) {
  if (!open) return null;
  const tones = {
    primary: ['var(--color-primary-soft)', 'var(--color-primary)'],
    danger: ['var(--color-danger-soft)', 'var(--color-danger)'],
    green: ['var(--green-50)', 'var(--green-600)'],
    amber: ['var(--amber-50)', 'var(--amber-600)']
  };
  const [bg, fg] = tones[iconTone] || tones.primary;
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClose,
    style: {
      position: 'fixed',
      inset: 0,
      zIndex: 1000,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: 20,
      background: 'rgba(10,58,67,0.45)',
      backdropFilter: 'blur(2px)',
      animation: 'pc-fade var(--dur-base) var(--ease-out)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    onClick: e => e.stopPropagation(),
    role: "dialog",
    "aria-modal": "true",
    style: {
      width: '100%',
      maxWidth: 380,
      background: 'var(--surface-card)',
      borderRadius: 'var(--radius-lg)',
      boxShadow: 'var(--shadow-lg)',
      padding: 'var(--space-6)',
      textAlign: 'center',
      animation: 'pc-pop var(--dur-base) var(--ease-out)',
      ...style
    }
  }, icon && /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      width: 56,
      height: 56,
      borderRadius: '50%',
      background: bg,
      color: fg,
      marginBottom: 14
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 30,
      fontVariationSettings: "'FILL' 1"
    }
  }, icon)), title && /*#__PURE__*/React.createElement("h3", {
    style: {
      margin: '0 0 8px',
      fontFamily: 'var(--font-display)',
      fontWeight: 700,
      fontSize: 19,
      color: 'var(--text-strong)'
    }
  }, title), children && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14.5,
      color: 'var(--text-muted)',
      lineHeight: 1.5
    }
  }, children), actions && /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      marginTop: 22
    }
  }, actions)), /*#__PURE__*/React.createElement("style", null, `@keyframes pc-fade{from{opacity:0}to{opacity:1}}@keyframes pc-pop{from{opacity:0;transform:translateY(8px) scale(0.97)}to{opacity:1;transform:none}}`));
}
Object.assign(__ds_scope, { Dialog });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Dialog.jsx", error: String((e && e.message) || e) }); }

// components/feedback/EmptyState.jsx
try { (() => {
/** Empty / error / no-results state. Always offer a next action. */
function EmptyState({
  icon = 'inbox',
  title,
  message,
  action,
  tone = 'neutral',
  style
}) {
  const tones = {
    neutral: ['var(--surface-sunken)', 'var(--text-faint)'],
    primary: ['var(--color-primary-soft)', 'var(--color-primary)'],
    amber: ['var(--amber-50)', 'var(--amber-500)']
  };
  const [bg, fg] = tones[tone] || tones.neutral;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      textAlign: 'center',
      padding: '40px 24px',
      gap: 6,
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      width: 72,
      height: 72,
      borderRadius: '50%',
      background: bg,
      color: fg,
      marginBottom: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 38
    }
  }, icon)), title && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontWeight: 700,
      fontSize: 17,
      color: 'var(--text-strong)'
    }
  }, title), message && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      color: 'var(--text-muted)',
      maxWidth: 280,
      lineHeight: 1.5
    }
  }, message), action && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 14
    }
  }, action));
}
Object.assign(__ds_scope, { EmptyState });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/EmptyState.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Toast.jsx
try { (() => {
/** Toast / snackbar. tone drives the accent + icon. */
function Toast({
  tone = 'success',
  title,
  message,
  onClose,
  style
}) {
  const tones = {
    success: {
      c: 'var(--green-600)',
      bg: 'var(--green-50)',
      icon: 'check_circle'
    },
    error: {
      c: 'var(--red-400)',
      bg: 'var(--red-50)',
      icon: 'error'
    },
    info: {
      c: 'var(--deep-500)',
      bg: 'var(--color-info-soft)',
      icon: 'info'
    },
    warning: {
      c: 'var(--amber-500)',
      bg: 'var(--amber-50)',
      icon: 'warning'
    }
  };
  const t = tones[tone] || tones.success;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'flex-start',
      gap: 12,
      padding: '12px 14px',
      background: 'var(--surface-card)',
      border: '1px solid var(--border-subtle)',
      borderLeft: `3px solid ${t.c}`,
      borderRadius: 'var(--radius-md)',
      boxShadow: 'var(--shadow-md)',
      maxWidth: 420,
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      width: 30,
      height: 30,
      flex: 'none',
      borderRadius: 'var(--radius-sm)',
      background: t.bg,
      color: t.c
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 20,
      fontVariationSettings: "'FILL' 1"
    }
  }, t.icon)), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0,
      paddingTop: 1
    }
  }, title && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontWeight: 700,
      fontSize: 14,
      color: 'var(--text-strong)'
    }
  }, title), message && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: 'var(--text-muted)',
      marginTop: title ? 2 : 0
    }
  }, message)), onClose && /*#__PURE__*/React.createElement("button", {
    onClick: onClose,
    "aria-label": "Fermer",
    style: {
      display: 'inline-flex',
      border: 'none',
      background: 'transparent',
      color: 'var(--text-faint)',
      cursor: 'pointer',
      padding: 2,
      flex: 'none'
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 18
    }
  }, "close")));
}
Object.assign(__ds_scope, { Toast });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Toast.jsx", error: String((e && e.message) || e) }); }

// components/forms/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Procolis primary button. French imperative labels ("Créer le colis").
 */
function Button({
  children,
  variant = 'primary',
  // primary | secondary | ghost | danger | amber
  size = 'md',
  // sm | md | lg
  icon,
  // material-symbols name, leading
  iconTrailing,
  // material-symbols name, trailing
  block = false,
  loading = false,
  disabled = false,
  type = 'button',
  onClick,
  style,
  ...rest
}) {
  const sizes = {
    sm: {
      h: 36,
      px: 14,
      fs: 13,
      ic: 18,
      gap: 6
    },
    md: {
      h: 46,
      px: 18,
      fs: 15,
      ic: 20,
      gap: 8
    },
    lg: {
      h: 54,
      px: 22,
      fs: 16,
      ic: 22,
      gap: 8
    }
  };
  const s = sizes[size] || sizes.md;
  const variants = {
    primary: {
      bg: 'var(--color-primary)',
      fg: '#fff',
      bd: 'transparent',
      sh: 'var(--shadow-brand)',
      hb: 'var(--color-primary-hover)'
    },
    amber: {
      bg: 'var(--color-accent)',
      fg: '#3a2600',
      bd: 'transparent',
      sh: 'var(--shadow-amber)',
      hb: 'var(--color-accent-hover)'
    },
    secondary: {
      bg: 'var(--surface-card)',
      fg: 'var(--text-strong)',
      bd: 'var(--border-default)',
      sh: 'var(--shadow-xs)',
      hb: 'var(--surface-sunken)'
    },
    ghost: {
      bg: 'transparent',
      fg: 'var(--color-primary)',
      bd: 'transparent',
      sh: 'none',
      hb: 'var(--color-primary-soft)'
    },
    danger: {
      bg: 'var(--color-danger)',
      fg: '#fff',
      bd: 'transparent',
      sh: 'none',
      hb: 'var(--red-500)'
    }
  };
  const v = variants[variant] || variants.primary;
  const [hover, setHover] = React.useState(false);
  const [press, setPress] = React.useState(false);
  const isDisabled = disabled || loading;
  return /*#__PURE__*/React.createElement("button", _extends({
    type: type,
    onClick: onClick,
    disabled: isDisabled,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => {
      setHover(false);
      setPress(false);
    },
    onMouseDown: () => setPress(true),
    onMouseUp: () => setPress(false),
    style: {
      display: block ? 'flex' : 'inline-flex',
      width: block ? '100%' : 'auto',
      alignItems: 'center',
      justifyContent: 'center',
      gap: s.gap,
      height: s.h,
      padding: `0 ${s.px}px`,
      fontFamily: 'var(--font-display)',
      fontWeight: 700,
      fontSize: s.fs,
      letterSpacing: '0.01em',
      color: isDisabled ? 'var(--text-faint)' : v.fg,
      background: isDisabled ? 'var(--slate-200)' : hover ? v.hb : v.bg,
      border: `1px solid ${isDisabled ? 'transparent' : v.bd}`,
      borderRadius: 'var(--radius-md)',
      boxShadow: isDisabled ? 'none' : press ? 'none' : v.sh,
      cursor: isDisabled ? 'not-allowed' : 'pointer',
      transform: press && !isDisabled ? 'scale(0.97)' : 'scale(1)',
      transition: 'background var(--dur-fast) var(--ease-standard), transform var(--dur-fast) var(--ease-standard), box-shadow var(--dur-fast)',
      whiteSpace: 'nowrap',
      userSelect: 'none',
      ...style
    }
  }, rest), loading && /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: s.ic,
      animation: 'pc-spin 0.7s linear infinite'
    }
  }, "progress_activity"), !loading && icon && /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: s.ic
    }
  }, icon), children, !loading && iconTrailing && /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: s.ic
    }
  }, iconTrailing), /*#__PURE__*/React.createElement("style", null, `@keyframes pc-spin{to{transform:rotate(360deg)}}`));
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Button.jsx", error: String((e && e.message) || e) }); }

// components/forms/Checkbox.jsx
try { (() => {
/** Checkbox with label (terms, multi-select filters). */
function Checkbox({
  checked = false,
  onChange,
  label,
  disabled = false,
  id,
  style
}) {
  const fid = id || React.useId();
  return /*#__PURE__*/React.createElement("label", {
    htmlFor: fid,
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 10,
      cursor: disabled ? 'not-allowed' : 'pointer',
      opacity: disabled ? 0.5 : 1,
      ...style
    }
  }, /*#__PURE__*/React.createElement("button", {
    id: fid,
    role: "checkbox",
    "aria-checked": checked,
    disabled: disabled,
    onClick: () => onChange && onChange(!checked),
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      flex: 'none',
      width: 22,
      height: 22,
      padding: 0,
      background: checked ? 'var(--color-primary)' : 'var(--surface-card)',
      border: `2px solid ${checked ? 'var(--color-primary)' : 'var(--border-strong)'}`,
      borderRadius: 7,
      cursor: disabled ? 'not-allowed' : 'pointer',
      transition: 'background var(--dur-fast), border-color var(--dur-fast)'
    }
  }, checked && /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 16,
      color: '#fff',
      fontVariationSettings: "'wght' 700"
    }
  }, "check")), label && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-body)',
      fontWeight: 500,
      fontSize: 14,
      color: 'var(--text-body)'
    }
  }, label));
}
Object.assign(__ds_scope, { Checkbox });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Checkbox.jsx", error: String((e && e.message) || e) }); }

// components/forms/IconButton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/** Square/round icon-only button. */
function IconButton({
  icon,
  variant = 'ghost',
  // ghost | solid | soft | danger
  size = 'md',
  // sm | md | lg
  round = false,
  disabled = false,
  'aria-label': ariaLabel,
  onClick,
  style,
  ...rest
}) {
  const sizes = {
    sm: {
      d: 34,
      ic: 18
    },
    md: {
      d: 44,
      ic: 22
    },
    lg: {
      d: 52,
      ic: 26
    }
  };
  const s = sizes[size] || sizes.md;
  const variants = {
    ghost: {
      bg: 'transparent',
      fg: 'var(--text-muted)',
      hb: 'var(--surface-sunken)'
    },
    solid: {
      bg: 'var(--color-primary)',
      fg: '#fff',
      hb: 'var(--color-primary-hover)'
    },
    soft: {
      bg: 'var(--color-primary-soft)',
      fg: 'var(--color-primary)',
      hb: 'var(--teal-100)'
    },
    danger: {
      bg: 'var(--color-danger-soft)',
      fg: 'var(--color-danger)',
      hb: 'var(--red-100)'
    }
  };
  const v = variants[variant] || variants.ghost;
  const [hover, setHover] = React.useState(false);
  return /*#__PURE__*/React.createElement("button", _extends({
    "aria-label": ariaLabel,
    onClick: onClick,
    disabled: disabled,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      width: s.d,
      height: s.d,
      flex: 'none',
      color: disabled ? 'var(--text-faint)' : v.fg,
      background: disabled ? 'transparent' : hover ? v.hb : v.bg,
      border: 'none',
      borderRadius: round ? '50%' : 'var(--radius-sm)',
      cursor: disabled ? 'not-allowed' : 'pointer',
      transition: 'background var(--dur-fast) var(--ease-standard)',
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: s.ic
    }
  }, icon));
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/forms/Input.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/** Labeled text field with optional leading icon, suffix, error/help. */
function Input({
  label,
  value,
  onChange,
  placeholder,
  type = 'text',
  icon,
  suffix,
  error,
  help,
  disabled = false,
  mono = false,
  id,
  style,
  ...rest
}) {
  const [focus, setFocus] = React.useState(false);
  const fid = id || React.useId();
  const borderColor = error ? 'var(--color-danger)' : focus ? 'var(--border-focus)' : 'var(--border-default)';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 6,
      ...style
    }
  }, label && /*#__PURE__*/React.createElement("label", {
    htmlFor: fid,
    style: {
      fontFamily: 'var(--font-display)',
      fontWeight: 600,
      fontSize: 13,
      color: 'var(--text-body)'
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      height: 48,
      padding: '0 14px',
      background: disabled ? 'var(--surface-sunken)' : 'var(--surface-card)',
      border: `1px solid ${borderColor}`,
      borderRadius: 'var(--radius-md)',
      boxShadow: focus && !error ? 'var(--ring-focus)' : 'none',
      transition: 'border-color var(--dur-fast), box-shadow var(--dur-fast)'
    }
  }, icon && /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 20,
      color: focus ? 'var(--color-primary)' : 'var(--text-faint)'
    }
  }, icon), /*#__PURE__*/React.createElement("input", _extends({
    id: fid,
    type: type,
    value: value,
    onChange: onChange,
    placeholder: placeholder,
    disabled: disabled,
    onFocus: () => setFocus(true),
    onBlur: () => setFocus(false),
    style: {
      flex: 1,
      minWidth: 0,
      border: 'none',
      outline: 'none',
      background: 'transparent',
      fontFamily: mono ? 'var(--font-mono)' : 'var(--font-body)',
      fontWeight: mono ? 600 : 500,
      fontSize: 15,
      color: 'var(--text-strong)',
      letterSpacing: mono ? '0.02em' : 0
    }
  }, rest)), suffix && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 13,
      color: 'var(--text-muted)',
      whiteSpace: 'nowrap'
    }
  }, suffix)), (error || help) && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      color: error ? 'var(--color-danger)' : 'var(--text-muted)'
    }
  }, error || help));
}
Object.assign(__ds_scope, { Input });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Input.jsx", error: String((e && e.message) || e) }); }

// components/forms/SegmentedControl.jsx
try { (() => {
/** Segmented control — role switch, status filters, mode toggles. */
function SegmentedControl({
  options = [],
  value,
  onChange,
  size = 'md',
  block = false,
  style
}) {
  const norm = options.map(o => typeof o === 'string' ? {
    value: o,
    label: o
  } : o);
  const sizes = {
    sm: {
      h: 34,
      fs: 12.5,
      px: 12
    },
    md: {
      h: 42,
      fs: 14,
      px: 16
    }
  };
  const s = sizes[size] || sizes.md;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: block ? 'flex' : 'inline-flex',
      width: block ? '100%' : 'auto',
      padding: 4,
      gap: 4,
      background: 'var(--surface-sunken)',
      borderRadius: 'var(--radius-md)',
      ...style
    }
  }, norm.map(o => {
    const active = o.value === value;
    return /*#__PURE__*/React.createElement("button", {
      key: o.value,
      onClick: () => onChange && onChange(o.value),
      style: {
        flex: block ? 1 : 'none',
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 6,
        height: s.h,
        padding: `0 ${s.px}px`,
        fontFamily: 'var(--font-display)',
        fontWeight: 600,
        fontSize: s.fs,
        color: active ? 'var(--color-primary)' : 'var(--text-muted)',
        background: active ? 'var(--surface-card)' : 'transparent',
        border: 'none',
        borderRadius: 'var(--radius-sm)',
        boxShadow: active ? 'var(--shadow-xs)' : 'none',
        cursor: 'pointer',
        transition: 'background var(--dur-fast), color var(--dur-fast)',
        whiteSpace: 'nowrap'
      }
    }, o.icon && /*#__PURE__*/React.createElement("span", {
      className: "material-symbols-rounded",
      style: {
        fontSize: 18
      }
    }, o.icon), o.label);
  }));
}
Object.assign(__ds_scope, { SegmentedControl });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/SegmentedControl.jsx", error: String((e && e.message) || e) }); }

// components/forms/Select.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/** Native select styled to match Procolis inputs. */
function Select({
  label,
  value,
  onChange,
  options = [],
  placeholder,
  icon,
  error,
  disabled = false,
  id,
  style,
  ...rest
}) {
  const [focus, setFocus] = React.useState(false);
  const fid = id || React.useId();
  const borderColor = error ? 'var(--color-danger)' : focus ? 'var(--border-focus)' : 'var(--border-default)';
  const norm = options.map(o => typeof o === 'string' ? {
    value: o,
    label: o
  } : o);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 6,
      ...style
    }
  }, label && /*#__PURE__*/React.createElement("label", {
    htmlFor: fid,
    style: {
      fontFamily: 'var(--font-display)',
      fontWeight: 600,
      fontSize: 13,
      color: 'var(--text-body)'
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      height: 48,
      padding: '0 14px',
      background: disabled ? 'var(--surface-sunken)' : 'var(--surface-card)',
      border: `1px solid ${borderColor}`,
      borderRadius: 'var(--radius-md)',
      boxShadow: focus && !error ? 'var(--ring-focus)' : 'none',
      transition: 'border-color var(--dur-fast), box-shadow var(--dur-fast)'
    }
  }, icon && /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 20,
      color: focus ? 'var(--color-primary)' : 'var(--text-faint)'
    }
  }, icon), /*#__PURE__*/React.createElement("select", _extends({
    id: fid,
    value: value,
    onChange: onChange,
    disabled: disabled,
    onFocus: () => setFocus(true),
    onBlur: () => setFocus(false),
    style: {
      flex: 1,
      minWidth: 0,
      appearance: 'none',
      WebkitAppearance: 'none',
      border: 'none',
      outline: 'none',
      background: 'transparent',
      fontFamily: 'var(--font-body)',
      fontWeight: 500,
      fontSize: 15,
      color: value ? 'var(--text-strong)' : 'var(--text-faint)',
      cursor: disabled ? 'not-allowed' : 'pointer'
    }
  }, rest), placeholder && /*#__PURE__*/React.createElement("option", {
    value: "",
    disabled: true
  }, placeholder), norm.map(o => /*#__PURE__*/React.createElement("option", {
    key: o.value,
    value: o.value
  }, o.label))), /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 22,
      color: 'var(--text-muted)',
      pointerEvents: 'none'
    }
  }, "expand_more")), error && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      color: 'var(--color-danger)'
    }
  }, error));
}
Object.assign(__ds_scope, { Select });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Select.jsx", error: String((e && e.message) || e) }); }

// components/forms/Switch.jsx
try { (() => {
/** Switch toggle (assurance, urgence, disponibilité chauffeur). */
function Switch({
  checked = false,
  onChange,
  label,
  description,
  disabled = false,
  id,
  style
}) {
  const fid = id || React.useId();
  return /*#__PURE__*/React.createElement("label", {
    htmlFor: fid,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      cursor: disabled ? 'not-allowed' : 'pointer',
      opacity: disabled ? 0.5 : 1,
      ...style
    }
  }, /*#__PURE__*/React.createElement("button", {
    id: fid,
    role: "switch",
    "aria-checked": checked,
    disabled: disabled,
    onClick: () => onChange && onChange(!checked),
    style: {
      position: 'relative',
      width: 46,
      height: 28,
      flex: 'none',
      padding: 0,
      background: checked ? 'var(--color-primary)' : 'var(--slate-300)',
      border: 'none',
      borderRadius: 'var(--radius-pill)',
      cursor: disabled ? 'not-allowed' : 'pointer',
      transition: 'background var(--dur-base) var(--ease-standard)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: 3,
      left: checked ? 21 : 3,
      width: 22,
      height: 22,
      background: '#fff',
      borderRadius: '50%',
      boxShadow: 'var(--shadow-sm)',
      transition: 'left var(--dur-base) var(--ease-standard)'
    }
  })), (label || description) && /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 1
    }
  }, label && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-display)',
      fontWeight: 600,
      fontSize: 14,
      color: 'var(--text-strong)'
    }
  }, label), description && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12.5,
      color: 'var(--text-muted)'
    }
  }, description)));
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Switch.jsx", error: String((e && e.message) || e) }); }

// components/forms/Textarea.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/** Multi-line text area (parcel notes, offer messages). */
function Textarea({
  label,
  value,
  onChange,
  placeholder,
  rows = 3,
  error,
  help,
  maxLength,
  disabled = false,
  id,
  style,
  ...rest
}) {
  const [focus, setFocus] = React.useState(false);
  const fid = id || React.useId();
  const borderColor = error ? 'var(--color-danger)' : focus ? 'var(--border-focus)' : 'var(--border-default)';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 6,
      ...style
    }
  }, label && /*#__PURE__*/React.createElement("label", {
    htmlFor: fid,
    style: {
      fontFamily: 'var(--font-display)',
      fontWeight: 600,
      fontSize: 13,
      color: 'var(--text-body)'
    }
  }, label), /*#__PURE__*/React.createElement("textarea", _extends({
    id: fid,
    value: value,
    onChange: onChange,
    placeholder: placeholder,
    rows: rows,
    maxLength: maxLength,
    disabled: disabled,
    onFocus: () => setFocus(true),
    onBlur: () => setFocus(false),
    style: {
      resize: 'vertical',
      padding: '12px 14px',
      background: disabled ? 'var(--surface-sunken)' : 'var(--surface-card)',
      border: `1px solid ${borderColor}`,
      borderRadius: 'var(--radius-md)',
      boxShadow: focus && !error ? 'var(--ring-focus)' : 'none',
      fontFamily: 'var(--font-body)',
      fontWeight: 500,
      fontSize: 15,
      lineHeight: 1.5,
      color: 'var(--text-strong)',
      outline: 'none',
      transition: 'border-color var(--dur-fast), box-shadow var(--dur-fast)'
    }
  }, rest)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'space-between'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      color: error ? 'var(--color-danger)' : 'var(--text-muted)'
    }
  }, error || help || ''), maxLength != null && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      color: 'var(--text-faint)',
      fontFamily: 'var(--font-mono)'
    }
  }, (value || '').length, "/", maxLength)));
}
Object.assign(__ds_scope, { Textarea });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Textarea.jsx", error: String((e && e.message) || e) }); }

// components/navigation/AppBar.jsx
try { (() => {
/** Mobile top app bar. Optional brand-gradient hero variant. */
function AppBar({
  title,
  subtitle,
  leading,
  actions,
  variant = 'default',
  onBack,
  style
}) {
  const gradient = variant === 'brand';
  return /*#__PURE__*/React.createElement("header", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      height: 56,
      padding: '0 8px 0 6px',
      background: gradient ? 'var(--gradient-brand)' : 'var(--surface-card)',
      borderBottom: gradient ? 'none' : '1px solid var(--border-subtle)',
      color: gradient ? '#fff' : 'var(--text-strong)',
      ...style
    }
  }, onBack ? /*#__PURE__*/React.createElement("button", {
    onClick: onBack,
    "aria-label": "Retour",
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      width: 44,
      height: 44,
      border: 'none',
      background: 'transparent',
      color: 'inherit',
      cursor: 'pointer',
      borderRadius: 'var(--radius-sm)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 24
    }
  }, "arrow_back")) : leading || /*#__PURE__*/React.createElement("span", {
    style: {
      width: 8
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0,
      paddingLeft: onBack || leading ? 0 : 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: 'var(--font-display)',
      fontWeight: 700,
      fontSize: 18,
      lineHeight: 1.1,
      overflow: 'hidden',
      textOverflow: 'ellipsis',
      whiteSpace: 'nowrap'
    }
  }, title), subtitle && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12.5,
      opacity: gradient ? 0.85 : 1,
      color: gradient ? '#fff' : 'var(--text-muted)',
      marginTop: 1
    }
  }, subtitle)), actions && /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 2,
      flex: 'none'
    }
  }, actions));
}
Object.assign(__ds_scope, { AppBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/AppBar.jsx", error: String((e && e.message) || e) }); }

// components/navigation/Fab.jsx
try { (() => {
/** Floating action button — "Nouveau colis". */
function Fab({
  icon = 'add',
  label,
  onClick,
  tone = 'primary',
  style
}) {
  const [hover, setHover] = React.useState(false);
  const [press, setPress] = React.useState(false);
  const tones = {
    primary: {
      bg: 'var(--color-primary)',
      fg: '#fff',
      sh: 'var(--shadow-brand)',
      hb: 'var(--color-primary-hover)'
    },
    amber: {
      bg: 'var(--color-accent)',
      fg: '#3a2600',
      sh: 'var(--shadow-amber)',
      hb: 'var(--color-accent-hover)'
    }
  };
  const t = tones[tone] || tones.primary;
  const extended = !!label;
  return /*#__PURE__*/React.createElement("button", {
    onClick: onClick,
    "aria-label": label || 'Action',
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => {
      setHover(false);
      setPress(false);
    },
    onMouseDown: () => setPress(true),
    onMouseUp: () => setPress(false),
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 8,
      height: 56,
      width: extended ? 'auto' : 56,
      padding: extended ? '0 22px 0 18px' : 0,
      background: hover ? t.hb : t.bg,
      color: t.fg,
      border: 'none',
      borderRadius: extended ? 'var(--radius-pill)' : '50%',
      boxShadow: press ? 'var(--shadow-sm)' : t.sh,
      cursor: 'pointer',
      transform: press ? 'scale(0.96)' : 'scale(1)',
      transition: 'background var(--dur-fast), transform var(--dur-fast), box-shadow var(--dur-fast)',
      fontFamily: 'var(--font-display)',
      fontWeight: 700,
      fontSize: 15,
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 26,
      fontVariationSettings: "'wght' 500"
    }
  }, icon), label);
}
Object.assign(__ds_scope, { Fab });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/Fab.jsx", error: String((e && e.message) || e) }); }

// components/navigation/Icon.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/** Material Symbols Rounded icon wrapper. */
function Icon({
  name,
  size = 24,
  fill = false,
  weight = 400,
  color = 'currentColor',
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("span", _extends({
    className: "material-symbols-rounded",
    style: {
      fontSize: size,
      color,
      lineHeight: 1,
      flex: 'none',
      fontVariationSettings: `'FILL' ${fill ? 1 : 0}, 'wght' ${weight}, 'GRAD' 0, 'opsz' 24`,
      ...style
    }
  }, rest), name);
}
Object.assign(__ds_scope, { Icon });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/Icon.jsx", error: String((e && e.message) || e) }); }

// components/navigation/TabBar.jsx
try { (() => {
/**
 * Bottom tab bar for the mobile app.
 * items: [{ key, label, icon, badge }]
 */
function TabBar({
  items = [],
  value,
  onChange,
  style
}) {
  return /*#__PURE__*/React.createElement("nav", {
    style: {
      display: 'flex',
      alignItems: 'stretch',
      height: 64,
      padding: '0 6px',
      background: 'var(--surface-card)',
      borderTop: '1px solid var(--border-subtle)',
      boxShadow: '0 -2px 10px rgba(11,70,79,0.05)',
      ...style
    }
  }, items.map(it => {
    const active = it.key === value;
    return /*#__PURE__*/React.createElement("button", {
      key: it.key,
      onClick: () => onChange && onChange(it.key),
      style: {
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 3,
        border: 'none',
        background: 'transparent',
        cursor: 'pointer',
        position: 'relative',
        padding: '6px 0',
        color: active ? 'var(--color-primary)' : 'var(--text-faint)'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'relative'
      }
    }, /*#__PURE__*/React.createElement("span", {
      className: "material-symbols-rounded",
      style: {
        fontSize: 25,
        fontVariationSettings: `'FILL' ${active ? 1 : 0}, 'wght' ${active ? 600 : 400}`
      }
    }, it.icon), it.badge != null && it.badge !== 0 && /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'absolute',
        top: -4,
        right: -8,
        minWidth: 16,
        height: 16,
        padding: '0 4px',
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'var(--red-400)',
        color: '#fff',
        borderRadius: 'var(--radius-pill)',
        fontFamily: 'var(--font-display)',
        fontWeight: 700,
        fontSize: 10,
        border: '2px solid var(--surface-card)'
      }
    }, it.badge)), /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: active ? 700 : 500,
        fontSize: 11
      }
    }, it.label));
  }));
}
Object.assign(__ds_scope, { TabBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/TabBar.jsx", error: String((e && e.message) || e) }); }

// components/navigation/Tabs.jsx
try { (() => {
/** Underline tabs for in-page sections (filters, detail panels). */
function Tabs({
  items = [],
  value,
  onChange,
  style
}) {
  const norm = items.map(o => typeof o === 'string' ? {
    value: o,
    label: o
  } : o);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 4,
      borderBottom: '1px solid var(--border-subtle)',
      ...style
    }
  }, norm.map(it => {
    const active = it.value === value;
    return /*#__PURE__*/React.createElement("button", {
      key: it.value,
      onClick: () => onChange && onChange(it.value),
      style: {
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        padding: '10px 14px',
        border: 'none',
        background: 'transparent',
        cursor: 'pointer',
        fontFamily: 'var(--font-display)',
        fontWeight: active ? 700 : 600,
        fontSize: 14,
        color: active ? 'var(--color-primary)' : 'var(--text-muted)',
        borderBottom: `2px solid ${active ? 'var(--color-primary)' : 'transparent'}`,
        marginBottom: -1,
        transition: 'color var(--dur-fast)',
        whiteSpace: 'nowrap'
      }
    }, it.label, it.count != null && /*#__PURE__*/React.createElement("span", {
      style: {
        minWidth: 18,
        height: 18,
        padding: '0 5px',
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: active ? 'var(--color-primary-soft)' : 'var(--surface-sunken)',
        color: active ? 'var(--color-primary)' : 'var(--text-muted)',
        borderRadius: 'var(--radius-pill)',
        fontSize: 11,
        fontWeight: 700
      }
    }, it.count));
  }));
}
Object.assign(__ds_scope, { Tabs });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/Tabs.jsx", error: String((e && e.message) || e) }); }

// ui_kits/admin/mock.js
try { (() => {
// Procolis admin UI kit — mock data
(function () {
  window.PCAdmin = {
    kpis: [{
      icon: 'package_2',
      tone: 'primary',
      value: '1 284',
      label: 'Colis ce mois',
      delta: 12
    }, {
      icon: 'local_shipping',
      tone: 'green',
      value: '34',
      label: 'En transit',
      delta: 4
    }, {
      icon: 'schedule',
      tone: 'amber',
      value: '18',
      label: 'En attente',
      delta: -6
    }, {
      icon: 'group',
      tone: 'neutral',
      value: '27',
      label: 'Chauffeurs actifs',
      delta: 2
    }],
    parcels: [{
      tracking: 'PC-7F3K-2291',
      client: 'Awa Diallo',
      from: 'Abidjan',
      to: 'Bouaké',
      driver: 'Koffi Aka',
      status: 'transit',
      price: '12 500',
      date: '27/06 · 08:12'
    }, {
      tracking: 'PC-2M9X-7740',
      client: 'Awa Diallo',
      from: 'Abidjan',
      to: 'Yamoussoukro',
      driver: null,
      status: 'free',
      price: '6 000',
      date: '27/06 · 09:40'
    }, {
      tracking: 'PC-8K3P-5521',
      client: 'Yao Kouassi',
      from: 'Abidjan',
      to: 'Daloa',
      driver: null,
      status: 'pending',
      price: '14 500',
      date: '27/06 · 10:02'
    }, {
      tracking: 'PC-5J1B-3382',
      client: 'Fatou Baki',
      from: 'Abidjan',
      to: 'San-Pédro',
      driver: 'Ibrahim Koné',
      status: 'delivered',
      price: '18 000',
      date: '26/06 · 16:30'
    }, {
      tracking: 'PC-9D4C-1120',
      client: 'Yao Kouassi',
      from: 'Abidjan',
      to: 'Korhogo',
      driver: 'Sékou Bamba',
      status: 'pickup',
      price: '22 000',
      date: '26/06 · 14:11'
    }, {
      tracking: 'PC-1A7T-9043',
      client: 'Awa Diallo',
      from: 'Abidjan',
      to: 'Man',
      driver: null,
      status: 'free',
      price: '20 000',
      date: '26/06 · 11:48'
    }, {
      tracking: 'PC-3R6Y-4417',
      client: 'Mariam Cissé',
      from: 'Abidjan',
      to: 'Gagnoa',
      driver: 'Koffi Aka',
      status: 'delivering',
      price: '9 800',
      date: '26/06 · 09:20'
    }],
    drivers: [{
      name: 'Koffi Aka',
      vehicle: 'Toyota Hiace',
      rating: '4,9',
      load: 2,
      status: 'online'
    }, {
      name: 'Ibrahim Koné',
      vehicle: 'Renault Master',
      rating: '4,7',
      load: 0,
      status: 'online'
    }, {
      name: 'Sékou Bamba',
      vehicle: 'Toyota Hiace',
      rating: '4,8',
      load: 1,
      status: 'busy'
    }, {
      name: 'Adama Touré',
      vehicle: 'Hyundai H1',
      rating: '4,6',
      load: 0,
      status: 'offline'
    }, {
      name: 'Bakary Sanogo',
      vehicle: 'Mercedes Sprinter',
      rating: '4,9',
      load: 3,
      status: 'busy'
    }],
    bars: [40, 55, 48, 70, 62, 80, 68, 90, 75, 84, 72, 95]
  };
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/admin/mock.js", error: String((e && e.message) || e) }); }

// ui_kits/mobile-app/mock.js
try { (() => {
// Procolis mobile UI kit — mock data (no backend). window.PCMock
(function () {
  const parcels = [{
    id: 'p1',
    tracking: 'PC-7F3K-2291',
    from: 'Abidjan',
    to: 'Bouaké',
    status: 'transit',
    price: '12 500 FCFA',
    weight: '8 kg',
    type: 'Colis standard',
    eta: '~4 h',
    express: true,
    sender: 'Awa Diallo',
    recipient: 'Moussa Traoré',
    recipientPhone: '+225 07 88 21 04',
    driver: 'Koffi Aka',
    offers: 0
  }, {
    id: 'p2',
    tracking: 'PC-2M9X-7740',
    from: 'Abidjan',
    to: 'Yamoussoukro',
    status: 'free',
    price: '6 000 FCFA',
    weight: '3 kg',
    type: 'Document',
    eta: '~2 h',
    express: false,
    sender: 'Awa Diallo',
    recipient: 'Service RH — Banque Atlantique',
    offers: 3
  }, {
    id: 'p3',
    tracking: 'PC-5J1B-3382',
    from: 'Abidjan',
    to: 'San-Pédro',
    status: 'delivered',
    price: '18 000 FCFA',
    weight: '15 kg',
    type: 'Volumineux',
    eta: 'Livré',
    express: false,
    sender: 'Awa Diallo',
    recipient: 'Comptoir du Port',
    driver: 'Ibrahim Koné',
    offers: 0
  }, {
    id: 'p4',
    tracking: 'PC-9D4C-1120',
    from: 'Abidjan',
    to: 'Korhogo',
    status: 'pending',
    price: '22 000 FCFA',
    weight: '12 kg',
    type: 'Fragile',
    eta: 'À confirmer',
    express: false,
    sender: 'Awa Diallo',
    recipient: 'Pharmacie du Nord',
    offers: 0
  }];

  // libre-service pool seen by a driver
  const freeParcels = [{
    id: 'f1',
    tracking: 'PC-2M9X-7740',
    from: 'Abidjan',
    to: 'Yamoussoukro',
    status: 'free',
    price: '6 000 FCFA',
    weight: '3 kg',
    type: 'Document',
    eta: '~2 h',
    distance: '240 km',
    offers: 3
  }, {
    id: 'f2',
    tracking: 'PC-8K3P-5521',
    from: 'Abidjan',
    to: 'Daloa',
    status: 'free',
    price: '14 500 FCFA',
    weight: '10 kg',
    type: 'Colis standard',
    eta: '~5 h',
    distance: '380 km',
    offers: 1,
    express: true
  }, {
    id: 'f3',
    tracking: 'PC-1A7T-9043',
    from: 'Abidjan',
    to: 'Man',
    status: 'free',
    price: '20 000 FCFA',
    weight: '18 kg',
    type: 'Volumineux',
    eta: '~7 h',
    distance: '570 km',
    offers: 0
  }];
  const offers = [{
    id: 'o1',
    driver: 'Koffi Aka',
    rating: '4,9',
    garage: 'Garage de Cocody',
    price: '11 000 FCFA',
    message: 'Je pars à 14 h, livraison ce soir.',
    hasAudio: true,
    when: 'il y a 8 min'
  }, {
    id: 'o2',
    driver: 'Ibrahim Koné',
    rating: '4,7',
    garage: 'Garage Treichville',
    price: '12 000 FCFA',
    message: 'Disponible immédiatement.',
    hasAudio: false,
    when: 'il y a 22 min'
  }, {
    id: 'o3',
    driver: 'Sékou Bamba',
    rating: '4,8',
    garage: 'Garage de Cocody',
    price: '13 500 FCFA',
    message: 'Véhicule réfrigéré dispo si besoin.',
    hasAudio: true,
    when: 'il y a 1 h'
  }];
  const timeline = [{
    label: 'Colis créé',
    time: 'Auj. 08:12',
    status: 'done',
    icon: 'add_box',
    note: 'Déposé par Awa Diallo'
  }, {
    label: 'Confirmé',
    time: '08:30',
    status: 'done',
    icon: 'check'
  }, {
    label: 'Ramassé · Garage de Cocody',
    time: '09:40',
    status: 'done',
    icon: 'package_2',
    note: 'Chauffeur : Koffi Aka'
  }, {
    label: 'En transit vers Bouaké',
    time: '10:05',
    status: 'current',
    icon: 'local_shipping',
    note: 'Position : Toumodi · ~4 h restantes'
  }, {
    label: 'Arrivé au garage destination',
    status: 'todo',
    icon: 'pin_drop'
  }, {
    label: 'Livré',
    status: 'todo',
    icon: 'task_alt'
  }];
  const notifications = [{
    id: 'n1',
    icon: 'sell',
    tone: 'primary',
    title: 'Nouvelle offre reçue',
    body: 'Koffi A. propose 11 000 FCFA pour PC-2M9X-7740.',
    when: '8 min',
    unread: true
  }, {
    id: 'n2',
    icon: 'local_shipping',
    tone: 'green',
    title: 'Colis en transit',
    body: 'PC-7F3K-2291 part vers Bouaké.',
    when: '1 h',
    unread: true
  }, {
    id: 'n3',
    icon: 'account_balance_wallet',
    tone: 'amber',
    title: 'Points crédités',
    body: '+150 pts pour votre dernière livraison.',
    when: '3 h',
    unread: false
  }, {
    id: 'n4',
    icon: 'task_alt',
    tone: 'green',
    title: 'Colis livré',
    body: 'PC-5J1B-3382 a été livré à San-Pédro.',
    when: 'hier',
    unread: false
  }];
  const cities = ['Abidjan', 'Bouaké', 'Yamoussoukro', 'San-Pédro', 'Korhogo', 'Daloa', 'Man', 'Gagnoa', 'Divo', 'Abengourou'];
  const parcelTypes = ['Colis standard', 'Document', 'Fragile', 'Volumineux', 'Denrées'];
  const user = {
    name: 'Awa Diallo',
    phone: '+221 76 516 27 96',
    city: 'Abidjan',
    points: '2 450',
    initials: 'AD',
    role: 'client'
  };
  window.PCMock = {
    parcels,
    freeParcels,
    offers,
    timeline,
    notifications,
    cities,
    parcelTypes,
    user
  };
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/mobile-app/mock.js", error: String((e && e.message) || e) }); }

// ui_kits/mobile-app/screens-detail.jsx
try { (() => {
/* Procolis mobile UI kit — detail screens. window.PCScreens.* */
(function () {
  const NS = window.ProcolisDesignSystem_1720b4;
  const {
    AppBar,
    IconButton,
    Button,
    Input,
    Card,
    StatBox,
    Badge,
    StatusBadge,
    Tag,
    Avatar,
    ListRow,
    ParcelCard,
    Stepper,
    Toast,
    EmptyState,
    Tabs,
    Switch,
    SegmentedControl
  } = NS;
  const M = window.PCMock;
  const e = React.createElement;
  const Body = window.PCScreens.Body;
  const SectionHeader = window.PCScreens.SectionHeader;
  const colStyle = window.PCScreens.colStyle;

  // =====================================================================
  // TRACK / PARCEL DETAIL
  // =====================================================================
  function TrackScreen({
    nav
  }) {
    const p = M.parcels[0];
    return e('div', {
      style: colStyle
    }, e(AppBar, {
      title: 'Suivi du colis',
      onBack: () => nav('home'),
      actions: e(IconButton, {
        icon: 'share'
      })
    }), e(Body, {
      style: {
        gap: 16
      }
    },
    // tracking hero
    e('div', {
      style: {
        background: 'var(--gradient-brand)',
        borderRadius: 'var(--radius-lg)',
        padding: 18,
        color: '#fff',
        boxShadow: 'var(--shadow-brand)'
      }
    }, e('div', {
      style: {
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between'
      }
    }, e('span', {
      style: {
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6
      }
    }, e('span', {
      className: 'material-symbols-rounded',
      style: {
        fontSize: 18
      }
    }, 'qr_code_2'), e('span', {
      style: {
        fontFamily: 'var(--font-mono)',
        fontWeight: 600,
        fontSize: 14
      }
    }, p.tracking)), e(StatusBadge, {
      status: p.status,
      size: 'sm',
      style: {
        background: 'rgba(255,255,255,.9)'
      }
    })), e('div', {
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        marginTop: 16
      }
    }, e(RouteEnd, {
      label: 'Départ',
      city: p.from
    }), e('div', {
      style: {
        flex: 1,
        position: 'relative',
        height: 2,
        background: 'rgba(255,255,255,.4)'
      }
    }, e('span', {
      className: 'material-symbols-rounded',
      style: {
        position: 'absolute',
        left: '55%',
        top: -12,
        fontSize: 24,
        color: '#fff',
        filter: 'drop-shadow(0 2px 4px rgba(0,0,0,.2))'
      }
    }, 'local_shipping')), e(RouteEnd, {
      label: 'Arrivée',
      city: p.to,
      right: true
    })), e('div', {
      style: {
        display: 'flex',
        gap: 16,
        marginTop: 16,
        fontSize: 12.5
      }
    }, e(HeroMeta, {
      label: 'Distance',
      value: '350 km'
    }), e(HeroMeta, {
      label: 'Temps restant',
      value: '~4 h'
    }), e(HeroMeta, {
      label: 'Prix',
      value: p.price
    }))),
    // driver card
    e(Card, {
      padding: 'sm'
    }, e(ListRow, {
      leading: e(Avatar, {
        name: p.driver,
        status: 'online'
      }),
      title: p.driver,
      subtitle: 'Garage de Cocody · 4,9 ★ · Toyota Hiace',
      trailing: e('div', {
        style: {
          display: 'flex',
          gap: 6
        }
      }, e(IconButton, {
        icon: 'call',
        variant: 'soft'
      }), e(IconButton, {
        icon: 'chat',
        variant: 'soft'
      }))
    })),
    // timeline
    e('div', null, e(SectionHeader, {
      title: 'Historique'
    }), e(Card, {
      padding: 'md'
    }, e(Stepper, {
      steps: M.timeline
    }))), e('div', {
      style: {
        display: 'flex',
        gap: 10
      }
    }, e(Button, {
      block: true,
      variant: 'secondary',
      icon: 'description'
    }, 'Voir le reçu'), e(Button, {
      block: true,
      variant: 'danger',
      icon: 'cancel'
    }, 'Annuler'))));
  }
  function RouteEnd({
    label,
    city,
    right
  }) {
    return e('div', {
      style: {
        textAlign: right ? 'right' : 'left'
      }
    }, e('div', {
      style: {
        fontSize: 10.5,
        opacity: .8,
        textTransform: 'uppercase',
        letterSpacing: '.07em',
        fontWeight: 700
      }
    }, label), e('div', {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: 700,
        fontSize: 17
      }
    }, city));
  }
  function HeroMeta({
    label,
    value
  }) {
    return e('div', null, e('div', {
      style: {
        opacity: .8
      }
    }, label), e('div', {
      style: {
        fontFamily: 'var(--font-mono)',
        fontWeight: 700,
        fontSize: 14,
        marginTop: 1
      }
    }, value));
  }

  // =====================================================================
  // LIBRE SERVICE — client view: offers received on a parcel
  // =====================================================================
  function LibreServiceScreen({
    nav
  }) {
    const [role, setRole] = React.useState('client');
    return e('div', {
      style: colStyle
    }, e(AppBar, {
      title: 'Libre service',
      actions: e(IconButton, {
        icon: 'tune'
      })
    }), e('div', {
      style: {
        padding: '12px 16px 0',
        background: 'var(--surface-card)'
      }
    }, e(SegmentedControl, {
      block: true,
      value: role,
      onChange: setRole,
      options: [{
        value: 'client',
        label: 'Mes offres reçues',
        icon: 'inbox'
      }, {
        value: 'driver',
        label: 'Colis à prendre',
        icon: 'local_shipping'
      }]
    })), role === 'client' ? e(ClientOffers, {
      nav
    }) : e(DriverPool, {
      nav
    }));
  }
  function ClientOffers({
    nav
  }) {
    const p = M.parcels[1];
    const [accepted, setAccepted] = React.useState(null);
    return e(Body, {
      style: {
        gap: 14,
        paddingTop: 16
      }
    }, e(ParcelCard, {
      parcel: p
    }), e(SectionHeader, {
      title: `${M.offers.length} offres reçues`
    }), e('div', {
      style: {
        display: 'flex',
        flexDirection: 'column',
        gap: 12
      }
    }, M.offers.map(o => e(Card, {
      key: o.id,
      padding: 'md',
      style: accepted === o.id ? {
        border: '2px solid var(--color-primary)'
      } : null
    }, e('div', {
      style: {
        display: 'flex',
        gap: 12
      }
    }, e(Avatar, {
      name: o.driver,
      status: 'online'
    }), e('div', {
      style: {
        flex: 1,
        minWidth: 0
      }
    }, e('div', {
      style: {
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between'
      }
    }, e('span', {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: 700,
        fontSize: 15,
        color: 'var(--text-strong)'
      }
    }, o.driver), e('span', {
      style: {
        fontFamily: 'var(--font-mono)',
        fontWeight: 700,
        fontSize: 17,
        color: 'var(--teal-600)'
      }
    }, o.price)), e('div', {
      style: {
        fontSize: 12.5,
        color: 'var(--text-muted)',
        marginTop: 1
      }
    }, `${o.garage} · ${o.rating} ★`), e('div', {
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        marginTop: 10,
        padding: '8px 10px',
        background: 'var(--surface-sunken)',
        borderRadius: 'var(--radius-sm)'
      }
    }, o.hasAudio ? e('span', {
      style: {
        display: 'inline-flex',
        alignItems: 'center',
        gap: 8,
        color: 'var(--color-primary)'
      }
    }, e('span', {
      className: 'material-symbols-rounded',
      style: {
        fontSize: 22
      }
    }, 'play_circle'), e(Waveform), e('span', {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 11,
        color: 'var(--text-muted)'
      }
    }, "0:08")) : e('span', {
      style: {
        fontSize: 13,
        color: 'var(--text-body)',
        fontStyle: 'italic'
      }
    }, `“${o.message}”`)), e('div', {
      style: {
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        marginTop: 10
      }
    }, e('span', {
      style: {
        fontSize: 11.5,
        color: 'var(--text-faint)'
      }
    }, o.when), e('div', {
      style: {
        display: 'flex',
        gap: 8
      }
    }, e(Button, {
      size: 'sm',
      variant: 'secondary'
    }, 'Négocier'), e(Button, {
      size: 'sm',
      icon: 'check',
      onClick: () => setAccepted(o.id)
    }, 'Accepter')))))))));
  }
  function Waveform() {
    const bars = [8, 14, 20, 12, 18, 24, 10, 16, 22, 9, 14, 18, 11];
    return e('span', {
      style: {
        display: 'inline-flex',
        alignItems: 'center',
        gap: 2,
        height: 24
      }
    }, bars.map((h, i) => e('span', {
      key: i,
      style: {
        width: 2.5,
        height: h,
        borderRadius: 2,
        background: i < 5 ? 'var(--color-primary)' : 'var(--teal-200)'
      }
    })));
  }
  function DriverPool({
    nav
  }) {
    return e(Body, {
      style: {
        gap: 12,
        paddingTop: 16
      }
    }, e('div', {
      style: {
        display: 'flex',
        gap: 8,
        marginBottom: 4,
        overflowX: 'auto'
      }
    }, ['Tous', 'Abidjan →', 'Express', '< 10 kg', 'Aujourd’hui'].map((f, i) => e(Tag, {
      key: i,
      tone: i === 0 ? 'primary' : 'neutral'
    }, f))), M.freeParcels.map(p => e(ParcelCard, {
      key: p.id,
      parcel: p,
      footer: e('div', {
        style: {
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between'
        }
      }, e('span', {
        style: {
          fontSize: 12.5,
          color: 'var(--text-muted)'
        }
      }, e('span', {
        className: 'material-symbols-rounded',
        style: {
          fontSize: 15,
          verticalAlign: '-3px',
          marginRight: 3
        }
      }, 'route'), p.distance, ' · ', p.offers, ' offres'), e(Button, {
        size: 'sm',
        icon: 'gavel'
      }, 'Faire une offre'))
    })));
  }

  // =====================================================================
  // NOTIFICATIONS
  // =====================================================================
  function NotificationsScreen({
    nav
  }) {
    return e('div', {
      style: colStyle
    }, e(AppBar, {
      title: 'Notifications',
      onBack: () => nav('home'),
      actions: e(IconButton, {
        icon: 'done_all'
      })
    }), e(Body, {
      style: {
        padding: '8px 12px 96px'
      }
    }, M.notifications.map(n => e('div', {
      key: n.id,
      style: {
        position: 'relative'
      }
    }, e(ListRow, {
      icon: n.icon,
      iconTone: n.tone,
      title: n.title,
      subtitle: n.body,
      trailing: e('span', {
        style: {
          fontSize: 11.5,
          color: 'var(--text-faint)',
          whiteSpace: 'nowrap'
        }
      }, n.when),
      style: n.unread ? {
        background: 'var(--color-primary-soft)'
      } : null
    }), n.unread ? e('span', {
      style: {
        position: 'absolute',
        left: 4,
        top: '50%',
        width: 6,
        height: 6,
        borderRadius: '50%',
        background: 'var(--color-primary)'
      }
    }) : null))));
  }

  // =====================================================================
  // PROFILE
  // =====================================================================
  function ProfileScreen({
    nav
  }) {
    return e('div', {
      style: colStyle
    }, e(AppBar, {
      title: 'Profil',
      actions: e(IconButton, {
        icon: 'edit'
      })
    }), e(Body, {
      style: {
        gap: 18
      }
    }, e('div', {
      style: {
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 8,
        paddingTop: 6
      }
    }, e(Avatar, {
      name: M.user.name,
      size: 'xl',
      status: 'online'
    }), e('div', {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: 800,
        fontSize: 21,
        color: 'var(--text-strong)'
      }
    }, M.user.name), e('div', {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 13,
        color: 'var(--text-muted)'
      }
    }, M.user.phone), e(Badge, {
      tone: 'primary',
      icon: 'verified'
    }, 'Compte vérifié')),
    // points strip
    e('div', {
      style: {
        display: 'flex',
        gap: 10
      }
    }, e(StatBox, {
      icon: 'account_balance_wallet',
      tone: 'amber',
      value: '2 450',
      label: 'Points',
      style: {
        flex: 1
      }
    }), e(StatBox, {
      icon: 'package_2',
      tone: 'primary',
      value: '31',
      label: 'Colis envoyés',
      style: {
        flex: 1
      }
    })), e(Card, {
      padding: 'sm'
    }, e(ListRow, {
      icon: 'person',
      iconTone: 'neutral',
      title: 'Informations personnelles',
      chevron: true
    }), e(Divider), e(ListRow, {
      icon: 'location_on',
      iconTone: 'neutral',
      title: 'Adresses',
      subtitle: `${M.user.city}, Côte d’Ivoire`,
      chevron: true
    }), e(Divider), e(ListRow, {
      icon: 'account_balance_wallet',
      iconTone: 'amber',
      title: 'Points & paiements',
      trailing: e(Badge, {
        tone: 'amber'
      }, '2 450 pts'),
      chevron: true
    }), e(Divider), e(ListRow, {
      icon: 'pin',
      iconTone: 'neutral',
      title: 'Code PIN',
      subtitle: 'Connexion rapide activée',
      chevron: true
    })), e(Card, {
      padding: 'sm'
    }, e(ListRow, {
      icon: 'notifications',
      iconTone: 'neutral',
      title: 'Notifications',
      trailing: e(Switch, {
        checked: true,
        onChange: () => {}
      })
    }), e(Divider), e(ListRow, {
      icon: 'help',
      iconTone: 'neutral',
      title: 'Aide & support',
      chevron: true
    }), e(Divider), e(ListRow, {
      icon: 'logout',
      iconTone: 'neutral',
      title: 'Se déconnecter',
      onClick: () => nav('login')
    })), e('div', {
      style: {
        textAlign: 'center',
        fontSize: 11.5,
        color: 'var(--text-faint)',
        fontFamily: 'var(--font-mono)'
      }
    }, 'PRO COLIS · v1.0.0')));
  }
  function Divider() {
    return e('div', {
      style: {
        height: 1,
        background: 'var(--border-subtle)',
        margin: '0 14px'
      }
    });
  }
  window.PCScreens = Object.assign(window.PCScreens || {}, {
    TrackScreen,
    LibreServiceScreen,
    NotificationsScreen,
    ProfileScreen
  });
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/mobile-app/screens-detail.jsx", error: String((e && e.message) || e) }); }

// ui_kits/mobile-app/screens-main.jsx
try { (() => {
/* Procolis mobile UI kit — primary screens. window.PCScreens.* */
(function () {
  const NS = window.ProcolisDesignSystem_1720b4;
  const {
    AppBar,
    TabBar,
    Fab,
    IconButton,
    Button,
    Input,
    Select,
    Switch,
    Checkbox,
    SegmentedControl,
    Card,
    StatBox,
    Badge,
    StatusBadge,
    Tag,
    Avatar,
    ListRow,
    ParcelCard,
    Stepper,
    Toast,
    EmptyState,
    Tabs
  } = NS;
  const M = window.PCMock;
  const e = React.createElement;

  // ---- small shared bits ----------------------------------------
  function SectionHeader({
    title,
    action,
    onAction
  }) {
    return e('div', {
      style: {
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        margin: '4px 2px 10px'
      }
    }, e('span', {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: 700,
        fontSize: 16,
        color: 'var(--text-strong)'
      }
    }, title), action && e('button', {
      onClick: onAction,
      style: {
        border: 'none',
        background: 'transparent',
        color: 'var(--text-link)',
        fontFamily: 'var(--font-display)',
        fontWeight: 600,
        fontSize: 13,
        cursor: 'pointer'
      }
    }, action));
  }
  const Body = props => e('div', {
    style: {
      flex: 1,
      overflowY: 'auto',
      padding: '16px 16px 96px',
      display: 'flex',
      flexDirection: 'column',
      ...props.style
    }
  }, props.children);

  // =====================================================================
  // LOGIN — phone + OTP / PIN
  // =====================================================================
  function LoginScreen({
    nav
  }) {
    const [mode, setMode] = React.useState('phone'); // phone | otp | pin
    const [phone, setPhone] = React.useState('07 11 45 90');
    const [otp, setOtp] = React.useState(['', '', '', '']);
    const [pin, setPin] = React.useState('');
    const Hero = e('div', {
      style: {
        background: 'var(--gradient-brand)',
        padding: '56px 24px 30px',
        color: '#fff',
        textAlign: 'center'
      }
    }, e('img', {
      src: '../../assets/logo-procolis.png',
      alt: 'Procolis',
      style: {
        width: 76,
        height: 76,
        objectFit: 'contain',
        filter: 'drop-shadow(0 6px 14px rgba(0,0,0,.25))'
      }
    }), e('div', {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: 800,
        fontSize: 26,
        letterSpacing: '-.02em',
        marginTop: 10
      }
    }, 'PRO COLIS'), e('div', {
      style: {
        fontSize: 14,
        opacity: .9,
        marginTop: 2
      }
    }, 'Vos colis, de ville en ville'));
    let form;
    if (mode === 'phone') {
      form = e(React.Fragment, null, e('h2', {
        style: titleStyle
      }, 'Connexion'), e('p', {
        style: subStyle
      }, 'Entrez votre numéro pour recevoir un code de vérification.'), e('div', {
        style: {
          display: 'flex',
          gap: 10,
          marginTop: 18
        }
      }, e('div', {
        style: {
          display: 'flex',
          alignItems: 'center',
          gap: 6,
          padding: '0 12px',
          height: 48,
          border: '1px solid var(--border-default)',
          borderRadius: 'var(--radius-md)',
          background: 'var(--surface-card)',
          fontWeight: 600,
          color: 'var(--text-body)',
          fontSize: 15
        }
      }, '🇨🇮 +225'), e('div', {
        style: {
          flex: 1
        }
      }, e(Input, {
        value: phone,
        onChange: ev => setPhone(ev.target.value),
        placeholder: '07 00 00 00',
        mono: true
      }))), e('div', {
        style: {
          marginTop: 22
        }
      }, e(Button, {
        block: true,
        size: 'lg',
        onClick: () => setMode('otp'),
        iconTrailing: 'arrow_forward'
      }, 'Recevoir le code')), e('div', {
        style: {
          textAlign: 'center',
          marginTop: 16
        }
      }, e('button', {
        onClick: () => setMode('pin'),
        style: linkBtn
      }, 'Se connecter avec un code PIN')), e('p', {
        style: {
          ...subStyle,
          textAlign: 'center',
          marginTop: 24,
          fontSize: 12.5
        }
      }, 'Pas encore de compte ? ', e('span', {
        style: {
          color: 'var(--text-link)',
          fontWeight: 700
        }
      }, 'Créer un compte')));
    } else if (mode === 'otp') {
      form = e(React.Fragment, null, e('h2', {
        style: titleStyle
      }, 'Vérification'), e('p', {
        style: subStyle
      }, `Code envoyé au +225 ${phone}.`), e('div', {
        style: {
          display: 'flex',
          gap: 12,
          justifyContent: 'center',
          margin: '24px 0 8px'
        }
      }, [0, 1, 2, 3].map(i => e('input', {
        key: i,
        value: otp[i],
        maxLength: 1,
        inputMode: 'numeric',
        onChange: ev => {
          const n = [...otp];
          n[i] = ev.target.value.slice(-1);
          setOtp(n);
        },
        style: {
          width: 56,
          height: 64,
          textAlign: 'center',
          fontFamily: 'var(--font-mono)',
          fontWeight: 700,
          fontSize: 26,
          color: 'var(--text-strong)',
          border: `2px solid ${otp[i] ? 'var(--color-primary)' : 'var(--border-default)'}`,
          borderRadius: 'var(--radius-md)',
          outline: 'none',
          background: 'var(--surface-card)'
        }
      }))), e('p', {
        style: {
          ...subStyle,
          textAlign: 'center'
        }
      }, 'Renvoyer le code dans ', e('span', {
        style: {
          fontFamily: 'var(--font-mono)',
          color: 'var(--text-body)'
        }
      }, '00:42')), e('div', {
        style: {
          marginTop: 22
        }
      }, e(Button, {
        block: true,
        size: 'lg',
        onClick: () => nav('home')
      }, 'Vérifier')), e('div', {
        style: {
          textAlign: 'center',
          marginTop: 14
        }
      }, e('button', {
        onClick: () => setMode('phone'),
        style: linkBtn
      }, 'Modifier le numéro')));
    } else {
      form = e(React.Fragment, null, e('h2', {
        style: titleStyle
      }, 'Code PIN'), e('p', {
        style: subStyle
      }, 'Entrez votre code à 4 chiffres pour Awa Diallo.'), e('div', {
        style: {
          display: 'flex',
          gap: 14,
          justifyContent: 'center',
          margin: '26px 0'
        }
      }, [0, 1, 2, 3].map(i => e('span', {
        key: i,
        style: {
          width: 18,
          height: 18,
          borderRadius: '50%',
          background: i < pin.length ? 'var(--color-primary)' : 'var(--slate-200)',
          border: i < pin.length ? 'none' : '1px solid var(--border-default)'
        }
      }))), e(Keypad, {
        onKey: k => {
          if (k === 'del') setPin(pin.slice(0, -1));else if (pin.length < 4) {
            const np = pin + k;
            setPin(np);
            if (np.length === 4) setTimeout(() => nav('home'), 180);
          }
        }
      }), e('div', {
        style: {
          textAlign: 'center',
          marginTop: 12
        }
      }, e('button', {
        onClick: () => setMode('phone'),
        style: linkBtn
      }, 'Utiliser le numéro de téléphone')));
    }
    return e('div', {
      style: {
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        background: 'var(--surface-page)'
      }
    }, Hero, e('div', {
      style: {
        flex: 1,
        overflowY: 'auto',
        padding: '26px 24px'
      }
    }, form));
  }
  const titleStyle = {
    fontFamily: 'var(--font-display)',
    fontWeight: 800,
    fontSize: 24,
    color: 'var(--text-strong)',
    margin: 0,
    letterSpacing: '-.01em'
  };
  const subStyle = {
    fontSize: 14,
    color: 'var(--text-muted)',
    margin: '6px 0 0',
    lineHeight: 1.5
  };
  const linkBtn = {
    border: 'none',
    background: 'transparent',
    color: 'var(--text-link)',
    fontFamily: 'var(--font-display)',
    fontWeight: 600,
    fontSize: 13.5,
    cursor: 'pointer'
  };
  function Keypad({
    onKey
  }) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];
    return e('div', {
      style: {
        display: 'grid',
        gridTemplateColumns: 'repeat(3,1fr)',
        gap: 10,
        maxWidth: 260,
        margin: '0 auto'
      }
    }, keys.map((k, i) => k === '' ? e('span', {
      key: i
    }) : e('button', {
      key: i,
      onClick: () => onKey(k),
      style: {
        height: 56,
        borderRadius: 'var(--radius-md)',
        border: '1px solid var(--border-subtle)',
        background: 'var(--surface-card)',
        fontFamily: 'var(--font-display)',
        fontWeight: 700,
        fontSize: 22,
        color: 'var(--text-strong)',
        cursor: 'pointer',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center'
      }
    }, k === 'del' ? e('span', {
      className: 'material-symbols-rounded',
      style: {
        fontSize: 24
      }
    }, 'backspace') : k)));
  }

  // =====================================================================
  // HOME — client dashboard
  // =====================================================================
  function HomeScreen({
    nav,
    unread
  }) {
    return e('div', {
      style: colStyle
    },
    // brand hero with points
    e('div', {
      style: {
        background: 'var(--gradient-brand)',
        padding: '52px 16px 22px',
        color: '#fff'
      }
    }, e('div', {
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: 12
      }
    }, e(Avatar, {
      name: M.user.name,
      status: 'online'
    }), e('div', {
      style: {
        flex: 1,
        minWidth: 0
      }
    }, e('div', {
      style: {
        fontSize: 12.5,
        opacity: .85
      }
    }, 'Bonjour,'), e('div', {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: 700,
        fontSize: 17
      }
    }, M.user.name)), e(IconButton, {
      icon: 'search',
      variant: 'ghost',
      style: {
        color: '#fff'
      }
    }), e('span', {
      style: {
        position: 'relative'
      }
    }, e(IconButton, {
      icon: 'notifications',
      variant: 'ghost',
      style: {
        color: '#fff'
      },
      onClick: () => nav('notifications')
    }), unread ? e('span', {
      style: notifDot
    }, unread) : null)),
    // points card
    e('div', {
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: 14,
        marginTop: 16,
        padding: 14,
        background: 'rgba(255,255,255,.14)',
        borderRadius: 'var(--radius-lg)',
        backdropFilter: 'blur(4px)'
      }
    }, e('span', {
      style: {
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        width: 44,
        height: 44,
        borderRadius: 'var(--radius-md)',
        background: 'rgba(255,255,255,.18)'
      }
    }, e('span', {
      className: 'material-symbols-rounded',
      style: {
        fontSize: 24,
        fontVariationSettings: "'FILL' 1"
      }
    }, 'account_balance_wallet')), e('div', {
      style: {
        flex: 1
      }
    }, e('div', {
      style: {
        fontSize: 11.5,
        opacity: .85,
        textTransform: 'uppercase',
        letterSpacing: '.07em',
        fontWeight: 700
      }
    }, 'Solde de points'), e('div', {
      style: {
        fontFamily: 'var(--font-mono)',
        fontWeight: 700,
        fontSize: 23,
        marginTop: 1
      }
    }, M.user.points, e('span', {
      style: {
        fontSize: 14,
        opacity: .8
      }
    }, ' pts'))), e(Button, {
      variant: 'amber',
      size: 'sm',
      icon: 'add'
    }, 'Recharger'))), e('div', {
      style: {
        flex: 1,
        overflowY: 'auto',
        padding: '18px 16px 96px'
      }
    },
    // quick actions
    e('div', {
      style: {
        display: 'grid',
        gridTemplateColumns: 'repeat(4,1fr)',
        gap: 10,
        marginBottom: 22
      }
    }, [['add_box', 'Nouveau', () => nav('new')], ['sell', 'Libre service', () => nav('libre')], ['qr_code_2', 'Suivre', () => nav('track')], ['history', 'Historique', () => nav('colis')]].map(([ic, lb, fn], i) => e('button', {
      key: i,
      onClick: fn,
      style: quickBtn
    }, e('span', {
      style: quickIcon
    }, e('span', {
      className: 'material-symbols-rounded',
      style: {
        fontSize: 24,
        color: 'var(--color-primary)',
        fontVariationSettings: "'FILL' 1"
      }
    }, ic)), e('span', {
      style: {
        fontSize: 11.5,
        fontWeight: 600,
        color: 'var(--text-body)'
      }
    }, lb)))),
    // KPI row
    e('div', {
      style: {
        display: 'grid',
        gridTemplateColumns: '1fr 1fr',
        gap: 10,
        marginBottom: 22
      }
    }, e(StatBox, {
      icon: 'package_2',
      tone: 'primary',
      value: '3',
      label: 'Colis en cours'
    }), e(StatBox, {
      icon: 'task_alt',
      tone: 'green',
      value: '28',
      label: 'Colis livrés'
    })), e(SectionHeader, {
      title: 'Mes colis récents',
      action: 'Tout voir',
      onAction: () => nav('colis')
    }), e('div', {
      style: {
        display: 'flex',
        flexDirection: 'column',
        gap: 12
      }
    }, M.parcels.slice(0, 2).map(p => e(ParcelCard, {
      key: p.id,
      parcel: p,
      onClick: () => nav('track'),
      footer: p.status === 'free' ? e(Button, {
        block: true,
        variant: 'secondary',
        size: 'sm',
        iconTrailing: 'chevron_right'
      }, `${p.offers} offres reçues`) : null
    })))));
  }

  // =====================================================================
  // MES COLIS — list with filter tabs
  // =====================================================================
  function MesColisScreen({
    nav
  }) {
    const [tab, setTab] = React.useState('cours');
    const filterMap = {
      cours: ['pending', 'free', 'confirmed', 'pickup', 'transit', 'arrived', 'delivering'],
      livres: ['delivered'],
      annules: ['cancelled']
    };
    const list = M.parcels.filter(p => filterMap[tab].includes(p.status));
    return e('div', {
      style: colStyle
    }, e(AppBar, {
      title: 'Mes colis',
      actions: e(IconButton, {
        icon: 'tune'
      })
    }), e('div', {
      style: {
        padding: '0 16px',
        background: 'var(--surface-card)',
        borderBottom: '1px solid var(--border-subtle)'
      }
    }, e(Tabs, {
      value: tab,
      onChange: setTab,
      items: [{
        value: 'cours',
        label: 'En cours',
        count: 3
      }, {
        value: 'livres',
        label: 'Livrés',
        count: 1
      }, {
        value: 'annules',
        label: 'Annulés'
      }]
    })), e(Body, null, list.length ? e('div', {
      style: {
        display: 'flex',
        flexDirection: 'column',
        gap: 12
      }
    }, list.map(p => e(ParcelCard, {
      key: p.id,
      parcel: p,
      onClick: () => nav('track')
    }))) : e(EmptyState, {
      icon: 'inbox',
      title: 'Aucun colis ici',
      message: 'Vos colis de cette catégorie apparaîtront ici.',
      action: e(Button, {
        icon: 'add',
        onClick: () => nav('new')
      }, 'Nouveau colis')
    })));
  }

  // =====================================================================
  // NEW PARCEL — creation form
  // =====================================================================
  function NewParcelScreen({
    nav,
    onCreate
  }) {
    const [insurance, setInsurance] = React.useState(true);
    const [urgent, setUrgent] = React.useState(false);
    const [terms, setTerms] = React.useState(false);
    return e('div', {
      style: colStyle
    }, e(AppBar, {
      title: 'Nouveau colis',
      subtitle: 'Étape 1 sur 2',
      onBack: () => nav('home')
    }), e(Body, {
      style: {
        gap: 18
      }
    }, e(FormSection, {
      title: 'Trajet',
      icon: 'route'
    }, e('div', {
      style: {
        display: 'grid',
        gridTemplateColumns: '1fr 1fr',
        gap: 12
      }
    }, e(Select, {
      label: 'Départ',
      icon: 'trip_origin',
      options: M.cities,
      placeholder: 'Ville'
    }), e(Select, {
      label: 'Arrivée',
      icon: 'pin_drop',
      options: M.cities,
      placeholder: 'Ville'
    }))), e(FormSection, {
      title: 'Destinataire',
      icon: 'person_pin'
    }, e(Input, {
      label: 'Nom complet',
      icon: 'badge',
      placeholder: 'Ex : Moussa Traoré'
    }), e(Input, {
      label: 'Téléphone',
      icon: 'call',
      placeholder: '07 00 00 00',
      mono: true
    })), e(FormSection, {
      title: 'Colis',
      icon: 'package_2'
    }, e('div', {
      style: {
        display: 'grid',
        gridTemplateColumns: '1fr 1fr',
        gap: 12
      }
    }, e(Select, {
      label: 'Type',
      icon: 'category',
      options: M.parcelTypes,
      placeholder: 'Type'
    }), e(Input, {
      label: 'Poids',
      suffix: 'kg',
      placeholder: '8',
      mono: true
    })), e(Input, {
      label: 'Description (optionnel)',
      icon: 'description',
      placeholder: 'Contenu du colis'
    })), e(FormSection, {
      title: 'Options',
      icon: 'tune'
    }, e('div', {
      style: {
        display: 'flex',
        flexDirection: 'column',
        gap: 14
      }
    }, e(Switch, {
      checked: insurance,
      onChange: setInsurance,
      label: 'Assurance',
      description: 'Couvre jusqu’à 200 000 FCFA'
    }), e(Switch, {
      checked: urgent,
      onChange: setUrgent,
      label: 'Livraison urgente (express)',
      description: 'Priorité haute, supplément 2 000 FCFA'
    }))),
    // price summary
    e(Card, {
      padding: 'md',
      style: {
        background: 'var(--color-primary-soft)',
        border: '1px solid var(--teal-100)'
      }
    }, e('div', {
      style: {
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between'
      }
    }, e('div', null, e('div', {
      style: {
        fontSize: 12.5,
        color: 'var(--teal-700)',
        fontWeight: 600
      }
    }, 'Prix estimé'), e('div', {
      style: {
        fontFamily: 'var(--font-mono)',
        fontWeight: 700,
        fontSize: 24,
        color: 'var(--teal-700)'
      }
    }, urgent ? '14 500 FCFA' : '12 500 FCFA')), e(Tag, {
      express: urgent ? true : undefined
    }, urgent ? undefined : 'Standard'))), e(Checkbox, {
      checked: terms,
      onChange: setTerms,
      label: 'J’accepte les conditions de transport.'
    }), e(Button, {
      block: true,
      size: 'lg',
      disabled: !terms,
      onClick: () => {
        onCreate && onCreate();
        nav('libre');
      },
      icon: 'sell'
    }, 'Publier en libre service'), e(Button, {
      block: true,
      variant: 'ghost',
      onClick: () => nav('home')
    }, 'Enregistrer comme brouillon')));
  }
  function FormSection({
    title,
    icon,
    children
  }) {
    return e('div', null, e('div', {
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: 7,
        marginBottom: 12
      }
    }, e('span', {
      className: 'material-symbols-rounded',
      style: {
        fontSize: 19,
        color: 'var(--color-primary)'
      }
    }, icon), e('span', {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: 700,
        fontSize: 14.5,
        color: 'var(--text-strong)'
      }
    }, title)), e('div', {
      style: {
        display: 'flex',
        flexDirection: 'column',
        gap: 12
      }
    }, children));
  }
  const colStyle = {
    display: 'flex',
    flexDirection: 'column',
    height: '100%',
    background: 'var(--surface-page)'
  };
  const notifDot = {
    position: 'absolute',
    top: 6,
    right: 6,
    minWidth: 16,
    height: 16,
    padding: '0 4px',
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: 'var(--amber-400)',
    color: '#3a2600',
    borderRadius: '999px',
    fontFamily: 'var(--font-display)',
    fontWeight: 800,
    fontSize: 10,
    border: '2px solid #0a8c84'
  };
  const quickBtn = {
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: 6,
    border: 'none',
    background: 'transparent',
    cursor: 'pointer',
    padding: 0
  };
  const quickIcon = {
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    width: 52,
    height: 52,
    borderRadius: 'var(--radius-md)',
    background: 'var(--color-primary-soft)'
  };
  window.PCScreens = Object.assign(window.PCScreens || {}, {
    LoginScreen,
    HomeScreen,
    MesColisScreen,
    NewParcelScreen,
    SectionHeader,
    Body,
    colStyle
  });
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/mobile-app/screens-main.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Avatar = __ds_scope.Avatar;

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.ListRow = __ds_scope.ListRow;

__ds_ns.ParcelCard = __ds_scope.ParcelCard;

__ds_ns.StatBox = __ds_scope.StatBox;

__ds_ns.PARCEL_STATUS = __ds_scope.PARCEL_STATUS;

__ds_ns.StatusBadge = __ds_scope.StatusBadge;

__ds_ns.Stepper = __ds_scope.Stepper;

__ds_ns.Tag = __ds_scope.Tag;

__ds_ns.Dialog = __ds_scope.Dialog;

__ds_ns.EmptyState = __ds_scope.EmptyState;

__ds_ns.Toast = __ds_scope.Toast;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Checkbox = __ds_scope.Checkbox;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.Input = __ds_scope.Input;

__ds_ns.SegmentedControl = __ds_scope.SegmentedControl;

__ds_ns.Select = __ds_scope.Select;

__ds_ns.Switch = __ds_scope.Switch;

__ds_ns.Textarea = __ds_scope.Textarea;

__ds_ns.AppBar = __ds_scope.AppBar;

__ds_ns.Fab = __ds_scope.Fab;

__ds_ns.Icon = __ds_scope.Icon;

__ds_ns.TabBar = __ds_scope.TabBar;

__ds_ns.Tabs = __ds_scope.Tabs;

})();
