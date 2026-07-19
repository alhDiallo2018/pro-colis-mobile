import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';

class ParcelMedia extends StatelessWidget {
  final List<String>? photoUrls;
  final List<String>? videoUrls;
  final List<String>? audioUrls;
  final double thumbnailSize;
  final bool showAudioPlayer;

  const ParcelMedia({
    super.key,
    this.photoUrls,
    this.videoUrls,
    this.audioUrls,
    this.thumbnailSize = 96,
    this.showAudioPlayer = true,
  });

  factory ParcelMedia.fromMap(Map<String, dynamic> data, {double thumbnailSize = 96}) {
    return ParcelMedia(
      thumbnailSize: thumbnailSize,
      photoUrls: (data['photoUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      videoUrls: (data['videoUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      audioUrls: (data['audioUrls'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }

  bool get hasMedia {
    final p = photoUrls?.where((u) => u.isNotEmpty).toList() ?? [];
    final v = videoUrls?.where((u) => u.isNotEmpty).toList() ?? [];
    final a = audioUrls?.where((u) => u.isNotEmpty).toList() ?? [];
    return p.isNotEmpty || v.isNotEmpty || a.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (!hasMedia) return const SizedBox.shrink();

    final photos = photoUrls?.where((u) => u.isNotEmpty).toList() ?? [];
    final videos = videoUrls?.where((u) => u.isNotEmpty).toList() ?? [];
    final audios = audioUrls?.where((u) => u.isNotEmpty).toList() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isNotEmpty || videos.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...photos.map((url) => _PhotoThumbnail(url: url, size: thumbnailSize)),
              ...videos.map((url) => _VideoThumbnail(url: url, size: thumbnailSize)),
            ],
          ),
        if (audios.isNotEmpty && showAudioPlayer) ...[
          if (photos.isNotEmpty || videos.isNotEmpty) const SizedBox(height: 10),
          ...audios.map((url) => _AudioPlayerWidget(url: url)),
        ],
      ],
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final String url;
  final double size;

  const _PhotoThumbnail({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreen(context, url),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.slate200),
          color: AppTheme.slate100,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd - 1),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: AppTheme.slate400, size: 32),
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoThumbnail extends StatefulWidget {
  final String url;
  final double size;

  const _VideoThumbnail({required this.url, required this.size});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  bool _showPlayer = false;

  @override
  Widget build(BuildContext context) {
    if (_showPlayer) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          color: Colors.black,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.videocam, size: 32, color: Colors.white70),
            Positioned(
              bottom: 4,
              right: 4,
              child: IconButton(
                onPressed: () => setState(() => _showPlayer = false),
                icon: const Icon(Icons.close, size: 18, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _showPlayer = true),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.slate200),
          color: Colors.black,
        ),
        child: const Icon(Icons.play_circle_fill, size: 36, color: Colors.white70),
      ),
    );
  }
}

class _AudioPlayerWidget extends StatefulWidget {
  final String url;

  const _AudioPlayerWidget({required this.url});

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.slate100,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() => _isPlaying = !_isPlaying);
              },
              icon: Icon(
                _isPlaying ? Icons.stop : Icons.play_arrow,
                color: AppTheme.primary,
                size: 22,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Note vocale',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
            Icon(Icons.mic, size: 14, color: AppTheme.slate400),
          ],
        ),
      ),
    );
  }
}
