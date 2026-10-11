// Page shell with shared top bar + bottom nav.

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../navigation/app_tab.dart';
import 'app_top_bar.dart';
import 'bottom_nav.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.tab,
    required this.body,
    required this.onTabSelected,
    this.onAddPressed,
    this.backgroundColor,
  });

  final AppTab tab;
  final Widget body;
  final ValueChanged<AppTab> onTabSelected;
  final VoidCallback? onAddPressed;
  final Color? backgroundColor;

  /// Clearance for the dock’s raised + button (extends above the bar).
  static const _addButtonClearance = 28.0;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final topPad = MediaQuery.paddingOf(context).top + AppTopBar.height;
    final bottomPad = BottomNav.height +
        BottomNav.outerInset +
        _addButtonClearance +
        MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: backgroundColor ?? colors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: topPad, bottom: bottomPad),
              child: body,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: AppTopBar(tab: tab),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNav(
              current: tab,
              onTabSelected: onTabSelected,
              onAddPressed: onAddPressed,
            ),
          ),
        ],
      ),
    );
  }
}
