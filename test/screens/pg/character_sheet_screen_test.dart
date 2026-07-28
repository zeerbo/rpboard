import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpboard/core/database/db.dart';
import 'package:rpboard/models/character.dart';
import 'package:rpboard/providers/character_provider.dart';
import 'package:rpboard/screens/pg/character_sheet_screen.dart';

import '../../support/in_memory_database.dart';

/// Widget-level coverage for the C7 split: the handful of things pure-Dart
/// `Character` tests can't reach — that a tab's edit writes straight into
/// the live `Character` (not just on save), and that switching tabs away
/// and back doesn't lose it. `characterProvider`'s cached `AsyncData` holds
/// the exact same `Character` instance the screen seeds `_char` from (see
/// `_seedFromLoaded`), so reading `container.read(characterProvider(id)).value`
/// observes a write-through edit immediately, with no need to wait on the
/// debounced save.
void main() {
  late InMemoryDatabase db;
  late ProviderContainer container;

  Future<void> pumpSheet(WidgetTester tester, String id) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: CharacterSheetScreen(characterId: id)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Explicitly unmounts the sheet (rather than relying on the test
  /// framework's implicit end-of-test teardown) so `State.dispose()`'s
  /// flush-save runs while we can still pump: `save()` ends in
  /// `ref.invalidateSelf()`, which schedules a zero-duration Riverpod
  /// timer, and the test framework fails the test if any timer is still
  /// pending once the widget tree is gone. Every test that pumps the sheet
  /// must call this last.
  Future<void> unmountSheet(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // `pump()` with no argument passes a null duration, which skips
    // FakeAsync's `elapse()` step entirely — a *zero*-duration Duration
    // must be passed explicitly to actually fire a due-now fake Timer.
    await tester.pump(Duration.zero);
  }

  /// Switches tabs by label. The `TabBar` is `isScrollable: true`, so a
  /// later tab (e.g. "Note") can be laid out past the 800px test viewport;
  /// tapping its geometric position directly misses (Flutter warns and the
  /// tap becomes a no-op). `ensureVisible` scrolls the `TabBar`'s own
  /// scrollable into view first.
  Future<void> tapTab(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  setUp(() {
    db = InMemoryDatabase();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() => container.dispose());

  group('Info tab', () {
    testWidgets('editing the name field writes through into the Character', (tester) async {
      await db.insertCharacter(Character(id: 'c1', name: 'Old Name'));
      await pumpSheet(tester, 'c1');

      await tester.enterText(find.widgetWithText(TextField, 'Nome Personaggio'), 'Aragorn');
      await tester.pump();

      expect(container.read(characterProvider('c1')).value?.name, 'Aragorn');
      // The parent's AppBar title reacts too (same live-update the pre-split
      // screen had via setState on every field change).
      expect(find.widgetWithText(AppBar, 'Aragorn'), findsOneWidget);
      await unmountSheet(tester);
    });

    testWidgets('switching away from Info and back preserves the edit', (tester) async {
      await db.insertCharacter(Character(id: 'c1', name: 'Old Name'));
      await pumpSheet(tester, 'c1');

      await tester.enterText(find.widgetWithText(TextField, 'Nome Personaggio'), 'Aragorn');
      await tester.pump();

      await tapTab(tester, 'Note');
      await tapTab(tester, 'Info');

      expect(find.text('Aragorn'), findsWidgets);
      expect(container.read(characterProvider('c1')).value?.name, 'Aragorn');
      await unmountSheet(tester);
    });
  });

  group('Combattimento tab', () {
    testWidgets('editing AC writes through into the Character', (tester) async {
      await db.insertCharacter(Character(id: 'c1', name: 'Aragorn'));
      await pumpSheet(tester, 'c1');

      await tapTab(tester, 'Combattimento');

      await tester.enterText(find.widgetWithText(TextField, 'CA'), '18');
      await tester.pump();

      expect(container.read(characterProvider('c1')).value?.armorClass, 18);
      await unmountSheet(tester);
    });

    testWidgets('switching away from Combattimento and back preserves the edit', (tester) async {
      await db.insertCharacter(Character(id: 'c1', name: 'Aragorn'));
      await pumpSheet(tester, 'c1');

      await tapTab(tester, 'Combattimento');
      await tester.enterText(find.widgetWithText(TextField, 'CA'), '18');
      await tester.pump();

      await tapTab(tester, 'Note');
      await tapTab(tester, 'Combattimento');

      expect(find.widgetWithText(TextField, 'CA'), findsOneWidget);
      final tf = tester.widget<TextField>(find.widgetWithText(TextField, 'CA'));
      expect(tf.controller?.text, '18');
      expect(container.read(characterProvider('c1')).value?.armorClass, 18);
      await unmountSheet(tester);
    });

    testWidgets('ticking a death-save box writes through; switching tabs preserves the tick', (tester) async {
      await db.insertCharacter(Character(id: 'c1', name: 'Aragorn'));
      await pumpSheet(tester, 'c1');

      await tapTab(tester, 'Combattimento');

      // 6 checkboxes: 0-2 = Successi, 3-5 = Fallimenti.
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pump();

      expect(container.read(characterProvider('c1')).value?.deathSaveSuccesses, 1);

      await tapTab(tester, 'Note');
      await tapTab(tester, 'Combattimento');

      expect(container.read(characterProvider('c1')).value?.deathSaveSuccesses, 1);
      await unmountSheet(tester);
    });

    testWidgets('ticking the third failure box sets isDead on the Character', (tester) async {
      await db.insertCharacter(Character(id: 'c1', name: 'Aragorn'));
      await pumpSheet(tester, 'c1');

      await tapTab(tester, 'Combattimento');

      // Failure checkboxes are indices 3, 4, 5.
      await tester.tap(find.byType(Checkbox).at(3));
      await tester.pump();
      await tester.tap(find.byType(Checkbox).at(4));
      await tester.pump();
      await tester.tap(find.byType(Checkbox).at(5));
      await tester.pump();

      final c = container.read(characterProvider('c1')).value!;
      expect(c.isDead, isTrue);
      expect(c.deathSaveFailures, 0);
      await unmountSheet(tester);
    });

    testWidgets('ticking the third success box sets isStable on the Character', (tester) async {
      await db.insertCharacter(Character(id: 'c1', name: 'Aragorn'));
      await pumpSheet(tester, 'c1');

      await tapTab(tester, 'Combattimento');

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pump();
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pump();

      final c = container.read(characterProvider('c1')).value!;
      expect(c.isStable, isTrue);
      expect(c.deathSaveSuccesses, 0);
      await unmountSheet(tester);
    });
  });

  group('Magie tab', () {
    const abilityLabel = 'Caratteristica Incantamento (es. Intelligenza)';

    testWidgets('editing the spellcasting-ability field writes through and recomputes DC/attack bonus', (tester) async {
      final c = Character(id: 'c1', name: 'Aragorn', charisma: 18); // +4
      await db.insertCharacter(c);
      await pumpSheet(tester, 'c1');

      await tapTab(tester, 'Magie');

      // Before typing a recognized ability: zero-modifier DC/attack bonus.
      expect(find.text('10'), findsOneWidget); // 8 + prof(2) + 0
      expect(find.text('+2'), findsOneWidget); // prof(2) + 0

      await tester.enterText(find.widgetWithText(TextField, abilityLabel), 'Carisma');
      await tester.pump();

      expect(container.read(characterProvider('c1')).value?.spellcastingAbility, 'Carisma');
      expect(find.text('14'), findsOneWidget); // 8 + prof(2) + 4
      expect(find.text('+6'), findsOneWidget); // prof(2) + 4
      await unmountSheet(tester);
    });

    testWidgets('switching away from Magie and back preserves the field, slot state, and spell list', (tester) async {
      await db.insertCharacter(Character(id: 'c1', name: 'Aragorn'));
      await pumpSheet(tester, 'c1');

      await tapTab(tester, 'Magie');

      await tester.enterText(find.widgetWithText(TextField, abilityLabel), 'Saggezza');
      await tester.pump();

      // Set 2 slots at level 1, then use one.
      await tester.enterText(find.widgetWithText(TextFormField, 'Tot').first, '2');
      await tester.pump();
      final slotIcons = find.byIcon(Icons.circle);
      await tester.tap(slotIcons.first);
      await tester.pump();

      expect(container.read(characterProvider('c1')).value?.spellSlots.first.used, 1);

      await tapTab(tester, 'Note');
      await tapTab(tester, 'Magie');

      final c = container.read(characterProvider('c1')).value!;
      expect(c.spellcastingAbility, 'Saggezza');
      expect(c.spellSlots.first.total, 2);
      expect(c.spellSlots.first.used, 1);
      expect(find.widgetWithText(TextField, abilityLabel), findsOneWidget);
      final tf = tester.widget<TextField>(find.widgetWithText(TextField, abilityLabel));
      expect(tf.controller?.text, 'Saggezza');
      await unmountSheet(tester);
    });
  });
}
