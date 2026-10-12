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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top + AppTopBar.height;
    final bottomInset = BottomNav.contentInset(context);

    return Scaffold(
      backgroundColor: backgroundColor ?? colors.background,
      body: Stack(
        children: [
          // Body paints under the dock so the frosted glass has content to blur.
          Positioned.fill(
            child: MediaQuery(
              data: mq.copyWith(
                padding: mq.padding.copyWith(top: 0, bottom: bottomInset),
              ),
              child: Padding(
                padding: EdgeInsets.only(top: topPad),
                child: body,
              ),
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
