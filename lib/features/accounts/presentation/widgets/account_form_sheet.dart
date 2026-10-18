// Add / edit money account.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../data/account.dart';
import '../../data/account_store.dart';
import '../../domain/account_style.dart';

Future<void> showAccountFormSheet(
  BuildContext context, {
  MoneyAccount? account,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) => AccountFormSheet(account: account),
  );
}

class AccountFormSheet extends StatefulWidget {
  const AccountFormSheet({super.key, this.account});

  final MoneyAccount? account;

  @override
  State<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends State<AccountFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late AccountKind _kind;
  late String _icon;
  late String _color;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _kind = a?.kind ?? AccountKind.bank;
    _icon = a?.icon ?? defaultIconForKind(_kind);
    _color = a?.color ?? defaultColorForKind(_kind);
    _name = TextEditingController(text: a?.name ?? '');
    final bal = a?.balance ?? 0;
    _balance = TextEditingController(
      text: _editing
          ? (bal == bal.roundToDouble()
              ? bal.round().toString()
              : bal.toString())
          : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter an account name.');
      return;
    }
    final bal = double.tryParse(_balance.text.trim()) ?? 0;
    if (bal < 0) {
      setState(() => _error = 'Enter a valid balance (0 or more).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_editing) {
        final existing = widget.account!;
        await AccountStore.instance.updateAccount(
          existing.copyWith(
            name: name,
            kind: _kind,
            // Opening balance only on create; edit updates name/style.
            // Balance changes go through tally / transactions.
            icon: _icon,
            color: _color,
          ),
        );
        if (!mounted) return;
        Navigator.pop(context);
        AppToast.success(context, 'Account updated.');
      } else {
        final created = await AccountStore.instance.addAccount(
          name: name,
          kind: _kind,
          balance: bal,
          icon: _icon,
          color: _color,
        );
        if (AppSettingsStore.instance.defaultAccountId == null) {
          await AppSettingsStore.instance.setDefaultAccountId(created.id);
        }
        if (!mounted) return;
        Navigator.pop(context);
        AppToast.success(context, 'Account added.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't save this account.";
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final symbol = CurrencyController.instance.symbol;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          12,
          AppSpacing.md,
          AppSpacing.md + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _editing ? 'Edit account' : 'Add account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Type',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in AccountKind.values)
                    ChoiceChip(
                      label: Text(accountKindLabel(kind)),
                      selected: _kind == kind,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _kind = kind;
                          if (!_editing) {
                            _icon = defaultIconForKind(kind);
                            _color = defaultColorForKind(kind);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Name',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g. HDFC Salary',
                  filled: true,
                  fillColor: colors.surfaceHover,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              ),
              if (!_editing) ...[
                const SizedBox(height: 12),
                Text(
                  'Opening balance',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _balance,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    prefixText: '$symbol ',
                    hintText: '0',
                    filled: true,
                    fillColor: colors.surfaceHover,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: colors.border),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Icon',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final key in accountIconOptions)
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _icon = key);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _icon == key
                              ? accountColorFromHex(_color)
                                  .withValues(alpha: 0.2)
                              : colors.surfaceHover,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _icon == key
                                ? accountColorFromHex(_color)
                                : colors.border,
                          ),
                        ),
                        child: Icon(
                          accountIconData(key),
                          size: 20,
                          color: accountColorFromHex(_color),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Color',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final hex in accountColorOptions)
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _color = hex);
                      },
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: accountColorFromHex(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == hex
                                ? colors.textPrimary
                                : colors.border,
                            width: _color == hex ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 13, color: colors.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(_saving ? 'Saving…' : (_editing ? 'Save' : 'Add')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
