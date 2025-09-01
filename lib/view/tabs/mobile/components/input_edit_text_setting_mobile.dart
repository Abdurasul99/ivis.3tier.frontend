// lib/view/tabs/mobile/components/input_edit_text_setting_mobile.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InputEditTextSetting extends StatelessWidget {
  const InputEditTextSetting({
    super.key,
    required this.controller,
    required this.title,
    required this.hintText,
    this.validator,
    this.inputFormatters,
    this.keyboardType,
    this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final String title;
  final String hintText;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          validator: validator,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, height: 1.2),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            hintText: hintText,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Color(0xFFDBDBDB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Color(0xFFDBDBDB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Color(0xFF005FB8)),
            ),
          ),
        ),
      ],
    );
  }
}
