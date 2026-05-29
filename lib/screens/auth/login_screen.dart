// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'otp_verification_screen.dart';
import 'pin_login_screen.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  bool _isLoading = false;
  bool _usePinLogin = false;
  bool _hasSavedIdentifier = false;

  @override
  void initState() {
    super.initState();
    _checkSavedIdentifier();
  }

  Future<void> _checkSavedIdentifier() async {
    final hasSavedId = await ref.read(authProvider.notifier).hasSavedIdentifier();
    setState(() {
      _hasSavedIdentifier = hasSavedId;
      if (hasSavedId) {
        _usePinLogin = true;
      }
    });
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    print('🔄 [LoginScreen] Envoi OTP pour: ${_identifierController.text.trim()}');
    
    try {
      final result = await ref.read(authProvider.notifier).sendOtp(
        identifier: _identifierController.text.trim(),
      );
      
      print('📦 [LoginScreen] Résultat reçu: $result');
      
      setState(() => _isLoading = false);
      
      if (result['success'] == true) {
        print('✅ [LoginScreen] OTP envoyé, userId: ${result['userId']}');
        
        if (!mounted) return;
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              userId: result['userId'].toString(),
              identifier: _identifierController.text.trim(),
              isLogin: true,
            ),
          ),
        );
      } else {
        print('❌ [LoginScreen] Erreur: ${result['message']}');
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Erreur lors de l\'envoi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ [LoginScreen] Exception: $e');
      setState(() => _isLoading = false);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Une erreur est survenue'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B6E3A), Color(0xFF168A48)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.local_shipping, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'PRO COLIS',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Transport de colis interurbain'),
              ),
              const SizedBox(height: 48),
              
              // Switch entre OTP et PIN
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LoginMethodButton(
                    title: 'OTP',
                    isSelected: !_usePinLogin,
                    onTap: () => setState(() => _usePinLogin = false),
                  ),
                  const SizedBox(width: 16),
                  _LoginMethodButton(
                    title: 'PIN',
                    isSelected: _usePinLogin,
                    onTap: () => setState(() => _usePinLogin = true),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              if (!_usePinLogin) ...[
                // Mode OTP - Première connexion ou reconnexion avec email
                const Text(
                  'Connexion',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Entrez votre email ou numéro de téléphone',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: CustomTextField(
                    controller: _identifierController,
                    label: 'Email ou Téléphone',
                    prefixIcon: Icons.person_outline,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
                  ),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Envoyer le code OTP',
                  onPressed: _sendOtp,
                  isLoading: _isLoading,
                ),
              ] else ...[
                // Mode PIN - Connexion rapide avec PIN uniquement
                const Text(
                  'Connexion rapide',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Entrez votre code PIN à 6 chiffres',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                const PinLoginScreen(),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() => _usePinLogin = false);
                    _identifierController.clear();
                  },
                  child: const Text(
                    'Connexion avec OTP',
                    style: TextStyle(color: Color(0xFF0B6E3A)),
                  ),
                ),
              ],
              
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Pas encore de compte ? ',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterDriverScreen()),
                      );
                    },
                    child: const Text(
                      'S\'inscrire',
                      style: TextStyle(color: Color(0xFF0B6E3A)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginMethodButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _LoginMethodButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0B6E3A) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? const Color(0xFF0B6E3A) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}