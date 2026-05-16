// Top-anchored toast notifications, exposed as a thin wrapper over
// `toastification`. Feature packages should call showToast from
// `package:toast_service/toast_service.dart` and never import the
// underlying library directly — that keeps the swap surface minimal.

export 'src/toast_service.dart';
export 'src/toast_wrapper.dart';
