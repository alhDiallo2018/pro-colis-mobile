import 'package:flutter/material.dart';
import 'messages_screen.dart';

const String supportUserId = String.fromEnvironment(
  'SUPPORT_USER_ID',
  defaultValue: 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
);
const String supportUserName = String.fromEnvironment(
  'SUPPORT_USER_NAME',
  defaultValue: 'Support SENDPROCOLIS',
);

/// Écran de chat support - réutilise MessagesScreen avec le peer support.
/// NE PAS emballer dans un Scaffold car MessagesScreen a le sien.
class SupportChatScreen extends StatelessWidget {
  const SupportChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MessagesScreen(
      initialPeerId: supportUserId,
      initialPeerName: supportUserName,
    );
  }
}
