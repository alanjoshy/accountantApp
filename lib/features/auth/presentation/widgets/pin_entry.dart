// PIN dots + system numeric keypad.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

class PinEntry extends StatefulWidget {
  const PinEntry({
    super.key,
    required this.value,
    required this.onChanged,
    this.maxLength = 6,
    this.disabled = false,
    this.error = false,
    this.hint,
    this.errorMessage,
    this.autoFocus = true,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final int maxLength;
  final bool disabled;
  final bool error;
  final String? hint;
  final String? errorMessage;
  final bool autoFocus;

  @override
  State<PinEntry> createState() => _PinEntryState();
}

class _PinEntryState extends State<PinEntry> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    if (widget.autoFocus && !widget.disabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant PinEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.maxLength, (i) {
                  final filled = i < widget.value.length;
                  final Color border;
                  final Color fill;
                  if (widget.error) {
                    border = filled
                        ? colors.error
                        : colors.error.withValues(alpha: 0.5);
                    fill = filled ? colors.error : Colors.transparent;
                  } else if (filled) {
                    border = colors.accent;
                    fill = colors.accent;
                  } else {
                    border = colors.border;
                    fill = colors.surfaceHover;
                  }

                  return Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fill,
                      border: Border.all(color: border, width: 2),
                    ),
                  );
                }),
              ),
              Opacity(
                opacity: 0,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !widget.disabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.maxLength),
                  ],
                  onChanged: (next) {
                    if (next.length > widget.value.length) {
                      HapticFeedback.lightImpact();
                    }
                    widget.onChanged(next);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (widget.errorMessage != null)
          Text(
            widget.errorMessage!,
            style: AppTextStyles.error.copyWith(color: colors.error),
          )
        else if (widget.hint != null)
          Text(
            widget.hint!,
            style: AppTextStyles.hint.copyWith(color: colors.textMuted),
          ),
      ],
    );
  }
}
