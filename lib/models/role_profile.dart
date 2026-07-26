import 'package:flutter/material.dart';

import '../widgets/pc_components.dart';

/// Une tuile de statistique de profil alimentée par un endpoint de rôle.
class RoleStat {
  final IconData icon;
  final String value;
  final String label;
  final PcTone tone;

  const RoleStat({
    required this.icon,
    required this.value,
    required this.label,
    this.tone = PcTone.neutral,
  });
}

class RoleInfoRow {
  final IconData icon;
  final String title;
  final String subtitle;
  final PcTone tone;

  const RoleInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.tone = PcTone.neutral,
  });
}

class RoleProfileSection {
  final String title;
  final List<RoleInfoRow> rows;

  const RoleProfileSection({required this.title, required this.rows});
}
