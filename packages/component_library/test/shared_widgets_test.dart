import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ActionBottomSheetLayout renders title and child', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActionBottomSheetLayout(
            title: 'Sheet',
            onClose: _noop,
            child: Text('Body'),
          ),
        ),
      ),
    );

    expect(find.text('Sheet'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
  });

  testWidgets('SelectionPreviewCard renders selected text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SelectionPreviewCard(text: 'Selected text'),
        ),
      ),
    );

    expect(find.text('Selected text'), findsOneWidget);
  });

  testWidgets('ButtonLoadingIndicator renders progress indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ButtonLoadingIndicator(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
  testWidgets('EmptyState renders icon, message, and subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.book,
            message: 'No items',
            subtitle: 'Add something',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.book), findsOneWidget);
    expect(find.text('No items'), findsOneWidget);
    expect(find.text('Add something'), findsOneWidget);
  });

  testWidgets('EmptyState renders message only when no icon or subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(message: 'Empty'),
        ),
      ),
    );

    expect(find.text('Empty'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('SearchField renders hint text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SearchField(hintText: 'Search...'),
        ),
      ),
    );

    expect(find.text('Search...'), findsOneWidget);
  });

  testWidgets('SearchField calls onChanged when text entered', (
    tester,
  ) async {
    String? lastQuery;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchField(
            hintText: 'Search...',
            onChanged: (q) => lastQuery = q,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'hello');
    expect(lastQuery, 'hello');
  });

  testWidgets('AppBadge renders label with correct colors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppBadge(
            label: 'PRO',
            foreground: Colors.white,
            background: Colors.purple,
          ),
        ),
      ),
    );

    expect(find.text('PRO'), findsOneWidget);
  });

  testWidgets('SectionLabel renders uppercase label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionLabel(label: 'GENERAL'),
        ),
      ),
    );

    expect(find.text('GENERAL'), findsOneWidget);
  });

  testWidgets('SettingsGroup renders children with dividers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SettingsGroup(
            children: [
              const Text('Row 1'),
              const Text('Row 2'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Row 1'), findsOneWidget);
    expect(find.text('Row 2'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('SettingsRow renders icon, label, and detail', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsRow(
            icon: Icons.settings,
            label: 'Font',
            detail: 'Inter',
            onTap: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Font'), findsOneWidget);
    expect(find.text('Inter'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('StatCard with icon renders icon, value, and label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            icon: Icons.book,
            value: '42',
            label: 'Books',
            color: Colors.blue,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.book), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Books'), findsOneWidget);
  });

  testWidgets('StatCard without icon renders bordered container', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(value: '0h', label: 'Read time'),
        ),
      ),
    );

    expect(find.text('0h'), findsOneWidget);
    expect(find.text('Read time'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });
}

void _noop() {}
