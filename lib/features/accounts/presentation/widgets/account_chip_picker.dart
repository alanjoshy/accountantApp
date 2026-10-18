// Account selection chips with icon/color.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/account.dart';
import '../../domain/account_style.dart';

class AccountChipPicker extends StatelessWidget {
  const AccountChipPicker({
    super.key,
    required this.accounts,
    required this.value,
    required this.onChanged,
    this.defaultId,
    this.showBalance = true,
  });

  final List<MoneyAccount> accounts;
  final String? value;
  final ValueChanged<String> onChanged;
  final String? defaultId;
  final bool showBalance;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (accounts.isEmpty) {
      return Text(
        'No accounts yet. Add one in More → Accounts & payments.',
        style: TextStyle(fontSize: 12, color: colors.textMuted),
      );
    }

    final format = CurrencyController.instance.compact;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final account in accounts)
          Material(
            color: value == account.id ? colors.accent : colors.surfaceHover,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(account.id);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        value == account.id ? colors.accent : colors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      accountIconData(account.icon),
                      size: 16,
                      color: value == account.id
                          ? Colors.white
                          : accountColorFromHex(account.color),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        [
                          account.name,
                          if (showBalance) format(account.balance),
                          if (defaultId == account.id) 'Default',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: value == account.id
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
