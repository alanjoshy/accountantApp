// Settings — Theme, Currency, and add-transaction defaults.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/app_currency.dart';
import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/theme_controller.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../accounts/data/account_store.dart';
import '../../../accounts/domain/payments.dart';
import '../../../accounts/presentation/widgets/account_chip_picker.dart';
import '../../../accounts/presentation/widgets/payment_mode_picker.dart';
import '../../../auth/data/app_lock_store.dart';
import '../../../auth/domain/app_session.dart';
import '../../../auth/domain/biometric_auth.dart';
import '../../../auth/domain/sensitive_access_session.dart';
import '../../../auth/presentation/widgets/pin_setup_sheet.dart';
import '../../../auth/presentation/widgets/unlock_sheet.dart';
import '../../../reminders/data/notification_service.dart';
import '../../../reminders/domain/reminder_sync.dart';
import '../../../settings/data/app_settings.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../../settings/presentation/widgets/cycle_start_day_editor.dart';
import '../../../transactions/domain/tag_label.dart';
import '../../../transactions/domain/transaction_categories.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.of(context).pop();
                        },
                        icon: Icon(
                          Icons.chevron_left_rounded,
                          size: 20,
                          color: colors.accent,
                        ),
                        label: Text(
                          'More',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.accent,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: colors.accent,
                        ),
                      ),
                    ),
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionLabel('General', colors),
                    const SizedBox(height: 6),
                    _SettingsPanel(
                      colors: colors,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final control = ListenableBuilder(
                              listenable: ThemeController.instance,
                              builder: (context, _) {
                                return _ThemeSegmented(
                                  value: ThemeController.instance.mode,
                                  colors: colors,
                                  onChanged: (mode) async {
                                    if (mode ==
                                        ThemeController.instance.mode) {
                                      return;
                                    }
                                    HapticFeedback.selectionClick();
                                    await ThemeController.instance
                                        .setMode(mode);
                                    if (!context.mounted) return;
                                    AppToast.success(context, 'Theme saved.');
                                  },
                                );
                              },
                            );
                            final label = Text(
                              'Theme',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: colors.textPrimary,
                              ),
                            );

                            if (constraints.maxWidth < 340) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  label,
                                  const SizedBox(height: 10),
                                  control,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: label),
                                Flexible(child: control),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionLabel('Security', colors),
                    const SizedBox(height: 4),
                    Text(
                      'PIN, biometrics, and hiding account balances.',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    const _SecuritySection(),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionLabel('Reminders', colors),
                    const SizedBox(height: 4),
                    Text(
                      'Local notifications and Things to remember tips.',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    const _RemindersSection(),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionLabel('Currency', colors),
                    const SizedBox(height: 4),
                    Text(
                      'Used as the money icon across the app.',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    ListenableBuilder(
                      listenable: CurrencyController.instance,
                      builder: (context, _) {
                        final selected = CurrencyController.instance.currency;
                        return _SettingsPanel(
                          colors: colors,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: _CurrencyDropdown(
                              key: const ValueKey('currency-dropdown'),
                              value: selected,
                              colors: colors,
                              onChanged: (value) async {
                                if (value == selected) return;
                                HapticFeedback.selectionClick();
                                await CurrencyController.instance
                                    .setCurrency(value);
                                if (!context.mounted) return;
                                AppToast.success(context, 'Currency saved.');
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionLabel('Pay cycle', colors),
                    const SizedBox(height: 4),
                    Text(
                      'Salary or billing month start — used on Home, Budgets, and Activity.',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    _SettingsPanel(
                      colors: colors,
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: CycleStartDayEditor(showTitle: false),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionLabel('When adding', colors),
                    const SizedBox(height: 4),
                    Text(
                      'Defaults for the dock + add sheet.',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        AppSettingsStore.instance,
                        AccountStore.instance,
                        CurrencyController.instance,
                      ]),
                      builder: (context, _) {
                        final store = AppSettingsStore.instance;
                        final accounts = AccountStore.instance.accounts;
                        final symbol = CurrencyController.instance.symbol;
                        return _SettingsPanel(
                          colors: colors,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Default date',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    if (store.defaultDateMode ==
                                            DefaultDateMode.remember &&
                                        store.lastTransactionDate != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Last · ${store.lastTransactionDate}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors.textMuted,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    _DateModeSegmented(
                                      value: store.defaultDateMode,
                                      colors: colors,
                                      onChanged: (mode) async {
                                        if (mode == store.defaultDateMode) {
                                          return;
                                        }
                                        HapticFeedback.selectionClick();
                                        await store.setDefaultDateMode(mode);
                                        if (!context.mounted) return;
                                        AppToast.success(
                                          context,
                                          'Default date saved.',
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: colors.border),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Default category',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        for (final c in spendCategories)
                                          _ChoiceChip(
                                            label: c,
                                            selected:
                                                store.defaultCategory == c,
                                            colors: colors,
                                            onTap: () async {
                                              if (store.defaultCategory == c) {
                                                return;
                                              }
                                              HapticFeedback.selectionClick();
                                              await store.setDefaultCategory(c);
                                              if (!context.mounted) return;
                                              AppToast.success(
                                                context,
                                                'Default category · $c',
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: colors.border),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Default tag',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        _ChoiceChip(
                                          label: 'None',
                                          selected: store.defaultTag == null,
                                          colors: colors,
                                          onTap: () async {
                                            if (store.defaultTag == null) {
                                              return;
                                            }
                                            HapticFeedback.selectionClick();
                                            await store.setDefaultTag(null);
                                            if (!context.mounted) return;
                                            AppToast.success(
                                              context,
                                              'Default tag cleared.',
                                            );
                                          },
                                        ),
                                        for (final tag in store.tags)
                                          _ChoiceChip(
                                            label: formatTagLabel(tag),
                                            selected: store.defaultTag == tag,
                                            colors: colors,
                                            onTap: () async {
                                              if (store.defaultTag == tag) {
                                                return;
                                              }
                                              HapticFeedback.selectionClick();
                                              await store.setDefaultTag(tag);
                                              if (!context.mounted) return;
                                              AppToast.success(
                                                context,
                                                'Default tag · ${formatTagLabel(tag)}',
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                    if (store.tags.isEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Add tags in More → Tags to pick a default.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: colors.border),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Default debit account',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Used when adding spends and income.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (accounts.isEmpty)
                                      Text(
                                        'Add accounts in More → Accounts & payments.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors.textMuted,
                                        ),
                                      )
                                    else
                                      AccountChipPicker(
                                        accounts: accounts,
                                        value: store.defaultAccountId,
                                        defaultId: store.defaultAccountId,
                                        showBalance: false,
                                        onChanged: (id) async {
                                          if (store.defaultAccountId == id) {
                                            return;
                                          }
                                          HapticFeedback.selectionClick();
                                          await store.setDefaultAccountId(id);
                                          if (!context.mounted) return;
                                          final name = AccountStore.instance
                                                  .byId(id)
                                                  ?.name ??
                                              'Account';
                                          AppToast.success(
                                            context,
                                            'Default account · $name',
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: colors.border),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Default payment mode',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    PaymentModePicker(
                                      value: store.defaultPaymentMode,
                                      defaultId: store.defaultPaymentMode,
                                      onChanged: (mode) async {
                                        if (store.defaultPaymentMode == mode) {
                                          return;
                                        }
                                        HapticFeedback.selectionClick();
                                        await store.setDefaultPaymentMode(mode);
                                        if (!context.mounted) return;
                                        AppToast.success(
                                          context,
                                          'Default payment · ${paymentModeLabel(mode)}',
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: colors.border),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Low balance alerts',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: colors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Show a tip on Home when an account is at or below this amount.',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: colors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Switch.adaptive(
                                          value: store.lowBalanceEnabled,
                                          onChanged: (v) async {
                                            HapticFeedback.selectionClick();
                                            await store.setLowBalanceEnabled(v);
                                          },
                                        ),
                                      ],
                                    ),
                                    if (store.lowBalanceEnabled) ...[
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        key: ValueKey(
                                          'low-balance-${store.lowBalanceThreshold}',
                                        ),
                                        initialValue: store.lowBalanceThreshold ==
                                                store.lowBalanceThreshold
                                                    .roundToDouble()
                                            ? store.lowBalanceThreshold
                                                .round()
                                                .toString()
                                            : store.lowBalanceThreshold
                                                .toString(),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9.]'),
                                          ),
                                        ],
                                        decoration: InputDecoration(
                                          labelText: 'Threshold',
                                          prefixText: '$symbol ',
                                          filled: true,
                                          fillColor: colors.surfaceHover,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                        onFieldSubmitted: (raw) async {
                                          final v =
                                              double.tryParse(raw.trim()) ?? 0;
                                          await store.setLowBalanceThreshold(v);
                                          if (!context.mounted) return;
                                          AppToast.success(
                                            context,
                                            'Low balance threshold saved.',
                                          );
                                        },
                                        onEditingComplete: () {},
                                        onTapOutside: (event) {
                                          FocusScope.of(context).unfocus();
                                        },
                                        onChanged: (raw) {
                                          final v =
                                              double.tryParse(raw.trim());
                                          if (v != null && v >= 0) {
                                            store.setLowBalanceThreshold(v);
                                          }
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateModeSegmented extends StatelessWidget {
  const _DateModeSegmented({
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  final DefaultDateMode value;
  final AppPalette colors;
  final ValueChanged<DefaultDateMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          children: [
            for (final (mode, label) in [
              (DefaultDateMode.today, 'Today'),
              (DefaultDateMode.remember, 'Last used'),
            ])
              Expanded(
                child: Material(
                  color: value == mode ? colors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => onChanged(mode),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: value == mode
                            ? Border.all(color: colors.border)
                            : null,
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: value == mode
                              ? colors.textPrimary
                              : colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colors.accentMuted : colors.surfaceHover,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? colors.accent : colors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? colors.accent : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  const _CurrencyDropdown({
    super.key,
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  final AppCurrency value;
  final AppPalette colors;
  final ValueChanged<AppCurrency> onChanged;

  static List<AppCurrency> get _options => [
        AppCurrency.inr,
        ...AppCurrency.values.where((c) => c != AppCurrency.inr),
      ];

  Future<void> _pick(BuildContext context) async {
    final picked = await showAppSheet<AppCurrency>(
      context: context,
      isScrollControlled: false,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  'Currency',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              for (final currency in _options)
                ListTile(
                  leading: Text(
                    currency.flag,
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: Text(
                    currency.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '${currency.country} · ${currency.code}',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                  trailing: Text(
                    currency.symbol,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: currency == value
                          ? colors.accent
                          : colors.textSecondary,
                    ),
                  ),
                  selected: currency == value,
                  selectedTileColor: colors.accentMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => Navigator.pop(sheetContext, currency),
                ),
            ],
          ),
        );
      },
    );

    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.surfaceHover,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: _CurrencyOption(
                  currency: value,
                  colors: colors,
                  dense: true,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyOption extends StatelessWidget {
  const _CurrencyOption({
    required this.currency,
    required this.colors,
    this.dense = false,
  });

  final AppCurrency currency;
  final AppPalette colors;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(currency.flag, style: TextStyle(fontSize: dense ? 18 : 20)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            currency.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
        if (!dense) ...[
          const SizedBox(width: 8),
          Text(
            currency.symbol,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

class _RemindersSection extends StatelessWidget {
  const _RemindersSection();

  Future<void> _afterChange(BuildContext context, String message) async {
    await ReminderSync.refresh();
    if (!context.mounted) return;
    AppToast.success(context, message);
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListenableBuilder(
      listenable: AppSettingsStore.instance,
      builder: (context, _) {
        final store = AppSettingsStore.instance;
        return _SettingsPanel(
          colors: colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SecurityToggleRow(
                icon: Icons.notifications_active_rounded,
                title: 'Phone notifications',
                subtitle: 'Allow local reminders when Accountant is closed.',
                value: store.notificationsEnabled,
                colors: colors,
                tint: colors.accent,
                onChanged: (v) async {
                  HapticFeedback.selectionClick();
                  if (v) {
                    await NotificationService.instance.requestPermission();
                  }
                  await store.setNotificationsEnabled(v);
                  if (!context.mounted) return;
                  await _afterChange(
                    context,
                    v ? 'Notifications on.' : 'Notifications off.',
                  );
                },
              ),
              Divider(height: 1, color: colors.border),
              _SecurityToggleRow(
                icon: Icons.edit_calendar_rounded,
                title: 'Daily log reminder',
                subtitle: 'Remind me to add spends at a set time.',
                value: store.dailyLogReminderEnabled,
                colors: colors,
                tint: const Color(0xFFEA580C),
                onChanged: (v) async {
                  HapticFeedback.selectionClick();
                  await store.setDailyLogReminderEnabled(v);
                  if (!context.mounted) return;
                  await _afterChange(context, 'Daily reminder updated.');
                },
              ),
              if (store.dailyLogReminderEnabled) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Reminder time · ${_formatTime(store.dailyLogReminderHour, store.dailyLogReminderMinute)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          HapticFeedback.selectionClick();
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: store.dailyLogReminderHour,
                              minute: store.dailyLogReminderMinute,
                            ),
                          );
                          if (picked == null) return;
                          await store.setDailyLogReminderTime(
                            picked.hour,
                            picked.minute,
                          );
                          if (!context.mounted) return;
                          await _afterChange(context, 'Reminder time saved.');
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),
              ],
              Divider(height: 1, color: colors.border),
              _SecurityToggleRow(
                icon: Icons.pie_chart_outline_rounded,
                title: 'Budget reminders',
                subtitle:
                    'Current month unplanned + next month (about 5 days before).',
                value: store.budgetRemindersEnabled,
                colors: colors,
                tint: colors.success,
                onChanged: (v) async {
                  HapticFeedback.selectionClick();
                  await store.setBudgetRemindersEnabled(v);
                  if (!context.mounted) return;
                  await _afterChange(context, 'Budget reminders updated.');
                },
              ),
              Divider(height: 1, color: colors.border),
              _SecurityToggleRow(
                icon: Icons.event_repeat_rounded,
                title: 'Scheduled payment reminders',
                subtitle:
                    'Alert within ${store.scheduledReminderLeadDays} days of due date.',
                value: store.scheduledRemindersEnabled,
                colors: colors,
                tint: const Color(0xFF7C3AED),
                onChanged: (v) async {
                  HapticFeedback.selectionClick();
                  await store.setScheduledRemindersEnabled(v);
                  if (!context.mounted) return;
                  await _afterChange(context, 'Scheduled reminders updated.');
                },
              ),
              Divider(height: 1, color: colors.border),
              _SecurityToggleRow(
                icon: Icons.savings_outlined,
                title: 'Planned reserves',
                subtitle:
                    'Home tip ~5 days before next cycle + fold into budget planning.',
                value: store.plannedReservesEnabled,
                colors: colors,
                tint: const Color(0xFF0D9488),
                onChanged: (v) async {
                  HapticFeedback.selectionClick();
                  await store.setPlannedReservesEnabled(v);
                  if (!context.mounted) return;
                  await _afterChange(context, 'Planned reserves updated.');
                },
              ),
              if (store.plannedReservesEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'When planning next cycle',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<PlannedReserveAllocationMode>(
                        segments: const [
                          ButtonSegment(
                            value: PlannedReserveAllocationMode.ask,
                            label: Text('Ask me'),
                          ),
                          ButtonSegment(
                            value: PlannedReserveAllocationMode.auto,
                            label: Text('Auto-add'),
                          ),
                        ],
                        selected: {store.plannedReserveAllocationMode},
                        onSelectionChanged: (set) async {
                          final mode = set.first;
                          HapticFeedback.selectionClick();
                          await store.setPlannedReserveAllocationMode(mode);
                          if (!context.mounted) return;
                          await _afterChange(
                            context,
                            mode == PlannedReserveAllocationMode.auto
                                ? 'Will auto-add reserves to limits.'
                                : 'Will ask before adding reserves.',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              Divider(height: 1, color: colors.border),
              _SecurityToggleRow(
                icon: Icons.handshake_outlined,
                title: 'Lend & borrow reminders',
                subtitle:
                    'Alert within ${store.debtReminderLeadDays} days of due date.',
                value: store.debtRemindersEnabled,
                colors: colors,
                tint: const Color(0xFFD97706),
                onChanged: (v) async {
                  HapticFeedback.selectionClick();
                  await store.setDebtRemindersEnabled(v);
                  if (!context.mounted) return;
                  await _afterChange(context, 'Debt reminders updated.');
                },
              ),
              if (store.debtRemindersEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Lead days',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                      for (final d in const [2, 3, 5])
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: ChoiceChip(
                            label: Text('$d'),
                            selected: store.debtReminderLeadDays == d,
                            onSelected: (_) async {
                              HapticFeedback.selectionClick();
                              await store.setDebtReminderLeadDays(d);
                              if (!context.mounted) return;
                              await _afterChange(
                                context,
                                'Debt lead days · $d',
                              );
                            },
                          ),
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

class _SecuritySection extends StatefulWidget {
  const _SecuritySection();

  @override
  State<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends State<_SecuritySection> {
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadBiometric();
  }

  Future<void> _loadBiometric() async {
    final available = await BiometricAuth.instance.isAvailable();
    if (!mounted) return;
    setState(() => _biometricAvailable = available);
  }

  Future<bool> _confirmWithPin(BuildContext context) async {
    final ok = await showUnlockSheet(
      context,
      title: 'Confirm PIN',
      subtitle: 'Enter your PIN to change this setting.',
    );
    return ok == true;
  }

  Future<void> _enableLock(BuildContext context) async {
    final lock = AppLockStore.instance;
    if (!lock.hasPin) {
      final saved = await showPinSetupSheet(context, title: 'Set a PIN');
      if (saved == true && context.mounted) {
        AppSession.instance.unlock();
        AppToast.success(context, 'App lock enabled.');
      }
      return;
    }
    await lock.setEnabled(true);
    if (context.mounted) AppToast.success(context, 'App lock enabled.');
  }

  Future<void> _disableLock(BuildContext context) async {
    if (!await _confirmWithPin(context)) return;
    await AppLockStore.instance.setEnabled(false);
    SensitiveAccessSession.instance.lock();
    if (context.mounted) AppToast.success(context, 'App lock turned off.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ListenableBuilder(
      listenable: AppLockStore.instance,
      builder: (context, _) {
        final lock = AppLockStore.instance;
        return _SettingsPanel(
          colors: colors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SecurityToggleRow(
                icon: Icons.lock_rounded,
                title: 'App lock',
                subtitle: lock.hasPin
                    ? 'Require PIN when opening Accountant.'
                    : 'Set a PIN to protect the app.',
                value: lock.isEnabled && lock.hasPin,
                colors: colors,
                tint: const Color(0xFF475569),
                onChanged: (v) async {
                  HapticFeedback.selectionClick();
                  if (v) {
                    await _enableLock(context);
                  } else {
                    await _disableLock(context);
                  }
                },
              ),
              if (lock.hasPin) ...[
                Divider(height: 1, color: colors.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF475569).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF475569).withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.pin_rounded,
                          size: 20,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Change PIN',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          HapticFeedback.selectionClick();
                          final ok = await showPinSetupSheet(
                            context,
                            title: 'Change PIN',
                            currentPinRequired: 'verify',
                          );
                          if (ok == true && context.mounted) {
                            AppToast.success(context, 'PIN updated.');
                          }
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),
              ],
              if ((_biometricAvailable || lock.biometricEnabled) &&
                  lock.hasPin) ...[
                Divider(height: 1, color: colors.border),
                _SecurityToggleRow(
                  icon: Icons.fingerprint_rounded,
                  title: 'Fingerprint / Face ID',
                  subtitle: _biometricAvailable
                      ? 'Unlock with biometrics. PIN is still required once a week.'
                      : 'Biometrics unavailable on this device.',
                  value: lock.biometricEnabled && lock.isEnabled,
                  colors: colors,
                  tint: const Color(0xFF0891B2),
                  onChanged: lock.isEnabled
                      ? (v) async {
                          HapticFeedback.selectionClick();
                          if (v) {
                            if (!_biometricAvailable) {
                              AppToast.warning(
                                context,
                                'Biometrics unavailable. Use PIN to unlock.',
                              );
                              return;
                            }
                            AppSession.instance.setAuthenticating(true);
                            final result =
                                await BiometricAuth.instance.authenticate(
                              reason: 'Enable biometrics for Accountant',
                            );
                            AppSession.instance.setAuthenticating(false);
                            if (!result.success) {
                              if (context.mounted) {
                                AppToast.warning(
                                  context,
                                  result.userMessage ??
                                      'Biometrics not confirmed.',
                                );
                              }
                              return;
                            }
                          }
                          await lock.setBiometricEnabled(v);
                          if (context.mounted) {
                            AppToast.success(
                              context,
                              v
                                  ? 'Fingerprint / Face ID enabled.'
                                  : 'Biometrics turned off.',
                            );
                          }
                        }
                      : null,
                ),
              ],
              if (lock.hasPin && lock.biometricEnabled) ...[
                Divider(height: 1, color: colors.border),
                _SecurityToggleRow(
                  icon: Icons.pin_outlined,
                  title: 'Weekly PIN check',
                  subtitle:
                      'Every 7 days ask for PIN even if biometrics work.',
                  value: lock.weeklyPinEnabled && lock.isEnabled,
                  colors: colors,
                  tint: const Color(0xFF0D9488),
                  onChanged: lock.isEnabled
                      ? (v) async {
                          HapticFeedback.selectionClick();
                          if (!v && !await _confirmWithPin(context)) return;
                          await lock.setWeeklyPinEnabled(v);
                          if (context.mounted) {
                            AppToast.success(
                              context,
                              v
                                  ? 'Weekly PIN check on.'
                                  : 'Weekly PIN check off.',
                            );
                          }
                        }
                      : null,
                ),
              ],
              if (lock.hasPin) ...[
                Divider(height: 1, color: colors.border),
                _SecurityToggleRow(
                  icon: Icons.phonelink_lock_rounded,
                  title: 'Lock when leaving app',
                  subtitle:
                      'Ask again after Accountant is in the background (~20s).',
                  value: lock.lockOnResume && lock.isEnabled,
                  colors: colors,
                  tint: const Color(0xFFEA580C),
                  onChanged: lock.isEnabled
                      ? (v) async {
                          HapticFeedback.selectionClick();
                          await lock.setLockOnResume(v);
                        }
                      : null,
                ),
                Divider(height: 1, color: colors.border),
                _SecurityToggleRow(
                  icon: Icons.visibility_off_rounded,
                  title: 'Protect account balances',
                  subtitle:
                      'Hide amounts on Home and Accounts until you unlock.',
                  value: lock.protectAccountBalances,
                  colors: colors,
                  tint: const Color(0xFF7C3AED),
                  onChanged: (v) async {
                    HapticFeedback.selectionClick();
                    if (v && !lock.hasPin) {
                      await _enableLock(context);
                      if (!context.mounted) return;
                      if (!AppLockStore.instance.hasPin) return;
                    }
                    if (!v && lock.protectAccountBalances) {
                      if (!await _confirmWithPin(context)) return;
                      if (!context.mounted) return;
                    }
                    await lock.setProtectAccountBalances(v);
                    SensitiveAccessSession.instance.lock();
                    if (!context.mounted) return;
                    AppToast.success(
                      context,
                      v
                          ? 'Balances stay hidden until unlocked.'
                          : 'Balance protection off.',
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SecurityToggleRow extends StatelessWidget {
  const _SecurityToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.colors,
    required this.onChanged,
    this.icon,
    this.tint,
  });

  final String title;
  final String subtitle;
  final bool value;
  final AppPalette colors;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  /// Behavior tint for the leading icon chip (defaults to accent).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final chip = tint ?? colors.accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: chip.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: chip.withValues(alpha: 0.22)),
              ),
              child: Icon(icon, size: 20, color: chip),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.colors);

  final String text;
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: colors.textMuted,
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.colors, required this.child});

  final AppPalette colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class _ThemeSegmented extends StatelessWidget {
  const _ThemeSegmented({
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  final ThemeMode value;
  final AppPalette colors;
  final ValueChanged<ThemeMode> onChanged;

  static const _options = <(ThemeMode, String, IconData)>[
    (ThemeMode.system, 'Auto', Icons.computer_rounded),
    (ThemeMode.light, 'Light', Icons.light_mode_rounded),
    (ThemeMode.dark, 'Dark', Icons.dark_mode_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          children: [
            for (final (mode, label, icon) in _options)
              Expanded(
                child: _Segment(
                  label: label,
                  icon: icon,
                  active: value == mode,
                  colors: colors,
                  onTap: () => onChanged(mode),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.active,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final AppPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? colors.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: colors.border) : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: active ? colors.textPrimary : colors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? colors.textPrimary : colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
