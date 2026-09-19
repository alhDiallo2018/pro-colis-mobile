import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Note vocale optionnelle : seule l'URL téléversée entre dans le formulaire.
/// Le fichier local reste disponible après un échec réseau pour réessayer.
class VoiceNoteField extends StatefulWidget {
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  final ValueChanged<bool> onBusyChanged;
  final AudioRecorder? recorder;
  final AudioPlayer? player;
  final Future<String?> Function(XFile)? upload;

  const VoiceNoteField({
    super.key,
    this.value,
    this.enabled = true,
    required this.onChanged,
    required this.onBusyChanged,
    this.recorder,
    this.player,
    this.upload,
  });

  @override
  State<VoiceNoteField> createState() => _VoiceNoteFieldState();
}

class _VoiceNoteFieldState extends State<VoiceNoteField> {
  AudioRecorder? _recorder;
  AudioPlayer? _player;
  StreamSubscription<void>? _completion;
  Timer? _timer;
  String? _localPath;
  String? _error;
  bool _recording = false;
  bool _paused = false;
  bool _working = false;
  bool _playing = false;
  int _seconds = 0;

  AudioRecorder get _audioRecorder =>
      _recorder ??= widget.recorder ?? AudioRecorder();

  AudioPlayer get _audioPlayer {
    if (_player == null) {
      _player = widget.player ?? AudioPlayer();
      _completion = _player!.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playing = false);
      });
    }
    return _player!;
  }

  void _notifyBusy() =>
      widget.onBusyChanged(_working || _recording || _localPath != null);

  void _reportError(String message, Object error, StackTrace stackTrace) {
    debugPrint('[VoiceNote] $message : $error');
    debugPrintStack(stackTrace: stackTrace);
    if (mounted) setState(() => _error = message);
  }

  Future<void> _start() async {
    if (_working || !widget.enabled) return;
    setState(() {
      _working = true;
      _error = null;
    });
    _notifyBusy();
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (mounted)
          setState(() => _error =
              'Autorisez le microphone dans les réglages pour enregistrer une note vocale.');
        return;
      }
      if (!mounted) return;
      final name = 'voyage_${DateTime.now().microsecondsSinceEpoch}.m4a';
      _localPath = kIsWeb ? name : '${Directory.systemTemp.path}/$name';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100),
        path: _localPath!,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _paused = false;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && !_paused) setState(() => _seconds++);
      });
    } catch (error, stackTrace) {
      await _deleteLocalFile();
      _reportError('Enregistrement impossible.', error, stackTrace);
    } finally {
      if (mounted) {
        setState(() => _working = false);
        _notifyBusy();
      }
    }
  }

  Future<void> _togglePause() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      if (_paused) {
        await _audioRecorder.resume();
      } else {
        await _audioRecorder.pause();
      }
      if (mounted) setState(() => _paused = !_paused);
    } catch (error, stackTrace) {
      _reportError('Impossible de modifier la pause.', error, stackTrace);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _stopAndUpload() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    _notifyBusy();
    try {
      if (_recording) {
        final path = await _audioRecorder.stop();
        _timer?.cancel();
        if (!mounted) return;
        setState(() {
          _recording = false;
          _paused = false;
        });
        if (path == null || path.isEmpty) {
          await _deleteLocalFile();
          throw StateError('Aucun fichier audio enregistré');
        }
        _localPath = path;
      }
      final path = _localPath;
      if (path == null) return;
      final upload = widget.upload ?? ApiService().uploadChatAudio;
      final url = await upload(XFile(path, name: 'note-vocale.m4a'));
      if (url == null || url.trim().isEmpty) {
        throw StateError('Le téléversement audio a échoué');
      }
      if (!mounted) return;
      widget.onChanged(url);
      await _deleteLocalFile();
    } catch (error, stackTrace) {
      _reportError(
          'Impossible d’ajouter la note vocale. Réessayez.', error, stackTrace);
    } finally {
      if (mounted) {
        setState(() => _working = false);
        _notifyBusy();
      }
    }
  }

  Future<void> _remove() async {
    if (_working) return;
    setState(() => _working = true);
    _notifyBusy();
    try {
      if (_recording) await _audioRecorder.cancel();
      _timer?.cancel();
      await _player?.stop();
      await _deleteLocalFile();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _paused = false;
        _playing = false;
        _error = null;
      });
      widget.onChanged(null);
    } catch (error, stackTrace) {
      _reportError(
          'Impossible de supprimer la note vocale.', error, stackTrace);
    } finally {
      if (mounted) {
        setState(() => _working = false);
        _notifyBusy();
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_working || widget.value == null) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      if (_playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer
            .play(UrlSource(ApiService.resolveMediaUrl(widget.value!)));
      }
      if (mounted) setState(() => _playing = !_playing);
    } catch (error, stackTrace) {
      _reportError('Lecture audio impossible.', error, stackTrace);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deleteLocalFile() async {
    final path = _localPath;
    _localPath = null;
    if (path == null || kIsWeb) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (error, stackTrace) {
      // Un nettoyage du cache raté ne doit pas invalider un upload réussi.
      debugPrint('[VoiceNote] Nettoyage audio impossible : $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _completion?.cancel();
    unawaited(_releaseAudio());
    super.dispose();
  }

  Future<void> _releaseAudio() async {
    // Libère le microphone même si le formulaire est fermé par son parent.
    try {
      await _recorder?.dispose();
      await _player?.dispose();
    } catch (error, stackTrace) {
      debugPrint('[VoiceNote] Libération audio impossible : $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      await _deleteLocalFile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = !widget.enabled || _working;
    final hasVoice = widget.value?.isNotEmpty == true;
    final duration = '${(_seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(_seconds % 60).toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_working && !_recording) const LinearProgressIndicator(),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (_recording) ...[
              Text('${_paused ? 'En pause' : 'Enregistrement'} · $duration'),
              TextButton.icon(
                onPressed: disabled ? null : _togglePause,
                icon: Icon(
                    _paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                label: Text(_paused ? 'Reprendre' : 'Pause'),
              ),
              TextButton.icon(
                onPressed: disabled ? null : _stopAndUpload,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Terminer'),
              ),
            ] else if (_localPath != null) ...[
              const Text('Note vocale en attente d’envoi'),
              TextButton(
                  onPressed: disabled ? null : _stopAndUpload,
                  child: const Text('Réessayer')),
            ] else if (hasVoice) ...[
              const Text('Note vocale enregistrée'),
              TextButton.icon(
                onPressed: disabled ? null : _togglePlayback,
                icon: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(_playing ? 'Pause' : 'Écouter'),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: disabled ? null : _start,
                icon: const Icon(Icons.mic_rounded),
                label: const Text('Enregistrer une note vocale'),
              ),
            if (_recording || _localPath != null || hasVoice)
              IconButton(
                tooltip: 'Supprimer la note vocale',
                onPressed: disabled ? null : _remove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        if (_error != null)
          Text(_error!, style: TextStyle(color: AppTheme.error)),
      ],
    );
  }
}
