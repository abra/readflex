/// Reactive network-connectivity status for UI (offline banner, disabled
/// buttons) with a real implementation on top of `connectivity_plus` and a
/// Noop stub for unit-test composition. Services never consume connectivity
/// directly — they try the network and handle failures.
library;

export 'src/connectivity_plus_service.dart';
export 'src/connectivity_scope.dart';
export 'src/connectivity_service.dart';
