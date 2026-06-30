// lib/screens/auth/otp_verification_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';
import '../dashboard/dashboard_screen.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String userId;
  final String identifier;
  final bool isLogin;
  
  const OtpVerificationScreen({
    super.key,
    required this.userId,
    required this.identifier,
    this.isLogin = true,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  Timer? _timer;
  int _remainingSeconds = 60;
  bool _canResend = false;
  bool _isVerifying = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
    debugPrint('🔐 OTP Screen initialisé');
    debugPrint('   UserId: ${widget.userId}');
    debugPrint('   Identifier: ${widget.identifier}');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _remainingSeconds = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      }
    });
  }

  Future<void> _verifyOtp() async {
    final code = _codeController.text.trim();
    
    if (code.length != 6) {
      setState(() => _errorMessage = 'Veuillez entrer le code à 6 chiffres');
      return;
    }
    
    setState(() {
      _isVerifying = true;
      _errorMessage = '';
    });
    
    debugPrint('🔐 Vérification OTP');
    debugPrint('   Code: $code');
    debugPrint('   UserId: ${widget.userId}');
    
    try {
      final result = await ref.read(authProvider.notifier).verifyOtp(
        userId: widget.userId,
        code: code,
        type: 'login',
        identifier: widget.identifier,
      );
      
      debugPrint('📦 Résultat vérification: $result');
      
      setState(() => _isVerifying = false);
      
      if (result['success'] == true) {
        debugPrint('✅ Connexion réussie !');
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Connexion réussie !'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (!mounted) return;
        
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false,
        );
      } else {
        setState(() => _errorMessage = result['message'] ?? 'Code invalide');
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Code invalide'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Exception lors de la vérification: $e');
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Une erreur est survenue';
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Une erreur est survenue'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;
    
    setState(() {
      _isVerifying = true;
      _errorMessage = '';
    });
    
    debugPrint('🔄 Renvoi OTP pour: ${widget.identifier}');
    
    try {
      final result = await ref.read(authProvider.notifier).sendOtp(
        identifier: widget.identifier,
      );
      
      debugPrint('📦 Résultat renvoi: $result');
      
      setState(() => _isVerifying = false);
      
      if (result['success'] == true) {
        _startTimer();
        _codeController.clear();
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Nouveau code envoyé !'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        setState(() => _errorMessage = result['message'] ?? 'Erreur lors du renvoi');
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Erreur lors du renvoi'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Exception lors du renvoi: $e');
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Une erreur est survenue';
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Une erreur est survenue'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 24),
            const SizedBox(width: 8),
            const Text(
              'PRO COLIS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.cardColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              
              // Logo avec animation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const AppLogo(size: 80),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Vérification du code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                'Un code de vérification a été envoyé à',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.identifier,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 32),
              
              // Input OTP avec PinCodeFields
              PinCodeTextField(
                appContext: context,
                controller: _codeController,
                length: 6,
                keyboardType: TextInputType.number,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(12),
                  fieldHeight: 60,
                  fieldWidth: 50,
                  inactiveColor: AppTheme.textSecondary.withValues(alpha: 0.3),
                  inactiveFillColor: AppTheme.cardColor,
                  activeColor: AppTheme.primaryBlue,
                  activeFillColor: AppTheme.cardColor,
                  selectedColor: AppTheme.primaryBlue,
                  selectedFillColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                ),
                enableActiveFill: true,
                onChanged: (value) {
                  setState(() {
                    _errorMessage = '';
                  });
                },
                onCompleted: (value) {
                  _verifyOtp();
                },
              ),
              
              // Message d'erreur
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.errorColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 20,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 32),
              
              // Bouton Vérifier
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.textSecondary.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Vérifier',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Timer / Resend
              if (!_canResend)
                Column(
                  children: [
                    Text(
                      'Code expiré dans',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer,
                            size: 20,
                            color: AppTheme.primaryBlue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    const Text(
                      'Vous n\'avez pas reçu le code ?',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _resendOtp,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryBlue,
                      ),
                      child: const Text(
                        'Renvoyer le code',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              
              const SizedBox(height: 24),
              
              // Indicateur de sécurité
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 16,
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Connexion sécurisée',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
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