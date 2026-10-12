// Shared create / edit jar form fields.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

const jarAccentOptions = <String>[
  '#22c55e',
  '#3b82f6',
  '#14b8a6',
  '#eab308',
  '#f97316',
  '#38bdf8',
];

Color jarColorFromHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  return Color(int.parse('FF$cleaned', radix: 16));
}

class JarFormSheet extends StatelessWidget {
  const JarFormSheet({
    super.key,
    required this.nameController,
    required this.targetController,
    required this.currentController,
    required this.color,
    required this.onColorChanged,
    required this.onSubmit,
    required this.submitLabel,
    required this.saving,
    this.error,
  });

  final TextEditingController nameController;
  final TextEditingController targetController;
  final TextEditingController currentController;
  final String color;
  final ValueChanged<String> onColorChanged;
  final VoidCallback onSubmit;
  final String submitLabel;
  final bool saving;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        8,
        AppSpacing.md,
        AppSpacing.md + bottomInset,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _FieldLabel('Name', colors),
            TextField(
              controller: nameController,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                colors,
                hint: 'e.g. Emergency fund',
              ),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Target', colors),
            TextField(
              controller: targetController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: _inputDecoration(colors, hint: '0'),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Already saved', colors),
            TextField(
              controller: currentController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: _inputDecoration(colors, hint: '0'),
            ),
            const SizedBox(height: 14),
            _FieldLabel('Label color', colors),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in jarAccentOptions)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onColorChanged(c);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: jarColorFromHex(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == c
                              ? colors.textPrimary
                              : colors.border,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Jar fill matches this label color.',
              style: TextStyle(fontSize: 10, color: colors.textMuted),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: saving ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                saving ? 'Saving…' : submitLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (error != null && error!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(AppPalette colors, {required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: colors.surfaceHover,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.accent),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, this.colors);

  final String text;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}
