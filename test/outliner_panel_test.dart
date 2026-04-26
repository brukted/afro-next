import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:afro/app/theme/app_theme.dart';
import 'package:afro/features/outliner/outliner_panel.dart';
import 'package:afro/features/workspace/workspace_controller.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('expands and collapses folder rows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 720));
    final controller = WorkspaceController.preview()..initializeForPreview();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: OutlinerPanel(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Material Graph 1'), findsOneWidget);
    expect(find.text('Math Graph 1'), findsNothing);

    await tester.tap(find.text('Math'));
    await tester.pumpAndSettle();
    expect(find.text('Math Graph 1'), findsOneWidget);

    await tester.tap(find.text('Math'));
    await tester.pumpAndSettle();
    expect(find.text('Math Graph 1'), findsNothing);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('shows folder and background context menus', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 720));
    final controller = WorkspaceController.preview()..initializeForPreview();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: OutlinerPanel(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _secondaryClick(tester, find.text('Materials'));
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Material Graph'), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    final listRect = tester.getRect(find.byType(ListView));
    final backgroundPoint = Offset(listRect.left + 24, listRect.bottom - 24);
    await _secondaryClickAt(tester, backgroundPoint);
    expect(find.text('Import Image'), findsOneWidget);
    expect(find.text('Import SVG'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);
    expect(find.text('Folder'), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    await _secondaryClick(tester, find.text('Material Graph 1'));
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Rename'), findsOneWidget);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('clicking a resource selects it without opening it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 720));
    final controller = WorkspaceController.preview()..initializeForPreview();
    final initiallyOpenedId = controller.openedResourceId;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: OutlinerPanel(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Math'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Math Graph 1'));
    await tester.pumpAndSettle();

    expect(controller.selectedResource?.name, 'Math Graph 1');
    expect(controller.openedResourceId, initiallyOpenedId);

    await tester.binding.setSurfaceSize(null);
  });
}

Future<void> _secondaryClick(WidgetTester tester, Finder finder) async {
  await _secondaryClickAt(tester, tester.getCenter(finder));
}

Future<void> _secondaryClickAt(WidgetTester tester, Offset point) async {
  final gesture = await tester.startGesture(
    point,
    buttons: kSecondaryMouseButton,
    kind: PointerDeviceKind.mouse,
  );
  await gesture.up();
  await tester.pumpAndSettle();
}
