// Tab host — pages inherit bottom nav via AppScaffold.

import 'package:flutter/material.dart';

import '../../../../core/navigation/app_tab.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../activity/presentation/screens/activity_screen.dart';
import '../../../budgets/presentation/screens/budgets_screen.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../more/presentation/screens/more_screen.dart';
import '../../../transactions/presentation/widgets/add_transaction_sheet.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTab = AppTab.home});

  final AppTab initialTab;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  static const _pages = <Widget>[
    HomeScreen(),
    ActivityScreen(),
    BudgetsScreen(),
    MoreScreen(),
  ];

  static const _duration = Duration(milliseconds: 230);
  static const _slide = 16.0;

  late AppTab _tab = widget.initialTab;
  late AppTab _previous = widget.initialTab;
  int _direction = 1;

  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: _duration,
    value: 1,
  )..addStatusListener(_onMotion);

  void _onMotion(AnimationStatus status) {
    if (status == AnimationStatus.completed && _previous != _tab && mounted) {
      setState(() => _previous = _tab);
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _select(AppTab tab) {
    if (tab == _tab) return;

    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      setState(() {
        _tab = tab;
        _previous = tab;
      });
      _motion.value = 1;
      return;
    }

    setState(() {
      _direction = tab.index > _tab.index ? 1 : -1;
      _previous = _tab;
      _tab = tab;
    });
    _motion.forward(from: 0);
  }

  void _onAdd() {
    showAddTransactionSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      tab: _tab,
      onTabSelected: _select,
      onAddPressed: _onAdd,
      body: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final tab in AppTab.values)
              _TabPageSlot(
                tab: tab,
                current: _tab,
                previous: _previous,
                direction: _direction,
                motion: _motion,
                slide: _slide,
                child: _pages[tab.index],
              ),
          ],
        ),
      ),
    );
  }
}

/// Keeps tab [State] alive via [Offstage], but only listens to [motion]
/// while that tab is entering or leaving — settled tabs skip per-frame rebuilds.
class _TabPageSlot extends StatelessWidget {
  const _TabPageSlot({
    required this.tab,
    required this.current,
    required this.previous,
    required this.direction,
    required this.motion,
    required this.slide,
    required this.child,
  });

  final AppTab tab;
  final AppTab current;
  final AppTab previous;
  final int direction;
  final AnimationController motion;
  final double slide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selected = tab == current;
    final leaving = tab == previous && previous != current;
    final hidden = !selected && !leaving;
    final settled = previous == current;

    final page = TickerMode(
      enabled: !hidden,
      child: ExcludeSemantics(
        excluding: !selected,
        child: child,
      ),
    );

    if (hidden || settled) {
      return Offstage(
        key: ValueKey(tab),
        offstage: hidden,
        child: IgnorePointer(
          ignoring: !selected,
          child: page,
        ),
      );
    }

    return AnimatedBuilder(
      key: ValueKey(tab),
      animation: motion,
      child: page,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(motion.value);
        // Keep a floor on opacity so hit-testing never fully “ghosts” mid-fade.
        final opacity = (selected ? t : 1 - t).clamp(0.0, 1.0);
        final dx = selected
            ? slide * direction * (1 - t)
            : -slide * direction * t;

        return Offstage(
          offstage: false,
          child: IgnorePointer(
            ignoring: !selected,
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
