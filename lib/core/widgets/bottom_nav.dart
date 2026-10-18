// Floating dock bottom bar (web BottomNav) — scrub + press float + haptics.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../navigation/app_tab.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({
    super.key,
    required this.current,
    required this.onTabSelected,
    this.onAddPressed,
  });

  final AppTab current;
  final ValueChanged<AppTab> onTabSelected;
  final VoidCallback? onAddPressed;

  static const height = 64.0;
  static const outerInset = 16.0;
  /// Raised + button peeks above the bar (Positioned top: -20).
  static const addClearance = 22.0;
  static const motion = Duration(milliseconds: 180);

  /// Gap under the dock — matches web `max(12px, safe-area)`.
  static double bottomGap(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    return safe > 0 ? safe : 12.0;
  }

  /// Space content should leave so the dock doesn’t cover it.
  static double contentInset(BuildContext context) {
    return height + bottomGap(context) + addClearance;
  }

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav>
    with SingleTickerProviderStateMixin {
  final _stackKey = GlobalKey();
  final _itemKeys = List<GlobalKey>.generate(
    AppTab.values.length,
    (_) => GlobalKey(),
  );

  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: BottomNav.motion,
    value: 1,
  );

  Rect? _from;
  Rect? _to;
  double? _width;
  bool _needsPlace = true;
  bool _animateNext = false;

  /// Finger is dragging across the dock.
  bool _scrubbing = false;
  /// Tab under the finger while scrubbing / pressing.
  AppTab? _hoverTab;

  @override
  void didUpdateWidget(BottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current != widget.current) {
      _animateNext = true;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(32);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        BottomNav.outerInset,
        0,
        BottomNav.outerInset,
        BottomNav.bottomGap(context),
      ),
      child: SizedBox(
        height: BottomNav.height,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: dark ? 0.35 : 0.12,
                      ),
                      blurRadius: 32,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated.withValues(
                          alpha: dark ? 0.55 : 0.72,
                        ),
                        borderRadius: radius,
                        border: Border.all(
                          color: colors.border.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            _scheduleMotion(constraints.maxWidth);
                            return Listener(
                              behavior: HitTestBehavior.translucent,
                              onPointerDown: (e) {
                                setState(() => _scrubbing = true);
                                _applyPointer(e.position, isDown: true);
                              },
                              onPointerMove: (e) {
                                if (!_scrubbing) return;
                                _applyPointer(e.position, isDown: false);
                              },
                              onPointerUp: (_) => _endScrub(),
                              onPointerCancel: (_) => _endScrub(),
                              child: Stack(
                                key: _stackKey,
                                clipBehavior: Clip.none,
                                children: [
                                  if (_from != null && _to != null)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: AnimatedBuilder(
                                          animation: _motion,
                                          builder: (context, _) {
                                            final t = Curves.easeOutCubic
                                                .transform(_motion.value);
                                            final rect =
                                                Rect.lerp(_from, _to, t)!;
                                            return CustomPaint(
                                              painter: _PillPainter(
                                                rect,
                                                colors.accentMuted,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _item(
                                              tab: AppTab.home,
                                              icon: Icons.home_rounded,
                                              label: 'Home',
                                              colors: colors,
                                            ),
                                            _item(
                                              tab: AppTab.activity,
                                              icon: Icons.timeline_rounded,
                                              label: 'Activity',
                                              colors: colors,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 56),
                                      Expanded(
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _item(
                                              tab: AppTab.budgets,
                                              icon: Icons.pie_chart_rounded,
                                              label: 'Budgets',
                                              colors: colors,
                                            ),
                                            _item(
                                              tab: AppTab.more,
                                              icon: Icons.grid_view_rounded,
                                              label: 'More',
                                              colors: colors,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -20,
              child: _AddButton(
                colors: colors,
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  widget.onAddPressed?.call();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _endScrub() {
    if (!_scrubbing && _hoverTab == null) return;
    setState(() {
      _scrubbing = false;
      _hoverTab = null;
    });
  }

  void _applyPointer(Offset global, {bool isDown = false}) {
    final tab = _tabAtGlobal(global);
    if (tab == null) return;

    if (_hoverTab != tab) {
      setState(() => _hoverTab = tab);
    }

    if (tab != widget.current) {
      // First contact = tap feel; drag across tabs = light ticks.
      _select(tab, fromScrub: !isDown);
    } else if (isDown) {
      HapticFeedback.selectionClick();
    }
  }

  AppTab? _tabAtGlobal(Offset global) {
    for (final tab in AppTab.values) {
      final itemContext = _itemKeys[tab.index].currentContext;
      if (itemContext == null) continue;
      final box = itemContext.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final origin = box.localToGlobal(Offset.zero);
      // Slightly taller hit target for easier scrubbing.
      final rect = (origin & box.size).inflate(10);
      if (rect.contains(global)) return tab;
    }
    return null;
  }

  void _scheduleMotion(double width) {
    final widthChanged = _width != null && _width != width;
    final place = _needsPlace;
    final animate = _animateNext;
    _width = width;
    if (!place && !animate && !widthChanged) return;

    _needsPlace = false;
    _animateNext = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _moveTo(widget.current, animate: animate && !place);
    });
  }

  Widget _item({
    required AppTab tab,
    required IconData icon,
    required String label,
    required AppPalette colors,
  }) {
    final active = widget.current == tab;
    final hovering = _hoverTab == tab;
    return Flexible(
      child: _NavItem(
        itemKey: _itemKeys[tab.index],
        icon: icon,
        label: label,
        active: active,
        lifted: active || hovering,
        pressed: hovering && _scrubbing,
        showFill: _from == null,
        colors: colors,
        onTap: () => _select(tab, fromScrub: false),
      ),
    );
  }

  void _select(AppTab tab, {required bool fromScrub}) {
    if (tab == widget.current) return;
    if (fromScrub) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.mediumImpact();
    }
    widget.onTabSelected(tab);
  }

  void _moveTo(AppTab tab, {required bool animate}) {
    final next = _rectFor(tab);
    if (next == null) return;

    final reduce = MediaQuery.disableAnimationsOf(context);
    final from = (!animate || reduce) ? next : (_displayed() ?? next);
    setState(() {
      _from = from;
      _to = next;
    });

    if (!animate || reduce || _near(from, next)) {
      _motion.value = 1;
      return;
    }

    final distance = (from.center - next.center).distance;
    final ms = (140 + distance * 0.12).clamp(160, 240).round();
    _motion.duration = Duration(milliseconds: ms);
    _motion.forward(from: 0);
  }

  Rect? _displayed() {
    if (_from == null || _to == null) return _to ?? _from;
    final t = Curves.easeOutCubic.transform(_motion.value);
    return Rect.lerp(_from, _to, t);
  }

  Rect? _rectFor(AppTab tab) {
    final itemContext = _itemKeys[tab.index].currentContext;
    final stackContext = _stackKey.currentContext;
    if (itemContext == null || stackContext == null) return null;

    final itemBox = itemContext.findRenderObject() as RenderBox?;
    final stackBox = stackContext.findRenderObject() as RenderBox?;
    if (itemBox == null ||
        stackBox == null ||
        !itemBox.hasSize ||
        !stackBox.hasSize) {
      return null;
    }

    final offset = itemBox.localToGlobal(Offset.zero, ancestor: stackBox);
    return offset & itemBox.size;
  }

  bool _near(Rect a, Rect b) {
    return (a.left - b.left).abs() < 0.5 &&
        (a.top - b.top).abs() < 0.5 &&
        (a.width - b.width).abs() < 0.5 &&
        (a.height - b.height).abs() < 0.5;
  }
}

class _AddButton extends StatefulWidget {
  const _AddButton({required this.colors, required this.onPressed});

  final AppPalette colors;
  final VoidCallback onPressed;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.03,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Transform.translate(
          offset: Offset(0, _pressed ? 0 : -2),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: widget.colors.accent,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.of(context).background,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.colors.accent.withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_rounded,
              color: AppColors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _PillPainter extends CustomPainter {
  const _PillPainter(this.rect, this.color);

  final Rect rect;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(18)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _PillPainter oldDelegate) =>
      oldDelegate.rect != rect || oldDelegate.color != color;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.itemKey,
    required this.icon,
    required this.label,
    required this.active,
    required this.lifted,
    required this.pressed,
    required this.showFill,
    required this.colors,
    required this.onTap,
  });

  final GlobalKey itemKey;
  final IconData icon;
  final String label;
  final bool active;
  final bool lifted;
  final bool pressed;
  final bool showFill;
  final AppPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final target = active ? colors.accent : colors.textMuted;
    final dy = reduce ? 0.0 : (pressed ? -1.0 : (lifted ? -2.5 : 0.0));
    final scale = reduce ? 1.0 : (pressed ? 0.94 : (lifted ? 1.04 : 1.0));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: dy),
        duration: reduce ? Duration.zero : const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        builder: (context, offsetY, child) {
          return Transform.translate(
            offset: Offset(0, offsetY),
            child: child,
          );
        },
        child: AnimatedScale(
          scale: scale,
          duration: reduce ? Duration.zero : const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: FittedBox(
            key: itemKey,
            fit: BoxFit.scaleDown,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: active && showFill
                    ? colors.accentMuted
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: target),
                  duration: reduce ? Duration.zero : BottomNav.motion,
                  curve: Curves.easeOutCubic,
                  builder: (context, color, _) {
                    final ink = color ?? target;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 22, color: ink),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: ink,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
