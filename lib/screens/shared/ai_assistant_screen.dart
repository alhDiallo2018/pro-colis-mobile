import 'package:flutter/material.dart';

import '../../services/api/ai_api.dart';
import '../../services/api/client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pc_components.dart';

/// Écran minimal V1 de l'assistant conversationnel. Chat vertical simple :
/// l'utilisateur tape une phrase, l'assistant renvoie un `answerText` et,
/// si l'intention est `create_parcel`, propose un bouton d'action qui
/// sera rebranché dans une étape ultérieure vers `create_colis_sheet`
/// pré-rempli avec le draft.
///
/// Déjà prêt à être poussé derrière un FAB dans `new_parcel_wizard_screen`.
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
    // Point d'extension : rebrancher vers `create_colis_sheet` pré-rempli.
    // Pour V1, on remonte un draft dans le parent via Navigator.pop afin que
    // l'appelant (future intégration dans new_parcel_wizard_screen) puisse
    // ouvrir le formulaire pré-rempli. Jamais de création automatique.
    final draft = _lastResult?.draft;
    if (draft != null) Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    final showDraftAction = _lastResult?.isCreateParcel == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant'),
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
            if (showDraftAction)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: PcButton(
                  'Remplir le formulaire avec ces infos',
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
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !_sending,
                      decoration: const InputDecoration(
                        hintText: 'Décrivez votre expédition…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
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
