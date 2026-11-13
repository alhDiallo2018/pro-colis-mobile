import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../services/api/ai_api.dart';
import '../../services/api/client.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pc_components.dart';

/// Écran minimal V1 de l'assistant conversationnel. Chat vertical simple :
/// l'utilisateur tape ou dicte une phrase, l'assistant renvoie un `answerText`
/// et, si l'intention est `create_parcel`, propose un bouton d'action pour
/// pré-remplir `new_parcel_wizard_screen`.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(
      fromUser: false,
      text:
          'Bonjour 👋 Je suis l\'assistant SendProColis. Décrivez ce que vous voulez envoyer : par exemple « Envoie un carton 5 kg de Dakar à Thiès demain ».',
    ),
  ];
  AiAssistantResult? _lastResult;
  bool _sending = false;
  bool _recording = false;
  bool _transcribing = false;
  String? _voiceError;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  AudioRecorder? _recorder;
  String? _recordPath;
  late final AiAssistantApi _api;

  @override
  void initState() {
    super.initState();
    _api = AiAssistantApi(ApiClient());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _recordingTimer?.cancel();
    _recorder?.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(_ChatMessage(fromUser: true, text: text));
      _sending = true;
    });
    _controller.clear();
    _scrollToEnd();
    final result = await _api.ask(message: text);
    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(fromUser: false, text: result.answerText));
      _lastResult = result;
      _sending = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onUseDraft() {
    final draft = _lastResult?.draft;
    if (draft != null) Navigator.of(context).pop(draft);
  }

  Future<void> _startRecording() async {
    if (_recording || _transcribing || _sending) return;
    _voiceError = null;
    try {
      _recorder ??= AudioRecorder();
      if (!await _recorder!.hasPermission()) {
        if (mounted) {
          setState(() => _voiceError =
              AppLocalizations.of(context).aiAssistantVoicePermission);
        }
        return;
      }
      final name = 'ai_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      _recordPath = kIsWeb ? name : '${Directory.systemTemp.path}/$name';
      await _recorder!.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 44100),
        path: _recordPath!,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordingSeconds = 0;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingSeconds++);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _voiceError =
          AppLocalizations.of(context).aiAssistantVoiceUnavailable);
    }
  }

  Future<void> _stopRecording() async {
    if (!_recording) return;
    _recordingTimer?.cancel();
    final path = await _recorder?.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _transcribing = true;
    });
    if (path == null) {
      setState(() {
        _transcribing = false;
        _voiceError =
            AppLocalizations.of(context).aiAssistantVoiceUnavailable;
      });
      return;
    }
    try {
      final file = XFile(path);
      final uploadedUrl =
          await ApiService().uploadFile(file: file, mediaType: 'audio');
      if (uploadedUrl == null) {
        if (!mounted) return;
        setState(() {
          _transcribing = false;
          _voiceError =
              AppLocalizations.of(context).aiAssistantVoiceUnavailable;
        });
        return;
      }
      final transcript = await _api.transcribe(audioUrl: uploadedUrl);
      if (!mounted) return;
      setState(() {
        _transcribing = false;
        if (transcript != null) {
          _controller.text = transcript;
        } else {
          _voiceError =
              AppLocalizations.of(context).aiAssistantVoiceUnavailable;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _transcribing = false;
        _voiceError =
            AppLocalizations.of(context).aiAssistantVoiceUnavailable;
      });
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final showDraftAction = _lastResult?.isCreateParcel == true;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.aiAssistantTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _ChatBubble(message: _messages[i]),
              ),
            ),
            if (_voiceError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  _voiceError!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error, fontSize: 12),
                ),
              ),
            if (showDraftAction)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PcButton(
                  l.aiAssistantFillForm,
                  onPressed: _onUseDraft,
                  icon: Icons.auto_awesome_rounded,
                  block: true,
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                border: Border(
                  top: BorderSide(color: AppTheme.slate300.withValues(alpha: 0.4)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: _recording
                        ? l.aiAssistantVoiceStop
                        : l.aiAssistantVoiceRecord,
                    onPressed: _sending || _transcribing
                        ? null
                        : (_recording ? _stopRecording : _startRecording),
                    icon: _transcribing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_recording
                            ? Icons.stop_circle_rounded
                            : Icons.mic_rounded),
                    color: _recording ? AppTheme.red500 : null,
                  ),
                  Expanded(
                    child: _recording
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.red50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              Icon(Icons.fiber_manual_record,
                                  size: 12, color: AppTheme.red500),
                              const SizedBox(width: 8),
                              Text(
                                '${l.aiAssistantVoiceRecording} ${_formatDuration(_recordingSeconds)}',
                                style: TextStyle(
                                    color: AppTheme.red500,
                                    fontWeight: FontWeight.w700),
                              ),
                            ]),
                          )
                        : TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 4,
                            enabled: !_sending && !_transcribing,
                            decoration: InputDecoration(
                              hintText: _transcribing
                                  ? l.aiAssistantVoiceTranscribing
                                  : l.aiAssistantHint,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Envoyer',
                    onPressed: _sending || _recording || _transcribing
                        ? null
                        : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final bool fromUser;
  final String text;
  const _ChatMessage({required this.fromUser, required this.text});
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final align = message.fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = message.fromUser ? AppTheme.primary : AppTheme.cardColor;
    final fg = message.fromUser ? Colors.white : null;
    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: message.fromUser
                  ? null
                  : Border.all(color: AppTheme.slate300.withValues(alpha: 0.4)),
            ),
            child: Text(message.text, style: TextStyle(color: fg)),
          ),
        ),
      ),
    );
  }
}
