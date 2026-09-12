import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rpboard/core/database/db.dart';
import 'package:rpboard/core/database/migrations.dart';
import 'package:rpboard/models/campaign.dart';
import 'package:rpboard/models/chapter.dart';
import 'package:rpboard/models/session_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as sql;

import '../../support/in_memory_database.dart';

/// Referential integrity, asserted through `openAppDatabase` — the same
/// function `SqfliteDatabase` opens its real on-device database with.
///
/// That detail is the point of this file. The schema has declared
/// `ON DELETE CASCADE` on `chapters`, `session_screens` and `components` since
/// the v1 DDL, but SQLite disables foreign key enforcement by default and the
/// setting is per *connection*, not per database file. So whether a DM
/// deleting a Campaign actually removes the Chapters, SessionScreens and
/// SessionComponents underneath it is not a property of the schema at all — it
/// is a property of how the app opens its connection. A test that opened a
/// connection of its own making could only prove something about itself.
///
/// The last group crosses to the other adapter. ADR-0002 makes the fake's
/// fidelity a requirement, not a courtesy — tests that run against a fake whose
/// contract has drifted from the real one pass against a fiction — so the
/// parent-insert rule this decision introduces is asserted on both.
///
/// See ADR-0006. The `sqflite_common_ffi` setup below is the same one
/// `migrations_execution_test.dart` documents at length.
void main() {
  setUpAll(() {
    sql.sqfliteFfiInit();
    sql.databaseFactory = sql.databaseFactoryFfi;
  });

  /// The columns a `campaigns` row needs, none of which any assertion here
  /// cares about beyond the id.
  Map<String, Object?> campaignRow(String id) => {
    'id': id,
    'name': id,
    'description': '',
    'setting': '',
    'created_at': '2026-01-01T00:00:00.000',
    'updated_at': '2026-01-01T00:00:00.000',
  };

  Future<Object?> foreignKeysSetting(sql.Database db) async =>
      (await db.rawQuery('PRAGMA foreign_keys')).first['foreign_keys'];

  /// A Campaign → Chapter → SessionScreen → SessionComponent chain, one row at
  /// each level, with the ids the assertions below refer to.
  Future<void> seedChain(sql.Database db) async {
    await db.insert('campaigns', campaignRow('campaign-1'));
    await db.insert('chapters', {
      'id': 'chapter-1',
      'campaign_id': 'campaign-1',
      'title': 'Barovia',
      'summary': '',
      'order_index': 0,
    });
    await db.insert('session_screens', {
      'id': 'screen-1',
      'chapter_id': 'chapter-1',
      'title': 'Death House',
      'order_index': 0,
    });
    await db.insert('components', {
      'id': 'component-1',
      'screen_id': 'screen-1',
      'type': 'narrative',
      'order_index': 0,
      'data': '{}',
    });
  }

  Future<int> countIn(sql.Database db, String table) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $table');
    return rows.first['n'] as int;
  }

  group('the connection the app opens', () {
    late sql.Database db;

    setUp(() async {
      db = await openAppDatabase(sql.inMemoryDatabasePath);
    });

    tearDown(() async => db.close());

    test('enforces foreign keys', () async {
      expect(await foreignKeysSetting(db), 1);
    });

    test('deleting a Campaign removes everything underneath it', () async {
      await seedChain(db);

      await db.delete('campaigns', where: 'id = ?', whereArgs: ['campaign-1']);

      expect(await countIn(db, 'chapters'), 0);
      expect(await countIn(db, 'session_screens'), 0);
      expect(await countIn(db, 'components'), 0);
    });

    test('deleting a Chapter removes its SessionScreens and their '
        'SessionComponents, leaving the Campaign alone', () async {
      await seedChain(db);

      await db.delete('chapters', where: 'id = ?', whereArgs: ['chapter-1']);

      expect(await countIn(db, 'campaigns'), 1);
      expect(await countIn(db, 'session_screens'), 0);
      expect(await countIn(db, 'components'), 0);
    });

    test('deleting a SessionScreen removes its SessionComponents, leaving the '
        'Chapter alone', () async {
      await seedChain(db);

      await db.delete('session_screens', where: 'id = ?', whereArgs: ['screen-1']);

      expect(await countIn(db, 'chapters'), 1);
      expect(await countIn(db, 'components'), 0);
    });

    test('rejects a Chapter whose Campaign does not exist', () async {
      await expectLater(
        db.insert('chapters', {
          'id': 'orphan',
          'campaign_id': 'no-such-campaign',
          'title': 'Nowhere',
          'summary': '',
          'order_index': 0,
        }),
        throwsA(isA<sql.DatabaseException>()),
      );
    });

    test('rejects a SessionScreen whose Chapter does not exist', () async {
      await expectLater(
        db.insert('session_screens', {
          'id': 'orphan',
          'chapter_id': 'no-such-chapter',
          'title': 'Nowhere',
          'order_index': 0,
        }),
        throwsA(isA<sql.DatabaseException>()),
      );
    });

    test('rejects a SessionComponent whose SessionScreen does not exist',
        () async {
      await expectLater(
        db.insert('components', {
          'id': 'orphan',
          'screen_id': 'no-such-screen',
          'type': 'narrative',
          'order_index': 0,
          'data': '{}',
        }),
        throwsA(isA<sql.DatabaseException>()),
      );
    });

    test('destroys a subtree when a parent row is written with INSERT OR '
        'REPLACE — which is why the adapter does not', () async {
      // A characterization test, not a wish. REPLACE resolves a primary key
      // conflict by deleting the existing row first, and with enforcement on
      // that delete cascades — so re-inserting a Chapter under its own id
      // takes its SessionScreens and SessionComponents with it, silently.
      //
      // Harmless before ADR-0006 (nothing cascaded); a trap after it. The
      // three parent-table inserts in `SqfliteDatabase` therefore let a
      // duplicate id throw instead. This test stands guard: if anyone
      // reintroduces `ConflictAlgorithm.replace` on a parent table, the
      // behaviour it documents is what they will get.
      await seedChain(db);

      await db.insert(
        'chapters',
        {
          'id': 'chapter-1',
          'campaign_id': 'campaign-1',
          'title': 'Barovia, renamed',
          'summary': '',
          'order_index': 0,
        },
        conflictAlgorithm: sql.ConflictAlgorithm.replace,
      );

      expect(await countIn(db, 'chapters'), 1);
      expect(await countIn(db, 'session_screens'), 0);
      expect(await countIn(db, 'components'), 0);
    });

    test('rejects a second Campaign written under an existing id', () async {
      await seedChain(db);

      await expectLater(
        db.insert('campaigns', campaignRow('campaign-1')),
        throwsA(isA<sql.DatabaseException>()),
        reason: 'the adapter relies on this: a duplicate id must fail loudly '
            'rather than replace the row and cascade its children away',
      );
      expect(await countIn(db, 'chapters'), 1);
    });

    test('still deletes a Campaign that owns nothing', () async {
      await db.insert('campaigns', campaignRow('empty'));

      await db.delete('campaigns', where: 'id = ?', whereArgs: ['empty']);

      expect(await countIn(db, 'campaigns'), 0);
    });
  });

  /// The v3 → v4 step, which sweeps out rows orphaned during the era when
  /// foreign keys went unenforced.
  ///
  /// Enabling enforcement does nothing about rows already on disk, so an
  /// upgraded database would otherwise keep contradicting its own constraints.
  /// Each test here reproduces the real upgrade's ordering: seed with
  /// enforcement off, the way those rows were actually written, then turn it on
  /// before applying the step — `onConfigure` runs before `onUpgrade`.
  group('the orphan sweep at version 4', () {
    late sql.Database db;

    setUp(() async {
      db = await sql.databaseFactory.openDatabase(sql.inMemoryDatabasePath);
      await const Migrations().apply(db, 0, 3);
    });

    tearDown(() async => db.close());

    Future<void> upgradeToV4() async {
      await db.execute('PRAGMA foreign_keys = ON');
      await const Migrations().apply(db, 3, 4);
    }

    test('deletes a Chapter whose Campaign is gone', () async {
      await db.insert('chapters', {
        'id': 'orphan-chapter',
        'campaign_id': 'deleted-campaign',
        'title': 'Left behind',
        'summary': '',
        'order_index': 0,
      });

      await upgradeToV4();

      expect(await countIn(db, 'chapters'), 0);
    });

    test('deletes a SessionScreen whose Chapter is gone', () async {
      await db.insert('session_screens', {
        'id': 'orphan-screen',
        'chapter_id': 'deleted-chapter',
        'title': 'Left behind',
        'order_index': 0,
      });

      await upgradeToV4();

      expect(await countIn(db, 'session_screens'), 0);
    });

    test('deletes a SessionComponent whose SessionScreen is gone', () async {
      await db.insert('components', {
        'id': 'orphan-component',
        'screen_id': 'deleted-screen',
        'type': 'narrative',
        'order_index': 0,
        'data': '{}',
      });

      await upgradeToV4();

      expect(await countIn(db, 'components'), 0);
    });

    test('sweeps a whole subtree left by one deleted Campaign', () async {
      // Exactly what a pre-ADR-0006 `deleteCampaign` left behind: the Campaign
      // row gone, all three levels beneath it still present.
      await db.insert('chapters', {
        'id': 'chapter-1',
        'campaign_id': 'deleted-campaign',
        'title': 'Barovia',
        'summary': '',
        'order_index': 0,
      });
      await db.insert('session_screens', {
        'id': 'screen-1',
        'chapter_id': 'chapter-1',
        'title': 'Death House',
        'order_index': 0,
      });
      await db.insert('components', {
        'id': 'component-1',
        'screen_id': 'screen-1',
        'type': 'narrative',
        'order_index': 0,
        'data': '{}',
      });

      await upgradeToV4();

      expect(await countIn(db, 'chapters'), 0);
      expect(await countIn(db, 'session_screens'), 0,
          reason: 'orphaned once its Chapter went, so the ordering of the '
              'step\'s statements has to catch it in the same pass');
      expect(await countIn(db, 'components'), 0);
    });

    test('leaves a Campaign and everything properly under it alone', () async {
      await seedChain(db);
      final characterCount = await countIn(db, 'characters');

      await upgradeToV4();

      expect(await countIn(db, 'campaigns'), 1);
      expect(await countIn(db, 'chapters'), 1);
      expect(await countIn(db, 'session_screens'), 1);
      expect(await countIn(db, 'components'), 1);
      expect(await countIn(db, 'characters'), characterCount);
    });

    test('keeps the healthy subtree while sweeping the orphaned one', () async {
      await seedChain(db);
      await db.insert('chapters', {
        'id': 'orphan-chapter',
        'campaign_id': 'deleted-campaign',
        'title': 'Left behind',
        'summary': '',
        'order_index': 1,
      });

      await upgradeToV4();

      final remaining = await db.query('chapters');
      expect(remaining.map((r) => r['id']), ['chapter-1']);
    });

    test('is a no-op on a database with no orphans', () async {
      await upgradeToV4();

      expect(await countIn(db, 'chapters'), 0);
      expect(await countIn(db, 'session_screens'), 0);
      expect(await countIn(db, 'components'), 0);
    });
  });

  /// Why the pragma lives in the connection's `onConfigure` hook and *not* in a
  /// migration step. A migration step runs once, when the schema version
  /// changes; the pragma is connection state, so a step would leave the very
  /// next launch unprotected. This asserts that difference against a real file
  /// rather than taking it on faith, because "it is per-connection" is exactly
  /// the kind of claim that is easy to assume and cheap to check.
  test('foreign key enforcement does not survive a reopen on its own',
      () async {
    final dir = await Directory.systemTemp.createTemp('rpboard-fk-');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'probe.db');

    final first = await sql.databaseFactory.openDatabase(path);
    await first.execute('PRAGMA foreign_keys = ON');
    expect(await foreignKeysSetting(first), 1);
    await first.close();

    final second = await sql.databaseFactory.openDatabase(path);
    addTearDown(() => second.close());
    expect(
      await foreignKeysSetting(second),
      0,
      reason: 'the pragma is per-connection: setting it once, however early, '
          'cannot protect later launches — so it belongs in onConfigure, which '
          'sqflite runs on every open',
    );
  });

  /// The same parent-insert rule, on the other side of the seam.
  ///
  /// `SqfliteDatabase` stopped replacing on conflict for the three parent
  /// tables, so a duplicate id now throws there. `InMemoryDatabase` has to
  /// refuse it too: a fake that keeps upserting would let a test pass on
  /// behaviour the real adapter no longer has, which ADR-0002 names as the one
  /// thing a behavioral fake must never do.
  ///
  /// The exception *type* is deliberately not asserted — that would pin a test
  /// to which adapter it is running against, and the seam exists to hide that.
  group('the in-memory fake', () {
    late InMemoryDatabase db;

    setUp(() => db = InMemoryDatabase());

    test('rejects a Campaign inserted under an existing id', () async {
      await db.insertCampaign(Campaign(
        id: 'campaign-1',
        name: 'First',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ));

      await expectLater(
        db.insertCampaign(Campaign(
          id: 'campaign-1',
          name: 'Collides',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        )),
        throwsA(isA<Object>()),
      );
      expect((await db.getCampaigns()).single.name, 'First');
    });

    test('rejects a Chapter inserted under an existing id', () async {
      await db.insertChapter(
          Chapter(id: 'chapter-1', campaignId: 'campaign-1', order: 0));

      await expectLater(
        db.insertChapter(
            Chapter(id: 'chapter-1', campaignId: 'campaign-1', order: 1)),
        throwsA(isA<Object>()),
      );
      expect((await db.getChapters('campaign-1')).single.order, 0);
    });

    test('rejects a SessionScreen inserted under an existing id', () async {
      await db.insertScreen(
          SessionScreen(id: 'screen-1', chapterId: 'chapter-1', order: 0));

      await expectLater(
        db.insertScreen(
            SessionScreen(id: 'screen-1', chapterId: 'chapter-1', order: 1)),
        throwsA(isA<Object>()),
      );
      expect((await db.getScreens('chapter-1')).single.order, 0);
    });

    test('still accepts a second Campaign under a fresh id', () async {
      await db.insertCampaign(Campaign(
        id: 'campaign-1',
        name: 'First',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ));
      await db.insertCampaign(Campaign(
        id: 'campaign-2',
        name: 'Second',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ));

      expect((await db.getCampaigns()).length, 2);
    });
  });
}
