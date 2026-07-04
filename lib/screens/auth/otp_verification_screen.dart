// Fichier mort - flux OTP supprimé (aligné Web)
import 'package:flutter/material.dart';
class OtpVerificationScreen extends StatelessWidget {
  final String userId;
  final String identifier;
  final bool isLogin;
  const OtpVerificationScreen({super.key, required this.userId, required this.identifier, this.isLogin = false});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Redirection...')));
}
