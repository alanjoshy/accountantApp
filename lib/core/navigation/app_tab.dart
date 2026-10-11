// Main tab ids.

enum AppTab {
  home,
  activity,
  budgets,
  more;

  String get label => switch (this) {
        AppTab.home => 'Home',
        AppTab.activity => 'Activity',
        AppTab.budgets => 'Budgets',
        AppTab.more => 'More',
      };
}
