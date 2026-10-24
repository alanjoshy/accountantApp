// Named route paths — kept separate from [AppRouter] widgets so lock tests
// do not import MainShell.

class AppRoutes {
  AppRoutes._();

  static const lock = '/lock';
  static const home = '/home';
}
