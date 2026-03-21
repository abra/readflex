// DI container: holds all application-wide dependencies as a plain data class.
//
// Passed down the widget tree via DependenciesScope instead of using global
// singletons or a service locator. This keeps dependencies explicit and makes
// them easy to substitute in tests via TestDependenciesContainer.

import 'package:nota/app/config/application_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Container for global dependencies.
class DependenciesContainer {
  const DependenciesContainer({
    required this.logger,
    required this.config,
    required this.errorReporter,
    required this.packageInfo,
  });

  final Logger logger;
  final ApplicationConfig config;
  final ErrorReportingService errorReporter;
  final PackageInfo packageInfo;
}

/// A special version of [DependenciesContainer] that is used in tests.
///
/// In order to use [DependenciesContainer] in tests, it is needed to
/// extend this class and provide the dependencies that are needed for the test.
base class TestDependenciesContainer implements DependenciesContainer {
  const TestDependenciesContainer();

  @override
  Object noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'The test tries to access ${invocation.memberName} dependency, but '
      'it was not provided. Please provide the dependency in the test. '
      'You can do it by extending this class and providing the dependency.',
    );
  }
}
