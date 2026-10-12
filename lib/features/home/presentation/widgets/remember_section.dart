// Things to remember — tip cards (web RememberSection).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../data/static_remember_tips.dart';

class RememberSection extends StatefulWidget {
  const RememberSection({super.key, this.tips = staticRememberTips});

  final List<StaticRememberTip> tips;

  @override
  State<RememberSection> createState() => _RememberSectionState();
}

class _RememberSectionState extends State<RememberSection> {
  static const _visibleCap = 4;
  final _dismissed = <String>{};

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final visible = widget.tips
        .where((t) => !_dismissed.contains(t.id))
        .take(_visibleCap)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Things to remember',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Budget setup, scheduled sends, debts, and spend pace',
          style: TextStyle(
            fontSize: 12,
            height: 1.3,
            color: colors.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceHover.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _TipCard(
                    key: ValueKey(visible[i].id),
                    tip: visible[i],
                    colors: colors,
                    onDismiss: () {
                      HapticFeedback.selectionClick();
                      setState(() => _dismissed.add(visible[i].id));
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    super.key,
    required this.tip,
    required this.colors,
    required this.onDismiss,
  });

  final StaticRememberTip tip;
  final AppPalette colors;
  final VoidCallback onDismiss;

  static const _warning = Color(0xFFEAB308);

  (Color border, Color accent, Color meta) get _tone {
    return switch (tip.tone) {
      RememberTone.info => (
          colors.border,
          colors.accent,
          colors.textMuted,
        ),
      RememberTone.warning => (
          _warning.withValues(alpha: 0.35),
          _warning,
          _warning.withValues(alpha: 0.8),
        ),
      RememberTone.success => (
          colors.success.withValues(alpha: 0.35),
          colors.success,
          colors.success.withValues(alpha: 0.8),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    // Web: rounded-2xl rounded-tl-md
    final radius = const BorderRadius.only(
      topLeft: Radius.circular(6),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: radius,
        border: Border.all(color: tone.$1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: colors.surfaceHover,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border),
                    ),
                    child: Icon(
                      tip.hrefLabel != null
                          ? Icons.chat_bubble_outline_rounded
                          : Icons.lightbulb_outline_rounded,
                      size: 14,
                      color: tone.$2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            letterSpacing: -0.2,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tip.body,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: colors.textSecondary,
                          ),
                        ),
                        if (tip.hrefLabel != null) ...[
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tip.hrefLabel!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: tone.$3,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 12,
                                  color: tone.$3,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            MediaQuery.withNoTextScaling(
              child: Tooltip(
                message: 'Dismiss ${tip.title}',
                child: InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: colors.textMuted,
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
