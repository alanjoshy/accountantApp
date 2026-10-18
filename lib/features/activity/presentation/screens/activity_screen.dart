// Activity tab — recent / categories / tags (web /activity).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../accounts/data/account.dart';
import '../../../accounts/data/account_store.dart';
import '../../../accounts/domain/payments.dart';
import '../../../budgets/data/budget_store.dart';
import '../../../budgets/domain/budget_logic.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../../transactions/data/transaction.dart';
import '../../../transactions/data/transaction_store.dart';
import '../../domain/activity_logic.dart';
import '../../domain/cycle.dart';
import '../widgets/category_spend_pie.dart';
import '../widgets/daily_spend_line_chart.dart';
import '../widgets/day_grouped_transactions.dart';

enum _ActivityTab { recent, categories, tags }

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  _ActivityTab _tab = _ActivityTab.recent;
  ActivityTypeFilter _type = ActivityTypeFilter.all;
  ActivityPeriodFilter _period = ActivityPeriodFilter.d30;
  String _search = '';
  String? _categoryFilter;
  String? _tagFilter;
  String? _accountFilter;
  String? _paymentModeFilter;
  bool _filtersOpen = false;
  bool _selectionMode = false;
  final _selectedIds = <String>{};
  bool _deleting = false;

  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _activeFilterCount =>
      (_type != ActivityTypeFilter.all ? 1 : 0) +
      (_period != ActivityPeriodFilter.all ? 1 : 0) +
      (_categoryFilter != null ? 1 : 0) +
      (_tagFilter != null ? 1 : 0) +
      (_accountFilter != null ? 1 : 0) +
      (_paymentModeFilter != null ? 1 : 0) +
      (_search.trim().isNotEmpty ? 1 : 0);

  void _clearFilters() {
    HapticFeedback.selectionClick();
    setState(() {
      _type = ActivityTypeFilter.all;
      _period = ActivityPeriodFilter.all;
      _search = '';
      _searchController.clear();
      _categoryFilter = null;
      _tagFilter = null;
      _accountFilter = null;
      _paymentModeFilter = null;
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _enterSelection([String? id]) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      _tab = _ActivityTab.recent;
      _selectedIds
        ..clear()
        ..addAll(id == null ? const <String>{} : {id});
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final n = _selectedIds.length;
    final ok = await AppToast.confirm(
      context,
      title: 'Delete $n transaction${n == 1 ? '' : 's'}?',
      message:
          'This removes them from Activity and reverses linked account balances. It cannot be undone.',
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      final removed =
          await TransactionStore.instance.deleteMany(_selectedIds);
      if (!mounted) return;
      _exitSelection();
      AppToast.warning(
        context,
        removed == 1
            ? '1 transaction deleted.'
            : '$removed transactions deleted.',
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ListenableBuilder(
      listenable: Listenable.merge([
        TransactionStore.instance,
        AccountStore.instance,
        AppSettingsStore.instance,
        BudgetStore.instance,
        CurrencyController.instance,
      ]),
      builder: (context, _) {
        final all = TransactionStore.instance.transactions;
        final cycleDay = AppSettingsStore.instance.cycleStartDay;
        final filtered = filterActivityTransactions(
          all,
          type: _type,
          period: _period,
          search: _search,
          category: _categoryFilter,
          tag: _tagFilter,
          accountId: _accountFilter,
          paymentMode: _paymentModeFilter,
          cycleStartDay: cycleDay,
        );
        final totals = sumByType(filtered);
        final categoryRows = buildCategoryBreakdown(filtered);
        final expenseRows = buildExpenseCategoryBreakdown(filtered);
        final tagRows = buildTagBreakdown(filtered);
        final dailySpend = buildDailySpending(
          filtered,
          _period,
          cycleStartDay: cycleDay,
        );
        final categories = {
          for (final t in all)
            if (t.type != TransactionType.transfer) t.category,
        }.toList()
          ..sort();
        final availableTags = AppSettingsStore.instance.tags;
        final cycleBounds = getCurrentCycleDayBounds(cycleDay);
        final cycleBudgets = listedBudgetsForWindow(
          BudgetStore.instance.budgets,
          cycleBounds,
          includeUndated: true,
        );
        final pool = totalBudgetPool(
          cycleBudgets.map((b) => b.limit),
          AppSettingsStore.instance.monthlyIncome,
        );
        final days = cycleDayCount(cycleDay);
        final dailyAllowance = pool > 0 && days > 0 ? pool / days : 0.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg + bottom,
          ),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Activity',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectionMode
                                    ? '${_selectedIds.length} selected'
                                    : 'Recent activity, categories, and tags',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_tab == _ActivityTab.recent)
                          IconButton(
                            onPressed: () {
                              if (_selectionMode) {
                                _exitSelection();
                              } else {
                                _enterSelection();
                              }
                            },
                            icon: Icon(
                              _selectionMode
                                  ? Icons.close_rounded
                                  : Icons.check_box_outlined,
                              color: colors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Tabs(
                      tab: _tab,
                      colors: colors,
                      onChanged: (t) {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _tab = t;
                          if (t != _ActivityTab.recent) _exitSelection();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _search = v),
                            decoration: InputDecoration(
                              hintText: 'Search title, category, tag…',
                              prefixIcon: Icon(Icons.search_rounded,
                                  color: colors.textMuted, size: 20),
                              filled: true,
                              fillColor: colors.surfaceHover,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
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
                        ),
                        const SizedBox(width: 8),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton.filledTonal(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setState(() => _filtersOpen = !_filtersOpen);
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: _filtersOpen ||
                                        _activeFilterCount > 0
                                    ? colors.accentMuted
                                    : colors.surfaceHover,
                              ),
                              icon: Icon(
                                Icons.tune_rounded,
                                color: _filtersOpen || _activeFilterCount > 0
                                    ? colors.accent
                                    : colors.textSecondary,
                              ),
                            ),
                            if (_activeFilterCount > 0)
                              Positioned(
                                right: 2,
                                top: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.accent,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$_activeFilterCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (_filtersOpen) ...[
                      const SizedBox(height: 12),
                      _FiltersPanel(
                        colors: colors,
                        type: _type,
                        period: _period,
                        categoryFilter: _categoryFilter,
                        tagFilter: _tagFilter,
                        accountFilter: _accountFilter,
                        paymentModeFilter: _paymentModeFilter,
                        categories: categories,
                        tags: availableTags,
                        accounts: AccountStore.instance.accounts,
                        activeCount: _activeFilterCount,
                        onClear: _clearFilters,
                        onType: (v) => setState(() => _type = v),
                        onPeriod: (v) => setState(() => _period = v),
                        onCategory: (v) => setState(() => _categoryFilter = v),
                        onTag: (v) => setState(() => _tagFilter = v),
                        onAccount: (v) => setState(() => _accountFilter = v),
                        onPaymentMode: (v) =>
                            setState(() => _paymentModeFilter = v),
                      ),
                    ],
                    if (_tab == _ActivityTab.categories) ...[
                      const SizedBox(height: 12),
                      CategorySpendPie(
                        rows: expenseRows,
                        income: totals.income,
                        expense: totals.expense,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _SummaryRow(
                      colors: colors,
                      income: totals.income,
                      expense: totals.expense,
                      count: filtered.length,
                    ),
                    const SizedBox(height: 12),
                    if (_tab == _ActivityTab.recent) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: CategorySpendPie(
                              rows: expenseRows,
                              income: totals.income,
                              expense: totals.expense,
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DailySpendLineChart(
                              points: dailySpend,
                              dailyAllowance: dailyAllowance,
                              compact: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Recent activity',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          if (_selectionMode) ...[
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedIds
                                    ..clear()
                                    ..addAll(filtered.map((t) => t.id));
                                });
                              },
                              child: Text('Select all',
                                  style: TextStyle(color: colors.accent)),
                            ),
                            TextButton(
                              onPressed: _selectedIds.isEmpty || _deleting
                                  ? null
                                  : _deleteSelected,
                              child: Text(
                                _deleting ? 'Deleting…' : 'Delete',
                                style: TextStyle(color: colors.error),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      DayGroupedTransactions(
                        transactions: filtered,
                        emptyMessage: _activeFilterCount > 0
                            ? 'No transactions match these filters.'
                            : 'No transactions yet. Tap + to add one.',
                        selectionMode: _selectionMode,
                        selectedIds: _selectedIds,
                        onToggleSelect: (id) {
                          setState(() {
                            if (_selectedIds.contains(id)) {
                              _selectedIds.remove(id);
                            } else {
                              _selectedIds.add(id);
                            }
                          });
                        },
                        onEnterSelection: _enterSelection,
                      ),
                    ],
                    if (_tab == _ActivityTab.categories) ...[
                      Text(
                        'Category spending',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (categoryRows.isEmpty)
                        _EmptyCard(
                          colors: colors,
                          text: 'No category data for this filter set.',
                        )
                      else
                        for (final row in categoryRows)
                          _BreakdownTile(
                            colors: colors,
                            row: row,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _categoryFilter = row.key;
                                _tab = _ActivityTab.recent;
                                _filtersOpen = true;
                              });
                            },
                          ),
                    ],
                    if (_tab == _ActivityTab.tags) ...[
                      Text(
                        'Tag spending',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (tagRows.isEmpty)
                        _EmptyCard(
                          colors: colors,
                          text:
                              'No tag data yet. Add tags in Settings, then tag transactions.',
                        )
                      else
                        for (final row in tagRows)
                          _BreakdownTile(
                            colors: colors,
                            row: row,
                            mutedBar: row.key == '__none__',
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _tagFilter = row.key;
                                _tab = _ActivityTab.recent;
                                _filtersOpen = true;
                              });
                            },
                          ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tab,
    required this.colors,
    required this.onChanged,
  });

  final _ActivityTab tab;
  final AppPalette colors;
  final ValueChanged<_ActivityTab> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(_ActivityTab id, String label, IconData icon) {
      final active = tab == id;
      return Expanded(
        child: Material(
          color: active ? colors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onChanged(id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 14,
                        color: active ? Colors.white : colors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            chip(_ActivityTab.recent, 'Recent', Icons.list_alt_rounded),
            chip(_ActivityTab.categories, 'Categories', Icons.category_rounded),
            chip(_ActivityTab.tags, 'Tags', Icons.sell_outlined),
          ],
        ),
      ),
    );
  }
}

class _FiltersPanel extends StatelessWidget {
  const _FiltersPanel({
    required this.colors,
    required this.type,
    required this.period,
    required this.categoryFilter,
    required this.tagFilter,
    required this.accountFilter,
    required this.paymentModeFilter,
    required this.categories,
    required this.tags,
    required this.accounts,
    required this.activeCount,
    required this.onClear,
    required this.onType,
    required this.onPeriod,
    required this.onCategory,
    required this.onTag,
    required this.onAccount,
    required this.onPaymentMode,
  });

  final AppPalette colors;
  final ActivityTypeFilter type;
  final ActivityPeriodFilter period;
  final String? categoryFilter;
  final String? tagFilter;
  final String? accountFilter;
  final String? paymentModeFilter;
  final List<String> categories;
  final List<String> tags;
  final List<MoneyAccount> accounts;
  final int activeCount;
  final VoidCallback onClear;
  final ValueChanged<ActivityTypeFilter> onType;
  final ValueChanged<ActivityPeriodFilter> onPeriod;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String?> onTag;
  final ValueChanged<String?> onAccount;
  final ValueChanged<String?> onPaymentMode;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Filters',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (activeCount > 0)
                  TextButton(
                    onPressed: onClear,
                    child: Text('Clear all',
                        style: TextStyle(color: colors.accent, fontSize: 12)),
                  ),
              ],
            ),
            Text('Type',
                style: TextStyle(fontSize: 11, color: colors.textMuted)),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final (f, label) in [
                  (ActivityTypeFilter.all, 'All'),
                  (ActivityTypeFilter.income, 'Income'),
                  (ActivityTypeFilter.expense, 'Expense'),
                ])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Text(label, style: const TextStyle(fontSize: 11)),
                        selected: type == f,
                        onSelected: (_) => onType(f),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Period',
                style: TextStyle(fontSize: 11, color: colors.textMuted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final (f, label) in [
                  (ActivityPeriodFilter.d7, '7 days'),
                  (ActivityPeriodFilter.d30, '30 days'),
                  (ActivityPeriodFilter.month, 'Cycle'),
                  (ActivityPeriodFilter.all, 'All time'),
                ])
                  ChoiceChip(
                    label: Text(label, style: const TextStyle(fontSize: 11)),
                    selected: period == f,
                    onSelected: (_) => onPeriod(f),
                  ),
              ],
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Category',
                  style: TextStyle(fontSize: 11, color: colors.textMuted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: categoryFilter == null,
                    onSelected: (_) => onCategory(null),
                  ),
                  for (final c in categories)
                    ChoiceChip(
                      label: Text(c),
                      selected: categoryFilter == c,
                      onSelected: (_) =>
                          onCategory(categoryFilter == c ? null : c),
                    ),
                ],
              ),
            ],
            if (tags.isNotEmpty || tagFilter != null) ...[
              const SizedBox(height: 10),
              Text('Tag',
                  style: TextStyle(fontSize: 11, color: colors.textMuted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: tagFilter == null,
                    onSelected: (_) => onTag(null),
                  ),
                  ChoiceChip(
                    label: const Text('No tag'),
                    selected: tagFilter == '__none__',
                    onSelected: (_) => onTag(
                      tagFilter == '__none__' ? null : '__none__',
                    ),
                  ),
                  for (final t in tags)
                    ChoiceChip(
                      label: Text(t.startsWith('#') ? t : '#$t'),
                      selected: tagFilter == t,
                      onSelected: (_) =>
                          onTag(tagFilter == t ? null : t),
                    ),
                ],
              ),
            ],
            if (accounts.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Account',
                  style: TextStyle(fontSize: 11, color: colors.textMuted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: accountFilter == null,
                    onSelected: (_) => onAccount(null),
                  ),
                  for (final a in accounts)
                    ChoiceChip(
                      label: Text(a.name),
                      selected: accountFilter == a.id,
                      onSelected: (_) => onAccount(
                        accountFilter == a.id ? null : a.id,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text('Payment mode',
                style: TextStyle(fontSize: 11, color: colors.textMuted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: paymentModeFilter == null,
                  onSelected: (_) => onPaymentMode(null),
                ),
                for (final m in paymentModes)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: paymentModeFilter == m.id.name,
                    onSelected: (_) => onPaymentMode(
                      paymentModeFilter == m.id.name ? null : m.id.name,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.colors,
    required this.income,
    required this.expense,
    required this.count,
  });

  final AppPalette colors;
  final double income;
  final double expense;
  final int count;

  @override
  Widget build(BuildContext context) {
    final format = CurrencyController.instance.format;
    Widget card(String label, String value, Color valueColor) {
      return Expanded(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        card('Income', format(income), colors.success),
        const SizedBox(width: 8),
        card('Expense', format(expense), colors.error),
        const SizedBox(width: 8),
        card('Count', '$count', colors.textPrimary),
      ],
    );
  }
}

class _BreakdownTile extends StatelessWidget {
  const _BreakdownTile({
    required this.colors,
    required this.row,
    required this.onTap,
    this.mutedBar = false,
  });

  final AppPalette colors;
  final BreakdownRow row;
  final VoidCallback onTap;
  final bool mutedBar;

  @override
  Widget build(BuildContext context) {
    final format = CurrencyController.instance.format;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            '${row.count} transaction${row.count == 1 ? '' : 's'} · ${(row.share * 100).round()}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      format(row.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colors.textMuted),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: row.share.clamp(0.02, 1),
                    minHeight: 6,
                    backgroundColor: colors.surfaceHover,
                    color: mutedBar ? colors.textMuted : colors.accent,
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.colors, required this.text});

  final AppPalette colors;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textMuted, fontSize: 13),
        ),
      ),
    );
  }
}
