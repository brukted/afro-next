import 'dart:ui';

import 'package:eyecandy/features/graph/models/graph_schema.dart';
import 'package:eyecandy/features/node_editor/node_editor_canvas.dart';
import 'package:eyecandy/features/node_editor/node_editor_models.dart';
import 'package:eyecandy/features/node_editor/node_editor_viewport.dart';
import 'package:flutter/gestures.dart';
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
            child: NodeEditorCanvas<String>(
              nodes: [
                NodeEditorNodeViewModel<String>(
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
            child: NodeEditorCanvas<Object?>(
              nodes: [
                NodeEditorNodeViewModel<Object?>(
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
                      valueType: GraphValueType.float,
                    ),
                  ],
                ),
                NodeEditorNodeViewModel<Object?>(
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
                      valueType: GraphValueType.float,
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

  testWidgets('requests the canvas context menu with scene coordinates', (
    WidgetTester tester,
  ) async {
    final viewportController = NodeEditorViewportController(
      initialScale: 2,
      initialTranslation: const Offset(20, 40),
    );
    Offset? requestedGlobalPosition;
    Offset? requestedScenePosition;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: NodeEditorCanvas<Object?>(
              viewportController: viewportController,
              nodes: const <NodeEditorNodeViewModel<Object?>>[],
              links: const [],
              selectedNodeId: null,
              pendingPropertyId: null,
              onSelectNode: (_) {},
              onSetNodePosition: (_, _) {},
              onSocketTap: (_, _) {},
              onCancelPendingConnection: () {},
              onRequestCanvasMenu: (globalPosition, scenePosition) async {
                requestedGlobalPosition = globalPosition;
                requestedScenePosition = scenePosition;
              },
            ),
          ),
        ),
      ),
    );

    const localPoint = Offset(300, 220);
    await _secondaryClickAt(tester, localPoint);

    expect(requestedGlobalPosition, isNotNull);
    expect(requestedScenePosition, isNotNull);
    expect(requestedScenePosition!.dx, moreOrLessEquals(140, epsilon: 0.01));
    expect(requestedScenePosition!.dy, moreOrLessEquals(90, epsilon: 0.01));
  });

  testWidgets('requests the node context menu for the clicked node', (
    WidgetTester tester,
  ) async {
    String? requestedNodeId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: NodeEditorCanvas<Object?>(
              nodes: [
                NodeEditorNodeViewModel<Object?>(
                  id: 'node-ctx',
                  title: 'Context Node',
                  position: Vector2(80, 80),
                  icon: Icons.account_tree_outlined,
                  accentColor: const Color(0xFF7D67FF),
                  sockets: const [],
                ),
              ],
              links: const [],
              selectedNodeId: null,
              pendingPropertyId: null,
              onSelectNode: (_) {},
              onSetNodePosition: (_, _) {},
              onSocketTap: (_, _) {},
              onCancelPendingConnection: () {},
              onRequestNodeMenu: (node, _) async {
                requestedNodeId = node.id;
              },
            ),
          ),
        ),
      ),
    );

    await _secondaryClick(tester, find.byIcon(Icons.drag_indicator));

    expect(requestedNodeId, 'node-ctx');
  });

  testWidgets('requests the socket context menu for the clicked socket', (
    WidgetTester tester,
  ) async {
    String? requestedNodeId;
    String? requestedSocketId;
    String? nodeMenuRequest;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: NodeEditorCanvas<Object?>(
              nodes: [
                NodeEditorNodeViewModel<Object?>(
                  id: 'node-socket-ctx',
                  title: 'Socket Context Node',
                  position: Vector2(80, 80),
                  icon: Icons.account_tree_outlined,
                  accentColor: const Color(0xFF7D67FF),
                  sockets: const [
                    NodeEditorSocketViewModel(
                      id: 'socket-ctx',
                      label: 'Output',
                      direction: GraphSocketDirection.output,
                      valueType: GraphValueType.float,
                      isConnected: true,
                    ),
                  ],
                ),
              ],
              links: const [],
              selectedNodeId: null,
              pendingPropertyId: null,
              onSelectNode: (_) {},
              onSetNodePosition: (_, _) {},
              onSocketTap: (_, _) {},
              onCancelPendingConnection: () {},
              onRequestNodeMenu: (node, _) async {
                nodeMenuRequest = node.id;
              },
              onRequestSocketMenu: (node, socket, _) async {
                requestedNodeId = node.id;
                requestedSocketId = socket.id;
              },
            ),
          ),
        ),
      ),
    );

    await _secondaryClick(tester, find.text('Output'));

    expect(requestedNodeId, 'node-socket-ctx');
    expect(requestedSocketId, 'socket-ctx');
    expect(nodeMenuRequest, isNull);
  });

  test('focusSceneRect centers the target rect', () {
    final controller = NodeEditorViewportController();
    const viewportSize = Size(800, 600);
    const rect = Rect.fromLTWH(100, 120, 240, 120);

    controller.focusSceneRect(
      sceneRect: rect,
      viewportSize: viewportSize,
    );

    final center = controller.sceneToScreen(rect.center);
    expect(center.dx, moreOrLessEquals(viewportSize.width / 2, epsilon: 0.01));
    expect(center.dy, moreOrLessEquals(viewportSize.height / 2, epsilon: 0.01));
    expect(controller.scale, greaterThan(1));
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
    return NodeEditorCanvas<Object?>(
      viewportController: widget.viewportController,
      nodes: [
        NodeEditorNodeViewModel<Object?>(
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
              valueType: GraphValueType.float,
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
