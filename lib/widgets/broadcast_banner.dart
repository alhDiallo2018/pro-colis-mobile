import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/broadcast.dart';
import '../providers/broadcast_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

class BroadcastBanner extends ConsumerStatefulWidget {
  const BroadcastBanner({super.key});

  @override
  ConsumerState<BroadcastBanner> createState() => _BroadcastBannerState();
}

class _BroadcastBannerState extends ConsumerState<BroadcastBanner> {
  Timer? _timer;
  int _currentIndex = 0;
  Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    final d = await _loadDismissedSet();
    if (mounted) {
      setState(() => _dismissed = d);
    }
  }

  Future<Set<String>> _loadDismissedSet() async {
    try {
      final sp = await ref.read(sharedPreferencesProvider.future);
      final raw = sp.getStringList('procolis-broadcasts-dismissed');
      return raw?.toSet() ?? {};
    } catch (_) {
      return {};
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.user?.role;
    final broadcastsAsync = ref.watch(broadcastProvider);

    return broadcastsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (all) {
        final active = filterActiveBroadcasts(all, _dismissed, role?.value);
        if (active.isEmpty) return const SizedBox.shrink();

        if (_currentIndex >= active.length) {
          _currentIndex = 0;
        }

        final broadcast = active[_currentIndex];

        if (_timer == null || !_timer!.isActive) {
          _timer = Timer.periodic(const Duration(seconds: 5), (_) {
            if (mounted && active.isNotEmpty) {
              setState(() {
                _currentIndex = (_currentIndex + 1) % active.length;
              });
            }
          });
        }

        final typeColor = _typeColor(broadcast.type);
        final typeIcon = _typeIcon(broadcast.type);

        return Container(
          width: double.infinity,
          color: typeColor.withAlpha(30),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Icon(typeIcon, size: 18, color: typeColor),
              const SizedBox(width: 8),
              Expanded(
                child: broadcast.scroll
                    ? _MarqueeText(message: broadcast.message)
                    : Text(
                        broadcast.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              if (active.length > 1) ...[
                const SizedBox(width: 8),
                Text(
                  '${_currentIndex + 1}/${active.length}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: AppTheme.slate400,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () async {
                  await dismissBroadcast(broadcast.id);
                  await _loadDismissed();
                },
                child: Icon(Icons.close, size: 16, color: AppTheme.slate400),
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

class _MarqueeTextState extends State<_MarqueeText> with SingleTickerProviderStateMixin {
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
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});
