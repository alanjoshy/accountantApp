// Settings — General / Appearance + Currency + Cash flow + Tags.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/app_currency.dart';
import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/theme_controller.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../settings/data/app_settings_store.dart';

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
                    _SectionLabel('Cash flow', colors),
                    const SizedBox(height: 4),
                    Text(
                      'Cycle start day and monthly income power daily allowance.',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    const _CashFlowSection(),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionLabel('Tags', colors),
                    const SizedBox(height: 4),
                    Text(
                      'Reusable tags for Activity filters and transactions.',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    ),
                    const SizedBox(height: 8),
                    const _TagsSection(),
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

class _CashFlowSection extends StatefulWidget {
  const _CashFlowSection();

  @override
  State<_CashFlowSection> createState() => _CashFlowSectionState();
}

class _CashFlowSectionState extends State<_CashFlowSection> {
  late final TextEditingController _income;
  late final TextEditingController _cycleDay;

  @override
  void initState() {
    super.initState();
    final s = AppSettingsStore.instance;
    final income = s.monthlyIncome;
    _income = TextEditingController(
      text: income <= 0
          ? ''
          : (income == income.roundToDouble()
              ? income.round().toString()
              : income.toString()),
    );
    _cycleDay = TextEditingController(text: '${s.cycleStartDay}');
  }

  @override
  void dispose() {
    _income.dispose();
    _cycleDay.dispose();
    super.dispose();
  }

  Future<void> _saveIncome() async {
    final value = double.tryParse(_income.text.trim()) ?? 0;
    await AppSettingsStore.instance.setMonthlyIncome(value);
    if (!mounted) return;
    AppToast.success(context, 'Monthly income saved.');
  }

  Future<void> _saveCycleDay() async {
    final day = int.tryParse(_cycleDay.text.trim()) ?? 1;
    await AppSettingsStore.instance.setCycleStartDay(day);
    _cycleDay.text = '${AppSettingsStore.instance.cycleStartDay}';
    if (!mounted) return;
    AppToast.success(context, 'Cycle start day saved.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return _SettingsPanel(
      colors: colors,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cycle start day (1–28)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cycleDay,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: colors.surfaceHover,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _saveCycleDay(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saveCycleDay,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Monthly income',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _income,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      hintText: '0',
                      filled: true,
                      fillColor: colors.surfaceHover,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _saveIncome(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saveIncome,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagsSection extends StatefulWidget {
  const _TagsSection();

  @override
  State<_TagsSection> createState() => _TagsSectionState();
}

class _TagsSectionState extends State<_TagsSection> {
  final _tag = TextEditingController();

  @override
  void dispose() {
    _tag.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final value = _tag.text.trim();
    if (value.isEmpty) return;
    await AppSettingsStore.instance.addTag(value);
    _tag.clear();
    if (!mounted) return;
    AppToast.success(context, 'Tag added.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListenableBuilder(
      listenable: AppSettingsStore.instance,
      builder: (context, _) {
        final tags = AppSettingsStore.instance.tags;
        return _SettingsPanel(
          colors: colors,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tag,
                        decoration: InputDecoration(
                          hintText: 'New tag',
                          filled: true,
                          fillColor: colors.surfaceHover,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onSubmitted: (_) => _add(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _add,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in tags)
                        InputChip(
                          label: Text(tag),
                          onDeleted: () async {
                            await AppSettingsStore.instance.removeTag(tag);
                            if (!context.mounted) return;
                            AppToast.show(
                              context,
                              'Tag removed.',
                              tone: AppToastTone.info,
                            );
                          },
                        ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Text(
                    'No tags yet.',
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        );
      },
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
    final picked = await showModalBottomSheet<AppCurrency>(
      context: context,
      backgroundColor: colors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
