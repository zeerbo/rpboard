import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/models/component.dart';
import 'package:rpboard/screens/master/session/components/component_view.dart';
import 'package:rpboard/screens/master/session/components/narrative_widget.dart';
import 'package:rpboard/screens/master/session/components/npc_stat_block_widget.dart';
import 'package:rpboard/screens/master/session/components/initiative_tracker_widget.dart';
import 'package:rpboard/screens/master/session/components/custom_table_widget.dart';
import 'package:rpboard/screens/master/session/components/image_widget.dart';

SessionComponent _component(ComponentData data) => SessionComponent(
      id: 'c1',
      screenId: 's1',
      order: 0,
      data: data,
    );

Future<void> _pump(
  WidgetTester tester,
  ComponentData data, {
  required bool isEditMode,
  Future<void> Function(SessionComponent)? onUpdate,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ComponentView(
          component: _component(data),
          isEditMode: isEditMode,
          onUpdate: onUpdate ?? (_) async {},
        ),
      ),
    ),
  );
}

void main() {
  group('ComponentView dispatch', () {
    testWidgets('narrativeText renders NarrativeWidget; edit affordance follows isEditMode', (tester) async {
      final data = NarrativeTextData(title: 'T', content: 'Some content', isSecret: false);

      await _pump(tester, data, isEditMode: true);
      expect(find.byType(NarrativeWidget), findsOneWidget);
      expect(find.text('Modifica'), findsOneWidget);

      await _pump(tester, data, isEditMode: false);
      expect(find.byType(NarrativeWidget), findsOneWidget);
      expect(find.text('Modifica'), findsNothing);
    });

    testWidgets('npcStatBlock renders NpcStatBlockWidget; edit affordance follows isEditMode', (tester) async {
      final data = NpcStatBlockData.empty();

      await _pump(tester, data, isEditMode: true);
      expect(find.byType(NpcStatBlockWidget), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);

      await _pump(tester, data, isEditMode: false);
      expect(find.byType(NpcStatBlockWidget), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets('initiativeTracker renders InitiativeTrackerWidget and forwards onUpdate through play mode', (tester) async {
      final data = InitiativeTrackerData(
        combatants: [
          {'id': 'a', 'name': 'Goblin', 'initiative': 10, 'hp_max': 7, 'hp_current': 7, 'ac': 12, 'is_player': false, 'notes': ''},
        ],
        round: 1,
        currentTurn: 0,
      );

      bool updated = false;
      await _pump(
        tester,
        data,
        isEditMode: false,
        onUpdate: (_) async {
          updated = true;
        },
      );
      expect(find.byType(InitiativeTrackerWidget), findsOneWidget);

      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pump();

      expect(updated, isTrue);
    });

    testWidgets('customTable renders CustomTableWidget; edit affordance follows isEditMode', (tester) async {
      final data = CustomTableData.empty();

      await _pump(tester, data, isEditMode: true);
      expect(find.byType(CustomTableWidget), findsOneWidget);
      expect(find.text('Configura Tabella'), findsOneWidget);

      await _pump(tester, data, isEditMode: false);
      expect(find.byType(CustomTableWidget), findsOneWidget);
      expect(find.text('Configura Tabella'), findsNothing);
    });

    testWidgets('image renders ImageWidget; edit affordance follows isEditMode', (tester) async {
      final data = ImageData.empty();

      await _pump(tester, data, isEditMode: true);
      expect(find.byType(ImageWidget), findsOneWidget);
      expect(find.text('Modifica'), findsOneWidget);

      await _pump(tester, data, isEditMode: false);
      expect(find.byType(ImageWidget), findsOneWidget);
      expect(find.text('Modifica'), findsNothing);
    });

    testWidgets('unrecognized kind renders the unsupported placeholder', (tester) async {
      final data = UnknownComponentData(rawType: 'mysteryKind', rawJson: '{}');

      await _pump(tester, data, isEditMode: true);
      expect(find.textContaining('mysteryKind'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    });
  });
}
