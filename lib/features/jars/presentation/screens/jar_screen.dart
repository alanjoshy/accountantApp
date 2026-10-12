// Jars — savings goals (web /jar).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/currency/currency_controller.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/jar_goal.dart';
import '../../data/jar_store.dart';
import '../widgets/glass_jar.dart';
import '../widgets/jar_form_sheet.dart';

class JarScreen extends StatefulWidget {
  const JarScreen({super.key});

  @override
  State<JarScreen> createState() => _JarScreenState();
}

class _JarScreenState extends State<JarScreen> {
  Future<void> _openCreate() async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _JarEditorSheet(mode: _JarEditorMode.create),
    );
  }

  Future<void> _openEdit(JarGoal jar) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _JarEditorSheet(mode: _JarEditorMode.edit, jar: jar),
    );
  }

  Future<void> _openAdd(JarGoal jar) async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddMoneySheet(jar: jar),
    );
  }

  Future<void> _confirmDelete(JarGoal jar) async {
    final colors = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surfaceElevated,
          title: Text(
            'Delete jar?',
            style: TextStyle(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '“${jar.name}” and its saved progress will be removed.',
            style: TextStyle(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete', style: TextStyle(color: colors.error)),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    try {
      await JarStore.instance.deleteJar(jar.id);
      if (!mounted) return;
      AppToast.warning(context, 'Jar deleted.');
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, "Couldn't delete this jar. Please try again.");
      HapticFeedback.heavyImpact();
    }
  }

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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jars',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Watch savings fill as you add money',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: colors.accentMuted,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: _openCreate,
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                Icons.add_circle_outline_rounded,
                                color: colors.accent,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ListenableBuilder(
                      listenable: JarStore.instance,
                      builder: (context, _) {
                        final jars = JarStore.instance.jars;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (jars.isEmpty) _EmptyJars(colors: colors),
                            if (jars.isNotEmpty)
                              _JarGrid(
                                jars: jars,
                                colors: colors,
                                onAdd: _openAdd,
                                onEdit: _openEdit,
                                onDelete: _confirmDelete,
                              ),
                            const SizedBox(height: AppSpacing.md),
                            _AutoTransferComingSoon(colors: colors),
                          ],
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

class _EmptyJars extends StatelessWidget {
  const _EmptyJars({required this.colors});

  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.success.withValues(alpha: 0.20),
                ),
              ),
              child: Icon(Icons.archive_rounded, color: colors.success, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              'No jars yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create a savings jar and fill it toward your goal.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _JarGrid extends StatelessWidget {
  const _JarGrid({
    required this.jars,
    required this.colors,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<JarGoal> jars;
  final AppPalette colors;
  final ValueChanged<JarGoal> onAdd;
  final ValueChanged<JarGoal> onEdit;
  final ValueChanged<JarGoal> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CurrencyController.instance,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final gap = 12.0;
            final tileW = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final jar in jars)
                  SizedBox(
                    width: tileW,
                    child: _JarCard(
                      key: ValueKey(jar.id),
                      jar: jar,
                      colors: colors,
                      onAdd: () => onAdd(jar),
                      onEdit: () => onEdit(jar),
                      onDelete: () => onDelete(jar),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _JarCard extends StatelessWidget {
  const _JarCard({
    super.key,
    required this.jar,
    required this.colors,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final JarGoal jar;
  final AppPalette colors;
  final VoidCallback onAdd;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final format = CurrencyController.instance.format;
    final accent = jarColorFromHex(jar.color);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    jar.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${format(jar.currentAmount)} / ${format(jar.targetAmount)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                height: 1.3,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: colors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: GlassJar(
                progress: jar.progressPct,
                compact: true,
                fillColor: accent,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onAdd,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: OutlinedButton(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.textMuted,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Icon(Icons.delete_outline_rounded, size: 14, color: colors.textMuted),
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

class _AutoTransferComingSoon extends StatelessWidget {
  const _AutoTransferComingSoon({required this.colors});

  final AppPalette colors;

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jar auto-transfer',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Move money from an account into a jar daily, weekly, or monthly — like a savings SIP.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surfaceHover,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                'Coming soon',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _JarEditorMode { create, edit }

class _JarEditorSheet extends StatefulWidget {
  const _JarEditorSheet({required this.mode, this.jar});

  final _JarEditorMode mode;
  final JarGoal? jar;

  @override
  State<_JarEditorSheet> createState() => _JarEditorSheetState();
}

class _JarEditorSheetState extends State<_JarEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _current;
  late String _color;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final jar = widget.jar;
    _name = TextEditingController(text: jar?.name ?? '');
    _target = TextEditingController(
      text: jar == null ? '' : _trimNum(jar.targetAmount),
    );
    _current = TextEditingController(
      text: jar == null ? '' : _trimNum(jar.currentAmount),
    );
    _color = jar?.color ?? jarAccentOptions.first;
  }

  String _trimNum(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toString();
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _current.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a jar name.');
      HapticFeedback.heavyImpact();
      return;
    }
    final target = double.tryParse(_target.text.trim());
    if (target == null || target <= 0) {
      setState(() => _error = 'Enter a valid target (above zero).');
      HapticFeedback.heavyImpact();
      return;
    }
    final currentRaw = _current.text.trim();
    final current = currentRaw.isEmpty ? 0.0 : double.tryParse(currentRaw);
    if (current == null || current < 0) {
      setState(() => _error = 'Enter a valid current amount (0 or more).');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _saving = true);
    try {
      if (widget.mode == _JarEditorMode.create) {
        await JarStore.instance.createJar(
          name: name,
          targetAmount: target,
          currentAmount: current,
          color: _color,
        );
        if (!mounted) return;
        Navigator.pop(context);
        AppToast.success(context, 'Jar created.');
      } else {
        final id = widget.jar!.id;
        await JarStore.instance.updateJar(
          id,
          name: name,
          targetAmount: target,
          currentAmount: current,
          color: _color,
        );
        if (!mounted) return;
        Navigator.pop(context);
        AppToast.success(context, 'Jar updated.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = widget.mode == _JarEditorMode.create
            ? "Couldn't create this jar. Please try again."
            : "Couldn't update this jar. Please try again.";
        _saving = false;
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.mode == _JarEditorMode.create ? 'Create jar' : 'Edit jar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
          JarFormSheet(
            nameController: _name,
            targetController: _target,
            currentController: _current,
            color: _color,
            onColorChanged: (c) => setState(() => _color = c),
            onSubmit: _submit,
            submitLabel: widget.mode == _JarEditorMode.create
                ? 'Create jar'
                : 'Save changes',
            saving: _saving,
            error: _error,
          ),
        ],
      ),
    );
  }
}

class _AddMoneySheet extends StatefulWidget {
  const _AddMoneySheet({required this.jar});

  final JarGoal jar;

  @override
  State<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends State<_AddMoneySheet> {
  final _amount = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    final parsed = double.tryParse(_amount.text.trim());
    if (parsed == null || parsed == 0) {
      setState(() => _error = 'Enter a non-zero amount.');
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _saving = true);
    try {
      await JarStore.instance.addMoney(widget.jar.id, parsed);
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(context, 'Amount added to jar.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't update jar balance. Please try again.";
        _saving = false;
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
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
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Add money',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Jar: ${widget.jar.name}',
                style: TextStyle(fontSize: 14, color: colors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                ],
                decoration: InputDecoration(
                  hintText: 'Amount (negative to withdraw)',
                  filled: true,
                  fillColor: colors.surfaceHover,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _saving ? 'Saving…' : 'Add amount',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
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
      ),
    );
  }
}
