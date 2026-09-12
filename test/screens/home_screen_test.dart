import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rpboard/screens/home_screen.dart';

/// Confirms the data-transfer entry point is an icon control, not a third
/// `_ModeCard` — `CONTEXT.md` keeps PG Mode and Master Mode as the app's only
/// two faces. A tiny two-route [GoRouter] stands in for the real one so this
/// stays independent of every other screen's dependencies.
void main() {
  testWidgets('the Trasferisci dati icon control navigates to /data-transfer',
      (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/data-transfer',
        builder: (_, _) => const Scaffold(body: Text('DATA TRANSFER SCREEN')),
      ),
      GoRoute(path: '/characters', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(path: '/campaigns', builder: (_, _) => const SizedBox.shrink()),
    ]);
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Trasferisci dati'), findsOneWidget);
    // Not presented as a mode card alongside the other two.
    expect(find.text('Modalità Giocatore'), findsOneWidget);
    expect(find.text('Modalità Master'), findsOneWidget);

    await tester.tap(find.byTooltip('Trasferisci dati'));
    await tester.pumpAndSettle();

    expect(find.text('DATA TRANSFER SCREEN'), findsOneWidget);
  });
}
