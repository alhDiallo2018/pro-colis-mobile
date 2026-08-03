import 'dart:async';

import 'package:contacts_service_plus/contacts_service_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_theme.dart';

/// Données utiles d'un contact sélectionné pour remplir un destinataire.
class PhoneContactSelection {
  const PhoneContactSelection({
    required this.phoneNumber,
    required this.contactName,
  });

  final String phoneNumber;
  final String contactName;
}

/// Nettoie un numéro issu du carnet tout en conservant un éventuel préfixe `+`.
String normalizeContactPhoneNumber(String? phoneNumber) {
  final rawPhoneNumber = phoneNumber?.trim() ?? '';
  if (rawPhoneNumber.isEmpty) return '';

  final digits = rawPhoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  return rawPhoneNumber.startsWith('+') ? '+$digits' : digits;
}

/// Ouvre le carnet dans une feuille dédiée et renvoie le contact choisi.
///
/// La vérification de plateforme évite d'appeler le canal natif du plugin sur
/// le Web ou sur une plateforme de bureau non prise en charge.
Future<PhoneContactSelection?> showPhoneContactPicker({
  required BuildContext context,
  String? selectedPhone,
}) async {
  final isSupportedPlatform = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  if (!isSupportedPlatform) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'L’import des contacts est disponible sur Android et iPhone.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return null;
  }

  try {
    return await showModalBottomSheet<PhoneContactSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final mediaQuery = MediaQuery.of(sheetContext);
        final availableHeight =
            mediaQuery.size.height - mediaQuery.viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            16 + mediaQuery.viewInsets.bottom,
          ),
          child: SizedBox(
            // La hauteur se réduit avec le clavier pour éviter tout débordement
            // pendant la recherche d'un contact.
            height: availableHeight * 0.72,
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.slate300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.contact_phone_rounded,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Choisir un contact',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: PhoneContactPicker(
                    selectedPhone: selectedPhone,
                    onContactSelected: (phoneNumber, contactName) {
                      Navigator.of(sheetContext).pop(
                        PhoneContactSelection(
                          phoneNumber: phoneNumber,
                          contactName: contactName,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  } catch (error, stackTrace) {
    debugPrint(
      '[PhoneContactPicker] Impossible d’ouvrir le carnet de contacts: '
      '$error\n$stackTrace',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible d’ouvrir les contacts pour le moment.',
          ),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return null;
  }
}

class PhoneContactPicker extends StatefulWidget {
  const PhoneContactPicker({
    super.key,
    required this.onContactSelected,
    this.selectedPhone,
  });

  final void Function(String phoneNumber, String contactName) onContactSelected;
  final String? selectedPhone;

  @override
  State<PhoneContactPicker> createState() => _PhoneContactPickerState();
}

class _PhoneContactPickerState extends State<PhoneContactPicker>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();

  List<_PhoneContactEntry> _contacts = const [];
  List<_PhoneContactEntry> _filteredContacts = const [];
  bool _isLoading = false;
  bool _hasPermission = false;
  bool _permissionPermanentlyDenied = false;
  String? _loadError;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionAndLoadContacts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Au retour des réglages système, on relit la permission sans afficher
    // immédiatement une nouvelle demande native.
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAndLoadContacts(requestPermission: false);
    }
  }

  Future<void> _checkPermissionAndLoadContacts({
    bool requestPermission = true,
  }) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      var status = await Permission.contacts.status;
      if (!status.isGranted && requestPermission) {
        status = await Permission.contacts.request();
      }
      if (!mounted) return;

      if (!status.isGranted) {
        setState(() {
          _hasPermission = false;
          _permissionPermanentlyDenied = status.isPermanentlyDenied;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _hasPermission = true;
        _permissionPermanentlyDenied = false;
      });
      await _loadContacts();
    } catch (error, stackTrace) {
      debugPrint(
        '[PhoneContactPicker] Erreur pendant la vérification de permission: '
        '$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasPermission = false;
        _loadError = 'Impossible de vérifier l’accès aux contacts.';
      });
    }
  }

  Future<void> _loadContacts() async {
    try {
      // Les miniatures ne sont pas nécessaires ici : les désactiver accélère
      // sensiblement le chargement des carnets volumineux.
      final deviceContacts = await ContactsService.getContacts(
        withThumbnails: false,
        photoHighResolution: false,
      );

      // Un même contact peut avoir plusieurs téléphones. Chaque numéro devient
      // une option indépendante afin de ne jamais sélectionner le mauvais.
      final entries = <_PhoneContactEntry>[];
      final seenEntries = <String>{};
      for (final contact in deviceContacts) {
        final rawName = contact.displayName?.trim() ?? '';
        final displayName = rawName.isEmpty ? 'Sans nom' : rawName;
        for (final phone in contact.phones ?? const <Item>[]) {
          final normalizedPhone = normalizeContactPhoneNumber(phone.value);
          if (normalizedPhone.isEmpty) continue;

          final deduplicationKey =
              '${displayName.toLowerCase()}\u0000$normalizedPhone';
          if (!seenEntries.add(deduplicationKey)) continue;
          entries.add(
            _PhoneContactEntry(
              displayName: displayName,
              contactName: rawName,
              phoneNumber: normalizedPhone,
              phoneLabel: phone.label?.trim(),
            ),
          );
        }
      }

      entries.sort((a, b) {
        final byName =
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        return byName != 0 ? byName : a.phoneNumber.compareTo(b.phoneNumber);
      });

      if (!mounted) return;
      setState(() {
        _contacts = entries;
        _filteredContacts = entries;
        _isLoading = false;
        _loadError = null;
      });
    } catch (error, stackTrace) {
      debugPrint(
        '[PhoneContactPicker] Erreur pendant le chargement des contacts: '
        '$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Impossible de charger les contacts pour le moment.';
      });
    }
  }

  void _filterContacts(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;

      final normalizedQuery = query.trim().toLowerCase();
      final phoneQuery = normalizedQuery.replaceAll(RegExp(r'[^0-9]'), '');
      setState(() {
        if (normalizedQuery.isEmpty) {
          _filteredContacts = _contacts;
          return;
        }
        _filteredContacts = _contacts.where((contact) {
          final matchesName =
              contact.displayName.toLowerCase().contains(normalizedQuery);
          final matchesPhone = phoneQuery.isNotEmpty &&
              contact.phoneNumber.replaceAll('+', '').contains(phoneQuery);
          return matchesName || matchesPhone;
        }).toList();
      });
    });
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() => _filteredContacts = _contacts);
  }

  Future<void> _openSettings() async {
    try {
      final didOpen = await openAppSettings();
      if (!didOpen) {
        throw StateError('Les réglages système n’ont pas pu être ouverts.');
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[PhoneContactPicker] Impossible d’ouvrir les réglages: '
        '$error\n$stackTrace',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d’ouvrir les réglages du téléphone.'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty || name == 'Sans nom') return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 14),
            Text('Chargement des contacts…'),
          ],
        ),
      );
    }

    if (!_hasPermission) {
      return _PermissionMessage(
        permanentlyDenied: _permissionPermanentlyDenied,
        errorMessage: _loadError,
        onPressed: _permissionPermanentlyDenied
            ? _openSettings
            : _checkPermissionAndLoadContacts,
      );
    }

    if (_loadError != null) {
      return _ContactStateMessage(
        icon: Icons.sync_problem_rounded,
        title: 'Chargement impossible',
        message: _loadError!,
        actionLabel: 'Réessayer',
        onPressed: _loadContacts,
      );
    }

    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: _filterContacts,
          decoration: InputDecoration(
            hintText: 'Rechercher par nom ou numéro',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, child) {
                return value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'Effacer',
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close_rounded),
                      );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _filteredContacts.isEmpty
              ? _ContactStateMessage(
                  icon: Icons.contacts_outlined,
                  title: _contacts.isEmpty
                      ? 'Aucun contact avec un numéro'
                      : 'Aucun résultat',
                  message: _contacts.isEmpty
                      ? 'Ajoutez un contact sur votre téléphone ou saisissez '
                          'le destinataire manuellement.'
                      : 'Essayez un autre nom ou numéro.',
                  actionLabel:
                      _contacts.isEmpty ? null : 'Voir tous les contacts',
                  onPressed: _contacts.isEmpty ? null : _clearSearch,
                )
              : ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: _filteredContacts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final contact = _filteredContacts[index];
                    final isSelected = contact.phoneNumber ==
                        normalizeContactPhoneNumber(widget.selectedPhone);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? AppTheme.primary
                            : AppTheme.primaryLight,
                        child: Text(
                          _getInitials(contact.displayName),
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        contact.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        [
                          contact.phoneNumber,
                          if (contact.phoneLabel?.isNotEmpty == true)
                            contact.phoneLabel!,
                        ].join(' · '),
                        style: TextStyle(color: AppTheme.textBody),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.primary,
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () => widget.onContactSelected(
                        contact.phoneNumber,
                        contact.contactName,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PhoneContactEntry {
  const _PhoneContactEntry({
    required this.displayName,
    required this.contactName,
    required this.phoneNumber,
    this.phoneLabel,
  });

  final String displayName;
  final String contactName;
  final String phoneNumber;
  final String? phoneLabel;
}

class _PermissionMessage extends StatelessWidget {
  const _PermissionMessage({
    required this.permanentlyDenied,
    required this.errorMessage,
    required this.onPressed,
  });

  final bool permanentlyDenied;
  final String? errorMessage;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _ContactStateMessage(
      icon: Icons.contact_phone_outlined,
      title: errorMessage ?? 'Autorisez l’accès aux contacts',
      message: permanentlyDenied
          ? 'L’accès a été refusé. Ouvrez les réglages du téléphone pour '
              'l’autoriser.'
          : 'Cette autorisation sert uniquement à choisir rapidement le nom '
              'et le numéro du destinataire.',
      actionLabel:
          permanentlyDenied ? 'Ouvrir les réglages' : 'Autoriser l’accès',
      onPressed: onPressed,
    );
  }
}

class _ContactStateMessage extends StatelessWidget {
  const _ContactStateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            if (actionLabel != null && onPressed != null) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onPressed,
                icon: Icon(
                  permanentlySettingsIcon(actionLabel!)
                      ? Icons.settings_rounded
                      : Icons.refresh_rounded,
                ),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool permanentlySettingsIcon(String label) => label.contains('réglages');
}
