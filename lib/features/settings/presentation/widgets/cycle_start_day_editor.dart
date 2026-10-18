// Shared cycle start day picker (salary / billing month).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../activity/domain/cycle.dart';
import '../../data/app_settings_store.dart';

const _quickDays = [1, 5, 15, 25];

class CycleStartDayEditor extends StatefulWidget {
  const CycleStartDayEditor({
    super.key,
    this.showTitle = true,
    this.compact = false,
  });

  final bool showTitle;
  final bool compact;

  @override
  State<CycleStartDayEditor> createState() => _CycleStartDayEditorState();
}

class _CycleStartDayEditorState extends State<CycleStartDayEditor> {
  late final TextEditingController _day;
  late int _saved;

  @override
  void initState() {
    super.initState();
    _saved = AppSettingsStore.instance.cycleStartDay;
    _day = TextEditingController(text: '$_saved');
    _day.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _day.removeListener(_onFieldChanged);
    _day.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  int get _draftDay {
    final parsed = int.tryParse(_day.text.trim());
    if (parsed == null) return _saved;
    return clampCycleStartDay(parsed);
  }

  /// Save stays off until the draft differs from the last persisted value.
  bool get _canSave => _draftDay != _saved;

  void _selectDraft(int day) {
    final next = clampCycleStartDay(day);
    if (_day.text.trim() == '$next') return;
    HapticFeedback.selectionClick();
    _day.text = '$next';
    // Listener calls setState.
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final next = _draftDay;
    await AppSettingsStore.instance.setCycleStartDay(next);
    if (!mounted) return;
    setState(() {
      _saved = next;
      _day.text = '$next';
    });
    HapticFeedback.mediumImpact();
    AppToast.success(context, 'Pay cycle saved.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final draft = _draftDay;
    final range = getCurrentCycleRange(draft);
    final rangeLabel = formatDateRange(range.start, range.end);
    final canSave = _canSave;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle) ...[
          Text(
            'Month starts on day',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Use your salary or billing date (1–28). Home, budgets, and Activity follow this cycle.',
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final day in _quickDays)
              _DayChip(
                label: _ordinal(day),
                selected: draft == day,
                colors: colors,
                onTap: () => _selectDraft(day),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _day,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: InputDecoration(
                  labelText: 'Day (1–28)',
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
                onSubmitted: (_) {
                  if (canSave) _save();
                },
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: canSave ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: colors.surfaceHover,
                disabledForegroundColor: colors.textMuted,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
        if (!widget.compact) ...[
          const SizedBox(height: 12),
          Text(
            canSave
                ? 'Preview cycle · $rangeLabel'
                : 'Current cycle · $rangeLabel',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.accent,
            ),
          ),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
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
      color: selected ? colors.accent : colors.surfaceHover,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? colors.accent : colors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

String _ordinal(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  switch (day % 10) {
    case 1:
      return '${day}st';
    case 2:
      return '${day}nd';
    case 3:
      return '${day}rd';
    default:
      return '${day}th';
  }
}
