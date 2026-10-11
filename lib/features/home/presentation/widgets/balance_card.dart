// Home account-balance card (web hero).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import 'balance_battery.dart';
import 'streak_fire_badge.dart';

class BalanceCard extends StatefulWidget {
  const BalanceCard({
    super.key,
    this.balance = 0,
    this.income = 0,
    this.expense = 0,
    this.paymentStreak = 0,
    this.batteryCapacity,
  });

  final double balance;
  final double income;
  final double expense;
  final int paymentStreak;
  final double? batteryCapacity;

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  bool _visible = false;

  static const _placeholderCapacity = 10000.0;

  String _amount(double value) {
    if (!_visible) return '•••••';
    return CurrencyController.instance.format(value);
  }

  double get _capacity {
    if (widget.batteryCapacity != null && widget.batteryCapacity! > 0) {
      return widget.batteryCapacity!;
    }
    if (widget.income > 0) return widget.income;
    return _placeholderCapacity;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final capacity = _capacity;

    return ListenableBuilder(
      listenable: CurrencyController.instance,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.border),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        colors.accent.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Account balance',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                              StreakFireBadge(streak: widget.paymentStreak),
                            ],
                          ),
                        ),
                        _IconBtn(
                          icon: _visible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          colors: colors,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _visible = !_visible);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            _amount(widget.balance),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              height: 1,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (capacity > 0) ...[
                          const SizedBox(width: 10),
                          BalanceBattery(
                            balance: widget.balance,
                            capacity: capacity,
                            amountsVisible: _visible,
                            formatAmount: CurrencyController.instance.format,
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _FlowTile(
                            label: 'Income',
                            amount: _amount(widget.income),
                            icon: Icons.trending_up_rounded,
                            iconColor: colors.success,
                            colors: colors,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _FlowTile(
                            label: 'Expense',
                            amount: _amount(widget.expense),
                            icon: Icons.trending_down_rounded,
                            iconColor: colors.error,
                            colors: colors,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FlowTile extends StatelessWidget {
  const _FlowTile({
    required this.label,
    required this.amount,
    required this.icon,
    required this.iconColor,
    required this.colors,
  });

  final String label;
  final String amount;
  final IconData icon;
  final Color iconColor;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: iconColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              amount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.15,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final AppPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surfaceHover,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16, color: colors.textSecondary),
        ),
      ),
    );
  }
}
