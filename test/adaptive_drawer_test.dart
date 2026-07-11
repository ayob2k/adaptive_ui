import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adaptive_ui/adaptive_ui.dart';

void main() {
  group('AdaptiveDrawer', () {
    testWidgets('renders child content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AdaptiveDrawer(
            child: Text('Drawer Content'),
          ),
        ),
      );

      expect(find.text('Drawer Content'), findsOneWidget);
    });

    testWidgets('wraps content in a Drawer widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AdaptiveDrawer(child: SizedBox()),
        ),
      );

      expect(find.byType(Drawer), findsOneWidget);
    });

    testWidgets('opens and shows content inside AdaptiveScaffold', (
      tester,
    ) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveScaffold(
            scaffoldKey: scaffoldKey,
            drawer: const AdaptiveDrawer(
              child: Text('Drawer Content'),
            ),
            body: const Text('Body'),
          ),
        ),
      );

      expect(find.text('Drawer Content'), findsNothing);

      final scaffoldState = tester.firstState<ScaffoldState>(
        find.byType(Scaffold),
      );
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Drawer Content'), findsOneWidget);
    });

    testWidgets('closes when item tapped', (tester) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveScaffold(
            scaffoldKey: scaffoldKey,
            drawer: AdaptiveDrawer(
              child: ListTile(
                title: const Text('Item'),
                onTap: () => Navigator.pop(
                  scaffoldKey.currentState!.context,
                ),
              ),
            ),
            body: const Text('Body'),
          ),
        ),
      );

      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Item'), findsOneWidget);

      await tester.tap(find.text('Item'));
      await tester.pumpAndSettle();

      expect(find.text('Item'), findsNothing);
    });

    testWidgets('respects custom width', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AdaptiveDrawer(
            width: 200,
            child: SizedBox(),
          ),
        ),
      );

      final drawer = tester.widget<Drawer>(find.byType(Drawer));
      expect(drawer.width, 200);
    });
  });

  group('AdaptiveDrawerHeader', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveDrawerHeader(title: 'My App'),
          ),
        ),
      );

      expect(find.text('My App'), findsOneWidget);
    });

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveDrawerHeader(
              title: 'My App',
              subtitle: 'v1.0',
            ),
          ),
        ),
      );

      expect(find.text('My App'), findsOneWidget);
      expect(find.text('v1.0'), findsOneWidget);
    });

    testWidgets('renders leading widget when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveDrawerHeader(
              title: 'My App',
              leading: Icon(Icons.home, key: Key('leading-icon')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('leading-icon')), findsOneWidget);
    });

    testWidgets('no subtitle when not provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdaptiveDrawerHeader(title: 'Title Only'),
          ),
        ),
      );

      expect(find.text('Title Only'), findsOneWidget);
      // Only one text widget (the title)
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('renders inside AdaptiveDrawer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AdaptiveDrawer(
            child: Column(
              children: [
                AdaptiveDrawerHeader(title: 'Header'),
                Text('Content'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Header'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });
  });
}
