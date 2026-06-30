import 'package:flutter/material.dart';

class PinCodeField extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onCompleted;

  const PinCodeField({
    super.key,
    required this.controller,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      style: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: 12,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '●  ●  ●  ●  ●  ●',
        hintStyle: TextStyle(
          fontSize: 32,
          letterSpacing: 12,
          color: Colors.grey.shade300,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      onChanged: (value) {
        if (value.length == 6) {
          onCompleted(value);
        }
      },
    );
  }
}
