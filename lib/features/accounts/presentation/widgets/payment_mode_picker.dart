// Fixed payment mode chip row.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/payments.dart';

class PaymentModePicker extends StatelessWidget {
  const PaymentModePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.defaultId,
  });

  final PaymentMode value;
  final ValueChanged<PaymentMode> onChanged;
  final PaymentMode? defaultId;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final mode in paymentModes)
          Material(
            color: value == mode.id ? colors.accent : colors.surfaceHover,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(mode.id);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: value == mode.id ? colors.accent : colors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      mode.icon,
                      size: 16,
                      color: value == mode.id
                          ? Colors.white
                          : colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        defaultId == mode.id
                            ? '${mode.label} · Default'
                            : mode.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: value == mode.id
                              ? Colors.white
                              : colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
