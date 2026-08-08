import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/reader.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:shared/shared.dart';
import 'package:toast_service/toast_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('copies the exact selection rather than normalized text', (
    tester,
  ) async {
    MethodCall? clipboardCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') clipboardCall = call;
          return null;
        });
    final action = CopyTextAction();
    await tester.pumpWidget(
      ToastWrapper(
        child: MaterialApp(
          supportedLocales: ReadflexSupportedLocales.locales,
          localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => action.onExecute(context, _selection),
                child: const Text('Copy selection'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Copy selection'));
    await tester.pump();

    expect(clipboardCall?.arguments, {'text': 'pow'});

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}

const _selection = TextSelectionContext(
  selectedText: 'pow',
  normalizedSelectedText: 'power',
  sourceId: 'source-1',
  sourceType: SourceType.article,
);
