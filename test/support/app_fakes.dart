import 'package:readflex/app/config/application_config.dart';
import 'package:readflex/app/dependency_container.dart';

/// Partial test doubles fail loudly on unexpected dependency access.
base class TestDependenciesContainer implements DependenciesContainer {
  const TestDependenciesContainer();

  @override
  Object noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'Provide ${invocation.memberName} in the test dependencies.',
  );
}

base class TestConfig implements ApplicationConfig {
  const TestConfig();

  @override
  Object noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'Provide ${invocation.memberName} in the test configuration.',
  );
}
