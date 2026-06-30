import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../dashboard/dashboard_screen.dart';
import 'otp_verification_screen.dart';

class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  final List<String> _pinDigits = List.filled(6, '');
  final List<FocusNode> _focusNodes = List.generate(6, (i) => FocusNode());
  final List<TextEditingController> _controllers = List.generate(6, (i) => TextEditingController());
  bool _isLoading = false;
  bool _showPinError = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _pin => _pinDigits.join();

  void _onPinChanged(int index, String value) {
    setState(() {
      _pinDigits[index] = value;
      if (value.isNotEmpty && index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else if (value.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    });
    _showPinError = false;
    
    if (_pin.length == 6) {
      _verifyPin();
    }
  }

  Future<void> _verifyPin() async {
    if (_pin.length != 6) return;
    
    setState(() => _isLoading = true);
    
    // Appel du notifier
    final result = await ref.read(authProvider.notifier).loginWithSavedPin(_pin);
    
    if (!mounted) return;
    setState(() => _isLoading = false);
    
    if (result['success'] == true) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } else {
      setState(() {
        _showPinError = true;
        for (var i = 0; i < 6; i++) {
          _controllers[i].clear();
          _pinDigits[i] = '';
        }
      });
      if (_focusNodes.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'PIN incorrect'), 
          backgroundColor: Colors.red
        ),
      );
    }
  }

  Future<void> _forgotPin() async {
    final savedIdentifier = await ref.read(authProvider.notifier).getSavedIdentifier();
    
    if (!mounted) return;
    
    if (savedIdentifier == null || savedIdentifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun compte trouvé. Veuillez vous connecter avec OTP.')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    final result = await ref.read(authProvider.notifier).sendOtp(
      identifier: savedIdentifier,
    );
    
    if (!mounted) return;
    setState(() => _isLoading = false);
    
    if (result['success'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            userId: result['userId'],
            identifier: savedIdentifier,
            isLogin: true,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Erreur'), 
          backgroundColor: Colors.red
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) => SizedBox(
            width: 50,
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              obscureText: true,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _showPinError ? Colors.red : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _showPinError ? Colors.red : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0B6E3A), width: 2),
                ),
              ),
              onChanged: (value) => _onPinChanged(index, value),
            ),
          )),
        ),
        const SizedBox(height: 32),
        if (_isLoading)
          const CircularProgressIndicator()
        else
          Column(
            children: [
              CustomButton(
                text: 'Se connecter',
                // ✅ CORRECTION DU TYPE : Une fonction anonyme qui s'exécute ou ne fait rien si la condition n'est pas remplie
                onPressed: () {
                  if (_pin.length == 6) {
                    _verifyPin();
                  }
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _forgotPin,
                child: const Text(
                  'Mot de passe oublié ?',
                  style: TextStyle(color: Color(0xFF0B6E3A)),
                ),
              ),
            ],
          ),
      ],
    );
  }
}