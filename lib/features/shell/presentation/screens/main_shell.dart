// Tab host — pages inherit bottom nav via AppScaffold.

import 'package:flutter/material.dart';

import '../../../../core/navigation/app_tab.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../activity/presentation/screens/activity_screen.dart';
import '../../../budgets/presentation/screens/budgets_screen.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../more/presentation/screens/more_screen.dart';

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

  static const _duration = Duration(milliseconds: 180);
  static const _slide = 12.0;

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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      tab: _tab,
      onTabSelected: _select,
      onAddPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add transaction coming soon.')),
        );
      },
      body: ClipRect(
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_motion.value);
            return Stack(
              fit: StackFit.expand,
              children: [
                for (final tab in AppTab.values) _page(tab, t),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _page(AppTab tab, double t) {
    final selected = tab == _tab;
    final leaving = tab == _previous && _previous != _tab;
    final hidden = !selected && !leaving;
    final settled = _previous == _tab;
    final opacity = selected
        ? (settled ? 1.0 : t)
        : leaving
            ? 1 - t
            : 0.0;
    final dx = hidden || settled
        ? 0.0
        : selected
            ? _slide * _direction * (1 - t)
            : -_slide * _direction * t;

    return Offstage(
      key: ValueKey(tab),
      offstage: hidden,
      child: IgnorePointer(
        ignoring: !selected,
        child: Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: TickerMode(
              enabled: !hidden,
              child: ExcludeSemantics(
                excluding: !selected,
                child: _pages[tab.index],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
