// lib/widgets/phone_contact_picker.dart
import 'dart:async';

import 'package:contacts_service_plus/contacts_service_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_theme.dart';

class PhoneContactPicker extends StatefulWidget {
  final Function(String phoneNumber, String contactName) onContactSelected;
  final String? selectedPhone;

  const PhoneContactPicker({
    super.key,
    required this.onContactSelected,
    this.selectedPhone,
  });

  @override
  State<PhoneContactPicker> createState() => _PhoneContactPickerState();
}

class _PhoneContactPickerState extends State<PhoneContactPicker> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = false;
  bool _hasPermission = false;
  String _searchQuery = '';
  Timer? _debounceTimer;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoadContacts();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissionAndLoadContacts() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final status = await Permission.contacts.status;
      
      if (status.isGranted) {
        _hasPermission = true;
        await _loadContacts();
      } else {
        final result = await Permission.contacts.request();
        if (result.isGranted) {
          setState(() {
            _hasPermission = true;
          });
          await _loadContacts();
        } else {
          setState(() {
            _hasPermission = false;
            _isLoading = false;
          });
          _showPermissionDeniedDialog();
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur vérification permission: $e');
      setState(() {
        _isLoading = false;
        _hasPermission = false;
      });
    }
  }

  Future<void> _loadContacts() async {
    if (!_hasPermission) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final contacts = await ContactsService.getContacts();
      
      final validContacts = contacts.where((contact) {
        return contact.phones != null && contact.phones!.isNotEmpty;
      }).toList();
      
      validContacts.sort((a, b) {
        final nameA = a.displayName?.toLowerCase() ?? '';
        final nameB = b.displayName?.toLowerCase() ?? '';
        return nameA.compareTo(nameB);
      });
      
      setState(() {
        _contacts = validContacts;
        _filteredContacts = validContacts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Erreur chargement contacts: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du chargement des contacts: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Permission requise',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Pour importer vos contacts, veuillez autoriser l\'accès à vos contacts dans les paramètres de l\'application.',
          style: TextStyle(
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkPermissionAndLoadContacts();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
            ),
            child: const Text('Réessayer'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
              _checkPermissionAndLoadContacts();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Ouvrir les paramètres'),
          ),
        ],
      ),
    );
  }

  void _filterContacts(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = query;
        if (query.isEmpty) {
          _filteredContacts = _contacts;
        } else {
          final lowerQuery = query.toLowerCase();
          final cleanQuery = lowerQuery.replaceAll(RegExp(r'[^0-9]'), '');
          
          _filteredContacts = _contacts.where((contact) {
            final nameMatches = contact.displayName?.toLowerCase().contains(lowerQuery) ?? false;
            
            final phoneMatches = contact.phones?.any((phone) {
              final phoneValue = phone.value?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
              return phoneValue.contains(cleanQuery);
            }) ?? false;
            
            return nameMatches || phoneMatches;
          }).toList();
        }
      });
    });
  }

  String _formatPhoneNumber(String? phone) {
    if (phone == null) return '';
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barre de recherche
        if (_hasPermission && !_isLoading)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un contact...',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withOpacity( 0.7),
                ),
                prefixIcon: Icon(Icons.search, color: AppTheme.primaryBlue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryBlue.withOpacity( 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppTheme.primaryBlue.withOpacity( 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryBlue,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: AppTheme.cardColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: AppTheme.textSecondary),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _filteredContacts = _contacts;
                          });
                        },
                      )
                    : null,
              ),
              onChanged: _filterContacts,
              controller: TextEditingController(text: _searchQuery),
            ),
          ),
        
        // État de chargement
        if (_isLoading)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.textSecondary.withOpacity( 0.1),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chargement des contacts...',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cela peut prendre quelques secondes',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withOpacity( 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        
        // Liste des contacts
        if (_hasPermission && !_isLoading)
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.textSecondary.withOpacity( 0.1),
              ),
            ),
            constraints: BoxConstraints(
              maxHeight: 300,
              minHeight: _filteredContacts.isEmpty ? 100 : 50,
            ),
            child: _filteredContacts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.contacts_outlined,
                            size: 48,
                            color: AppTheme.textSecondary.withOpacity( 0.3),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Aucun contact trouvé'
                                : 'Aucun résultat pour "$_searchQuery"',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          if (_searchQuery.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _filteredContacts = _contacts;
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryBlue,
                              ),
                              child: const Text('Voir tous les contacts'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: _filteredContacts.length,
                    itemBuilder: (context, index) {
                      final contact = _filteredContacts[index];
                      final displayName = contact.displayName ?? 'Sans nom';
                      final phone = contact.phones?.isNotEmpty == true
                          ? contact.phones!.first.value
                          : null;
                      final formattedPhone = _formatPhoneNumber(phone);
                      final isSelected = formattedPhone == widget.selectedPhone;
                      final initials = _getInitials(displayName);
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? AppTheme.primaryBlue
                              : AppTheme.primaryBlue.withOpacity( 0.1),
                          child: Text(
                            initials,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.primaryBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        title: Text(
                          displayName,
                          style: TextStyle(
                            color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: phone != null
                            ? Text(
                                formattedPhone,
                                style: TextStyle(
                                  color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: AppTheme.primaryBlue,
                                size: 24,
                              )
                            : null,
                        onTap: _isProcessing
                            ? null
                            : () {
                                if (phone != null) {
                                  setState(() {
                                    _isProcessing = true;
                                  });
                                  
                                  widget.onContactSelected(formattedPhone, displayName);
                                  
                                  Future.delayed(const Duration(milliseconds: 500), () {
                                    if (mounted) {
                                      setState(() {
                                        _isProcessing = false;
                                      });
                                    }
                                  });
                                }
                              },
                        tileColor: isSelected
                            ? AppTheme.primaryBlue.withOpacity( 0.05)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabled: !_isProcessing,
                      );
                    },
                  ),
          ),
        
        // État sans permission
        if (!_hasPermission && !_isLoading)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.warningColor.withOpacity( 0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.contact_phone_outlined,
                  size: 48,
                  color: AppTheme.warningColor,
                ),
                const SizedBox(height: 12),
                Text(
                  'Accès aux contacts refusé',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pour importer vos contacts, veuillez autoriser l\'accès',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _checkPermissionAndLoadContacts,
                  icon: const Icon(Icons.settings),
                  label: const Text('Autoriser l\'accès'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}