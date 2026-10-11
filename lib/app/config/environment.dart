// Build / runtime environment.

enum Environment { dev, staging, prod }

extension EnvironmentX on Environment {
  String get label => switch (this) {
        Environment.dev => 'dev',
        Environment.staging => 'staging',
        Environment.prod => 'prod',
      };
}
