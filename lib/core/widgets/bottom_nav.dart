// Floating dock bottom bar (web BottomNav).

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
                            return Stack(
                              key: _stackKey,
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
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.heavyImpact();
                  widget.onAddPressed?.call();
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.background, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accent.withValues(alpha: 0.45),
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
          ],
        ),
      ),
    );
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
    return Flexible(
      child: _NavItem(
        itemKey: _itemKeys[tab.index],
        icon: icon,
        label: label,
        active: widget.current == tab,
        showFill: _from == null,
        colors: colors,
        onTap: () => _select(tab),
      ),
    );
  }

  void _select(AppTab tab) {
    HapticFeedback.selectionClick();
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
    required this.showFill,
    required this.colors,
    required this.onTap,
  });

  final GlobalKey itemKey;
  final IconData icon;
  final String label;
  final bool active;
  final bool showFill;
  final AppPalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final target = active ? colors.accent : colors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: FittedBox(
        key: itemKey,
        fit: BoxFit.scaleDown,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: active && showFill ? colors.accentMuted : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    );
  }
}
