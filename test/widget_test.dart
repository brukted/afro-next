import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eyecandy/app/app.dart';
import 'package:eyecandy/app/startup/app_bootstrap.dart';

void main() {
  testWidgets('renders the editor workspace shell', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));

    await tester.pumpWidget(EyecandyApp(bootstrap: AppBootstrap.preview()));
    await tester.pumpAndSettle();

    expect(find.text('Eyecandy'), findsOneWidget);
    expect(find.text('Outliner'), findsOneWidget);
    expect(find.text('Material Editor'), findsOneWidget);
    expect(find.text('Property Editor'), findsOneWidget);
    expect(find.text('Material Graph 1'), findsWidgets);

    await tester.binding.setSurfaceSize(null);
  });
}
