import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_screen.dart';
import 'package:reader/src/reader_ui_cubit.dart';
import 'package:screen_control_service/screen_control_service.dart';

void main() {
  testWidgets('keeps screen awake while content-only mode is active', (
    tester,
  ) async {
    final service = _FakeScreenControlService();

    await tester.pumpWidget(
      ReaderKeepAwakeScope(
        active: true,
        screenControlService: service,
        child: const SizedBox.shrink(),
      ),
    );
    await tester.pump();

    expect(service.calls, const ['keepAwake']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(service.calls, const ['keepAwake', 'allowSleep']);
  });

  testWidgets('releases screen awake when content-only mode ends', (
    tester,
  ) async {
    final service = _FakeScreenControlService();

    await tester.pumpWidget(
      ReaderKeepAwakeScope(
        active: true,
        screenControlService: service,
        child: const SizedBox.shrink(),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      ReaderKeepAwakeScope(
        active: false,
        screenControlService: service,
        child: const SizedBox.shrink(),
      ),
    );
    await tester.pump();

    expect(service.calls, const ['keepAwake', 'allowSleep']);
  });

  testWidgets('does not keep screen awake while controls are visible', (
    tester,
  ) async {
    final service = _FakeScreenControlService();
    final uiCubit = ReaderUiCubit();
    addTearDown(uiCubit.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: uiCubit,
        child: ReaderKeepAwakeDriver(
          screenControlService: service,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    uiCubit.showChrome();
    await tester.pumpAndSettle();

    uiCubit.hideChrome();
    await tester.pumpAndSettle();

    uiCubit.openSearchDrawer();
    await tester.pumpAndSettle();

    expect(
      service.calls,
      const ['keepAwake', 'allowSleep', 'keepAwake', 'allowSleep'],
    );
  });

  testWidgets('releases in background and re-enables on resume', (
    tester,
  ) async {
    final service = _FakeScreenControlService();

    await tester.pumpWidget(
      ReaderKeepAwakeScope(
        active: true,
        screenControlService: service,
        child: const SizedBox.shrink(),
      ),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(service.calls, const ['keepAwake', 'allowSleep', 'keepAwake']);
  });
}

class _FakeScreenControlService implements ScreenControlService {
  final List<String> calls = [];

  @override
  Future<void> keepAwake() async {
    calls.add('keepAwake');
  }

  @override
  Future<void> allowSleep() async {
    calls.add('allowSleep');
  }
}
