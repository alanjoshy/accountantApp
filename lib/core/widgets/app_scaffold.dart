// Page shell with shared bottom nav.

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../navigation/app_tab.dart';
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

  @override
  Widget build(BuildContext context) {
    final bottomPad = BottomNav.height +
        BottomNav.outerInset +
        28 +
        MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPad),
              child: body,
            ),
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
