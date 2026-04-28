import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../viewmodel/controller/locale_controller.dart';

class AppLanguageToggle extends StatelessWidget {
  final bool compact;

  const AppLanguageToggle({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LocaleController>(
      init: Get.find<LocaleController>(),
      builder: (LocaleController controller) {
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _LanguageChip(
                label: '한국어',
                selected: controller.isKorean,
                compact: compact,
                onTap: () => controller.setLocale(LocaleController.korean),
              ),
              _LanguageChip(
                label: 'English',
                selected: controller.isEnglish,
                compact: compact,
                onTap: () => controller.setLocale(LocaleController.english),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 7,
        ),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF005CB2) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'pretendard',
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }
}
