// Manage reusable transaction tags (from More, not Settings).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../settings/data/app_settings_store.dart';
import '../../../transactions/domain/tag_label.dart';

class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key});

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  final _tag = TextEditingController();

  @override
  void dispose() {
    _tag.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final value = normalizeTagName(_tag.text);
    if (value.isEmpty) return;
    await AppSettingsStore.instance.addTag(value);
    _tag.clear();
    if (!mounted) return;
    AppToast.success(context, 'Tag added.');
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
                    Text(
                      'Tags',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reusable tags for Activity filters and transactions.',
                      style: TextStyle(fontSize: 14, color: colors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ListenableBuilder(
                      listenable: AppSettingsStore.instance,
                      builder: (context, _) {
                        final tags = AppSettingsStore.instance.tags;
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surfaceElevated,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.border),
                          ),
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
                                          hintText: 'work',
                                          prefixText: '# ',
                                          filled: true,
                                          fillColor: colors.surfaceHover,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
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
                                          label: Text(formatTagLabel(tag)),
                                          onDeleted: () async {
                                            final ok = await AppToast.confirm(
                                              context,
                                              title: 'Remove tag?',
                                              message:
                                                  '“${formatTagLabel(tag)}” will be removed from the list.',
                                              confirmLabel: 'Remove',
                                            );
                                            if (ok != true || !context.mounted) {
                                              return;
                                            }
                                            await AppSettingsStore.instance
                                                .removeTag(tag);
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
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
