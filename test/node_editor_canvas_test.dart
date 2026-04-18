import 'package:eyecandy/features/graph/models/graph_schema.dart';
import 'package:eyecandy/features/node_editor/node_editor_canvas.dart';
import 'package:eyecandy/features/node_editor/node_editor_models.dart';
import 'package:eyecandy/features/node_editor/node_editor_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' show Vector2;

void main() {
  testWidgets('renders a feature-provided node body', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: NodeEditorCanvas(
              nodes: [
                NodeEditorNodeViewModel(
                  id: 'node-1',
                  title: 'Material Node',
                  position: Vector2(80, 80),
                  icon: Icons.account_tree_outlined,
                  accentColor: const Color(0xFF7D67FF),
                  bodyData: 'material-body',
                  sockets: const [],
                ),
              ],
              links: const [],
              selectedNodeId: null,
              pendingPropertyId: null,
              onSelectNode: (_) {},
              onSetNodePosition: (_, position) {},
              onSocketTap: (_, propertyId) {},
              onCancelPendingConnection: () {},
              buildNodeBody: (context, node) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.blueGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text('Body: ${node.bodyData}'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Body: material-body'), findsOneWidget);
  });

  testWidgets('keeps node dragging in sync when zoomed', (
    WidgetTester tester,
  ) async {
    final viewportController = NodeEditorViewportController(
      initialScale: 2,
      initialTranslation: Offset.zero,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: _NodeEditorDragHarness(
              viewportController: viewportController,
            ),
          ),
        ),
      ),
    );

    final dragHandleFinder = find.byIcon(Icons.drag_indicator);
    final initialPosition = tester.getCenter(dragHandleFinder);

    final gesture = await tester.startGesture(initialPosition);
    await gesture.moveBy(const Offset(30, 20));
    await tester.pump();

    final lockedPosition = tester.getCenter(dragHandleFinder);
    await gesture.moveBy(const Offset(80, 40));
    await tester.pump();
    await gesture.up();

    final updatedPosition = tester.getCenter(dragHandleFinder);
    expect(
      updatedPosition.dx - lockedPosition.dx,
      moreOrLessEquals(80, epsilon: 0.5),
    );
    expect(
      updatedPosition.dy - lockedPosition.dy,
      moreOrLessEquals(40, epsilon: 0.5),
    );
  });

  testWidgets('positions sockets using the configured body height', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 600,
            child: NodeEditorCanvas(
              nodes: [
                NodeEditorNodeViewModel(
                  id: 'node-small',
                  title: 'Small Node',
                  position: Vector2(80, 80),
                  icon: Icons.blur_on_outlined,
                  accentColor: const Color(0xFF3DD6B0),
                  bodyHeight: 96,
                  sockets: const [
                    NodeEditorSocketViewModel(
                      id: 'socket-small',
                      label: 'Small Output',
                      direction: GraphSocketDirection.output,
                    ),
                  ],
                ),
                NodeEditorNodeViewModel(
                  id: 'node-large',
                  title: 'Large Node',
                  position: Vector2(400, 80),
                  icon: Icons.blur_on_outlined,
                  accentColor: const Color(0xFF7D67FF),
                  bodyHeight: 160,
                  sockets: const [
                    NodeEditorSocketViewModel(
                      id: 'socket-large',
                      label: 'Large Output',
                      direction: GraphSocketDirection.output,
                    ),
                  ],
                ),
              ],
              links: const [],
              selectedNodeId: null,
              pendingPropertyId: null,
              onSelectNode: (_) {},
              onSetNodePosition: (_, position) {},
              onSocketTap: (_, propertyId) {},
              onCancelPendingConnection: () {},
              buildNodeBody: (context, node) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.blueGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    final smallSocketPosition = tester.getCenter(find.text('Small Output'));
    final largeSocketPosition = tester.getCenter(find.text('Large Output'));

    expect(
      largeSocketPosition.dy - smallSocketPosition.dy,
      moreOrLessEquals(64, epsilon: 1),
    );
  });
}

class _NodeEditorDragHarness extends StatefulWidget {
  const _NodeEditorDragHarness({
    required this.viewportController,
  });

  final NodeEditorViewportController viewportController;

  @override
  State<_NodeEditorDragHarness> createState() => _NodeEditorDragHarnessState();
}

class _NodeEditorDragHarnessState extends State<_NodeEditorDragHarness> {
  Vector2 _position = Vector2(100, 100);

  @override
  Widget build(BuildContext context) {
    return NodeEditorCanvas(
      viewportController: widget.viewportController,
      nodes: [
        NodeEditorNodeViewModel(
          id: 'node-1',
          title: 'Node 1',
          position: _position,
          icon: Icons.blur_on_outlined,
          accentColor: const Color(0xFF3DD6B0),
          sockets: const [
            NodeEditorSocketViewModel(
              id: 'socket-1',
              label: 'Output',
              direction: GraphSocketDirection.output,
            ),
          ],
        ),
      ],
      links: const [],
      selectedNodeId: 'node-1',
      pendingPropertyId: null,
      onSelectNode: (_) {},
      onSetNodePosition: (_, position) {
        setState(() {
          _position = position;
        });
      },
      onSocketTap: (_, propertyId) {},
      onCancelPendingConnection: () {},
    );
  }
}
