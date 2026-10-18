// Tag chips + create (web TagPicker) — labels show #prefix.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/tag_label.dart';

class TagPicker extends StatefulWidget {
  const TagPicker({
    super.key,
    required this.availableTags,
    required this.selected,
    required this.onChange,
    this.onCreateTag,
    this.allowCreate = true,
    this.emptyHint = 'Type a tag below to create one.',
  });

  final List<String> availableTags;
  final List<String> selected;
  final ValueChanged<List<String>> onChange;
  final Future<bool> Function(String name)? onCreateTag;
  final bool allowCreate;
  final String emptyHint;

  @override
  State<TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends State<TagPicker> {
  final _draft = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _toggle(String tag) {
    HapticFeedback.selectionClick();
    setState(() => _error = null);
    final next = [...widget.selected];
    if (next.contains(tag)) {
      next.remove(tag);
    } else {
      next.add(tag);
    }
    widget.onChange(next);
  }

  Future<void> _createOrSelect() async {
    if (_busy) return;
    setState(() => _error = null);
    final trimmed = normalizeTagName(_draft.text);
    if (trimmed.isEmpty) {
      setState(() => _error = 'Enter a tag name.');
      HapticFeedback.heavyImpact();
      return;
    }
    if (trimmed.length > 32) {
      setState(() => _error = 'Tag is too long (max 32 characters).');
      HapticFeedback.heavyImpact();
      return;
    }

    String? existingMatch;
    for (final t in widget.availableTags) {
      if (t.toLowerCase() == trimmed.toLowerCase()) {
        existingMatch = t;
        break;
      }
    }
    if (existingMatch != null) {
      if (!widget.selected.contains(existingMatch)) {
        widget.onChange([...widget.selected, existingMatch]);
        HapticFeedback.selectionClick();
      }
      _draft.clear();
      setState(() {});
      return;
    }

    final create = widget.onCreateTag;
    if (!widget.allowCreate || create == null) {
      setState(() => _error = 'Create tags in More → Tags first.');
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() => _busy = true);
    try {
      final ok = await create(trimmed);
      if (!ok) {
        setState(() => _error = "Couldn't add that tag.");
        HapticFeedback.heavyImpact();
        return;
      }
      if (!widget.selected
          .any((s) => s.toLowerCase() == trimmed.toLowerCase())) {
        widget.onChange([...widget.selected, trimmed]);
      }
      _draft.clear();
      HapticFeedback.lightImpact();
    } catch (_) {
      setState(() => _error = "Couldn't add that tag.");
      HapticFeedback.heavyImpact();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final trimmed = normalizeTagName(_draft.text);
    final existingMatch = widget.availableTags.any(
      (t) => t.toLowerCase() == trimmed.toLowerCase(),
    );
    final canCreate = widget.allowCreate &&
        widget.onCreateTag != null &&
        trimmed.isNotEmpty &&
        !existingMatch &&
        !_busy;

    final orphanSelected = widget.selected.where(
      (t) => !widget.availableTags
          .any((a) => a.toLowerCase() == t.toLowerCase()),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tags',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        if (widget.availableTags.isEmpty && widget.selected.isEmpty)
          Text(
            widget.emptyHint,
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in widget.availableTags)
                FilterChip(
                  label: Text(formatTagLabel(tag)),
                  selected: widget.selected.contains(tag),
                  onSelected: (_) => _toggle(tag),
                  selectedColor: colors.accentMuted,
                  checkmarkColor: colors.accent,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.selected.contains(tag)
                        ? colors.accent
                        : colors.textPrimary,
                  ),
                  side: BorderSide(
                    color: widget.selected.contains(tag)
                        ? colors.accent
                        : colors.border,
                  ),
                ),
              for (final tag in orphanSelected)
                FilterChip(
                  label: Text(formatTagLabel(tag)),
                  selected: true,
                  onSelected: (_) => _toggle(tag),
                  selectedColor: colors.accentMuted,
                  checkmarkColor: colors.accent,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                  side: BorderSide(color: colors.accent),
                ),
            ],
          ),
        if (widget.allowCreate) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _draft,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _createOrSelect(),
                  decoration: InputDecoration(
                    hintText: 'Type a new tag…',
                    prefixText: trimmed.isEmpty && _draft.text.isEmpty
                        ? '# '
                        : null,
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
              ),
              const SizedBox(width: 8),
              Material(
                color: colors.accent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: trimmed.isEmpty || _busy ? null : _createOrSelect,
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      Icons.add_rounded,
                      color: Colors.white.withValues(
                        alpha: trimmed.isEmpty || _busy ? 0.4 : 1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: TextStyle(fontSize: 12, color: colors.error),
          ),
        ],
        if (canCreate) ...[
          const SizedBox(height: 4),
          Text(
            'Press Enter or + to add “${formatTagLabel(trimmed)}” and select it.',
            style: TextStyle(fontSize: 11, color: colors.textMuted),
          ),
        ],
      ],
    );
  }
}
