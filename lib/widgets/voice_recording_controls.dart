import 'package:flutter/material.dart';
import 'package:record/record.dart';

/// Contrôles partagés : une pause conserve la prise native et son fichier.
class VoiceRecordingControls extends StatefulWidget {
  final AudioRecorder recorder;
  final int seconds;
  final bool paused;
  final ValueChanged<bool> onPausedChanged;
  final ValueChanged<bool> onBusyChanged;
  final Future<void> Function() onFinish;

  const VoiceRecordingControls({
    super.key,
    required this.recorder,
    required this.seconds,
    required this.paused,
    required this.onPausedChanged,
    required this.onBusyChanged,
    required this.onFinish,
  });

  @override
  State<VoiceRecordingControls> createState() => _VoiceRecordingControlsState();
}

class _VoiceRecordingControlsState extends State<VoiceRecordingControls> {
  bool _busy = false;
  String? _error;

  Future<void> _act({bool finish = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final notifyBusy = widget.onBusyChanged;
    notifyBusy(true);
    try {
      // Sérialiser pause, reprise et arrêt évite deux commandes natives rivales.
      // Ne modifier le compteur parent qu'après confirmation du microphone.
      if (finish) {
        await widget.onFinish();
      } else {
        final paused = !widget.paused;
        if (paused) {
          await widget.recorder.pause();
        } else {
          await widget.recorder.resume();
        }
        if (mounted) widget.onPausedChanged(paused);
      }
    } catch (error, stackTrace) {
      debugPrint('[VoiceRecording] Commande audio impossible : $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _error = 'Action impossible. Réessayez.');
    } finally {
      // Terminer peut retirer ce widget : le parent doit quand même être libéré.
      notifyBusy(false);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = '${(widget.seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(widget.seconds % 60).toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${widget.paused ? 'En pause' : 'Enregistrement'} · $duration'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _act(),
              icon: Icon(widget.paused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded),
              label: Text(widget.paused ? 'Reprendre' : 'Pause'),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : () => _act(finish: true),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Terminer'),
            ),
          ],
        ),
        if (_error != null)
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    );
  }
}
