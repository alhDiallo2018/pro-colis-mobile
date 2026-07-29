import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:procolis/theme/fonts.dart';

import '../providers/broadcast_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class BroadcastBanner extends ConsumerStatefulWidget {
  const BroadcastBanner({super.key});

  @override
  ConsumerState<BroadcastBanner> createState() => _BroadcastBannerState();
}

class _BroadcastBannerState extends ConsumerState<BroadcastBanner> {
  Timer? _rotationTimer;
  Timer? _snoozeWakeTimer;
  DateTime? _scheduledWakeAt;
  int _activeCount = 0;
  int _currentIndex = 0;
  Map<String, DateTime> _snoozedUntil = {};
  String? _loadedUserScope;
  bool _snoozesLoaded = false;

  Future<void> _loadSnoozes(String userScope) async {
    final snoozes = await loadBroadcastSnoozes(userScope);
    if (mounted && _loadedUserScope == userScope) {
      setState(() {
        _snoozedUntil = snoozes;
        _snoozesLoaded = true;
      });
      _scheduleSnoozeWakeUp();
    }
  }

  void _scheduleSnoozeWakeUp() {
    final now = DateTime.now();
    final futureExpirations = _snoozedUntil.values
        .where((expiration) => expiration.isAfter(now))
        .toList()
      ..sort();
    final nextExpiration =
        futureExpirations.isEmpty ? null : futureExpirations.first;

    if (nextExpiration == _scheduledWakeAt &&
        _snoozeWakeTimer?.isActive == true) {
      return;
    }

    _snoozeWakeTimer?.cancel();
    _scheduledWakeAt = nextExpiration;
    if (nextExpiration == null) return;

    // Réveiller précisément le bandeau rend la durée effective même si
    // l'utilisateur reste sur le même tableau de bord pendant deux heures.
    _snoozeWakeTimer = Timer(
      nextExpiration.difference(now) + const Duration(milliseconds: 100),
      () {
        if (!mounted) return;
        final currentTime = DateTime.now();
        setState(() {
          _snoozedUntil = Map<String, DateTime>.from(_snoozedUntil)
            ..removeWhere((_, expiration) => !expiration.isAfter(currentTime));
        });
        _scheduledWakeAt = null;
        _scheduleSnoozeWakeUp();
      },
    );
  }

  Future<void> _snooze(String broadcastId) async {
    final userScope = _loadedUserScope;
    if (userScope == null) return;

    final until = DateTime.now().add(broadcastSnoozeDuration);
    setState(() => _snoozedUntil = {
          ..._snoozedUntil,
          broadcastId: until,
        });
    _scheduleSnoozeWakeUp();

    try {
      await snoozeBroadcast(broadcastId, userScope);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Message masqué pendant 2 heures'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Annuler',
            onPressed: () => unawaited(_restore(broadcastId, userScope)),
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'BroadcastBanner: mise en veille de $broadcastId impossible '
        '($error)\n$stackTrace',
      );
    }
  }

  Future<void> _restore(String broadcastId, String userScope) async {
    setState(() {
      _snoozedUntil = Map<String, DateTime>.from(_snoozedUntil)
        ..remove(broadcastId);
    });
    _scheduleSnoozeWakeUp();
    try {
      await restoreBroadcast(broadcastId, userScope);
    } catch (error, stackTrace) {
      debugPrint(
        'BroadcastBanner: restauration de $broadcastId impossible '
        '($error)\n$stackTrace',
      );
    }
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _snoozeWakeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.user?.role;
    final userScope = authState.user?.id;
    final broadcastsAsync = ref.watch(broadcastProvider);

    // Le stockage est isolé par compte : fermer un message sur un téléphone
    // partagé ne doit pas le cacher pour l'utilisateur suivant.
    if (userScope != null && userScope != _loadedUserScope) {
      _loadedUserScope = userScope;
      _snoozedUntil = {};
      _snoozesLoaded = false;
      unawaited(_loadSnoozes(userScope));
    }

    return broadcastsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (all) {
        if (userScope == null || !_snoozesLoaded) {
          return const SizedBox.shrink();
        }
        final active = filterActiveBroadcasts(all, _snoozedUntil, role?.value);
        _activeCount = active.length;
        if (active.isEmpty) {
          _rotationTimer?.cancel();
          _rotationTimer = null;
          return const SizedBox.shrink();
        }

        if (_currentIndex >= active.length) {
          _currentIndex = 0;
        }

        final broadcast = active[_currentIndex];
        final hasImage =
            broadcast.imageUrl != null && broadcast.imageUrl!.isNotEmpty;

        if (active.length <= 1) {
          _rotationTimer?.cancel();
          _rotationTimer = null;
        } else if (_rotationTimer == null || !_rotationTimer!.isActive) {
          // Le timer lit le nombre courant au lieu de capturer une ancienne
          // liste de diffusions susceptible de changer après un refresh.
          _rotationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
            if (mounted && _activeCount > 1) {
              setState(() {
                _currentIndex = (_currentIndex + 1) % _activeCount;
              });
            }
          });
        }

        final typeColor = _typeColor(broadcast.type);
        final typeIcon = _typeIcon(broadcast.type);

        return Container(
          width: double.infinity,
          color: typeColor.withAlpha(30),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(typeIcon, size: 16, color: typeColor),
              const SizedBox(width: 6),
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    ApiService.resolveMediaUrl(broadcast.imageUrl!),
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              if (hasImage) const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (broadcast.title.isNotEmpty)
                      Text(
                        broadcast.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.plusJakartaSans(
                          fontSize: 11,
                          color: typeColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    broadcast.scroll
                        ? _MarqueeText(message: broadcast.message)
                        : Text(
                            broadcast.message,
                            maxLines: broadcast.title.isNotEmpty ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.manrope(
                              fontSize: 11,
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ],
                ),
              ),
              if (active.length > 1) ...[
                const SizedBox(width: 4),
                Text(
                  '${_currentIndex + 1}/${active.length}',
                  style: AppFonts.manrope(
                    fontSize: 10,
                    color: AppTheme.slate400,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _snooze(broadcast.id),
                icon: const Icon(Icons.close_rounded),
                iconSize: 16,
                color: AppTheme.slate400,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                tooltip: 'Masquer pendant 2 heures',
              ),
            ],
          ),
        );
      },
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'warning':
        return AppTheme.amber500;
      case 'success':
        return AppTheme.green600;
      case 'promo':
        return const Color(0xFF1D4ED8);
      default:
        return AppTheme.primary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'warning':
        return Icons.campaign;
      case 'success':
        return Icons.check_circle;
      case 'promo':
        return Icons.sell;
      default:
        return Icons.info;
    }
  }
}

class _MarqueeText extends StatefulWidget {
  final String message;

  const _MarqueeText({required this.message});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.message.length ~/ 5 + 3),
    )..repeat(reverse: false);

    _animation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: const Offset(-0.3, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SlideTransition(
        position: _animation,
        child: Text(
          widget.message,
          maxLines: 1,
          overflow: TextOverflow.visible,
          style: AppFonts.manrope(
            fontSize: 12,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
