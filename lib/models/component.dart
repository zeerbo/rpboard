import 'dart:convert';
import '../core/ordering/ordered.dart';

List<Map<String, dynamic>> _mapList(dynamic v) =>
    (v as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

class SessionComponent implements Ordered<SessionComponent> {
  @override
  final String id;
  final String screenId;
  @override
  int order;
  ComponentData data;

  SessionComponent({
    required this.id,
    required this.screenId,
    required this.order,
    required this.data,
  });

  factory SessionComponent.fromMap(Map<String, dynamic> m) => SessionComponent(
        id: m['id'] as String,
        screenId: m['screen_id'] as String,
        order: m['order_index'] ?? 0,
        data: ComponentData.fromDb(m['type'] as String, (m['data'] as String?) ?? '{}'),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'screen_id': screenId,
        'type': data.dbKey,
        'order_index': order,
        'data': data.toJson(),
      };

  SessionComponent copyWith({int? order, ComponentData? data}) => SessionComponent(
        id: id,
        screenId: screenId,
        order: order ?? this.order,
        data: data ?? this.data,
      );

  @override
  SessionComponent withOrder(int order) => copyWith(order: order);
}

// ─── Typed ComponentData (ADR-0001) ───────────────────────────────────────────
// The sealed hierarchy below is the sole, live representation of a
// SessionComponent's payload. A kind's persisted identity is its subclass's
// `dbKey`; there is no separate enum to drift out of sync with it.

sealed class ComponentData {
  String toJson();
  String get dbKey;

  /// Single registry driving both persistence dispatch and the addable-kinds
  /// menu. `UnknownComponentData` is intentionally excluded — it is not
  /// something a DM can add, only something the app can end up with.
  static const List<_Kind> kinds = [
    _Kind(NarrativeTextData.key, NarrativeTextData.empty, NarrativeTextData.fromJson),
    _Kind(NpcStatBlockData.key, NpcStatBlockData.empty, NpcStatBlockData.fromJson),
    _Kind(InitiativeTrackerData.key, InitiativeTrackerData.empty, InitiativeTrackerData.fromJson),
    _Kind(CustomTableData.key, CustomTableData.empty, CustomTableData.fromJson),
    _Kind(ImageData.key, ImageData.empty, ImageData.fromJson),
  ];

  static ComponentData fromDb(String dbKey, String json) {
    for (final kind in kinds) {
      if (kind.dbKey != dbKey) continue;
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        return kind.fromJson(map);
      } catch (_) {
        return UnknownComponentData(rawType: dbKey, rawJson: json);
      }
    }
    return UnknownComponentData(rawType: dbKey, rawJson: json);
  }
}

/// One registry entry: a kind's persisted identity, its seed-value factory
/// (for the "add component" menu), and its tolerant JSON parser.
class _Kind {
  final String dbKey;
  final ComponentData Function() empty;
  final ComponentData Function(Map<String, dynamic>) fromJson;
  const _Kind(this.dbKey, this.empty, this.fromJson);
}

class NarrativeTextData extends ComponentData {
  static const key = 'narrativeText';

  String title;
  String content;
  bool isSecret;

  NarrativeTextData({
    required this.title,
    required this.content,
    required this.isSecret,
  });

  static NarrativeTextData empty() => NarrativeTextData(
        title: '',
        content: '',
        isSecret: false,
      );

  factory NarrativeTextData.fromJson(Map<String, dynamic> m) => NarrativeTextData(
        title: m['title'] as String? ?? '',
        content: m['content'] as String? ?? '',
        isSecret: m['isSecret'] as bool? ?? false,
      );

  @override
  String toJson() => jsonEncode({
        'title': title,
        'content': content,
        'isSecret': isSecret,
      });

  @override
  String get dbKey => NarrativeTextData.key;
}

class NpcStatBlockData extends ComponentData {
  static const key = 'npcStatBlock';

  String name;
  String size;
  String type;
  String alignment;
  int ac;
  String acType;
  String hp;
  String speed;
  int str, dex, con, int_, wis, cha;
  String savingThrows;
  String skills;
  String damageResistances;
  String damageImmunities;
  String conditionImmunities;
  String senses;
  String languages;
  String cr;
  int xp;
  List<Map<String, dynamic>> traits;
  List<Map<String, dynamic>> actions;
  List<Map<String, dynamic>> bonusActions;
  List<Map<String, dynamic>> reactions;
  List<Map<String, dynamic>> legendaryActions;
  String notes;

  NpcStatBlockData({
    required this.name,
    required this.size,
    required this.type,
    required this.alignment,
    required this.ac,
    required this.acType,
    required this.hp,
    required this.speed,
    required this.str,
    required this.dex,
    required this.con,
    required this.int_,
    required this.wis,
    required this.cha,
    required this.savingThrows,
    required this.skills,
    required this.damageResistances,
    required this.damageImmunities,
    required this.conditionImmunities,
    required this.senses,
    required this.languages,
    required this.cr,
    required this.xp,
    required this.traits,
    required this.actions,
    required this.bonusActions,
    required this.reactions,
    required this.legendaryActions,
    required this.notes,
  });

  static NpcStatBlockData empty() => NpcStatBlockData(
        name: 'Nuovo NPC',
        size: 'Medio',
        type: 'Umanoide',
        alignment: 'Neutrale',
        ac: 10,
        acType: '',
        hp: '10',
        speed: '9 m',
        str: 10,
        dex: 10,
        con: 10,
        int_: 10,
        wis: 10,
        cha: 10,
        savingThrows: '',
        skills: '',
        damageResistances: '',
        damageImmunities: '',
        conditionImmunities: '',
        senses: 'Percezione passiva 10',
        languages: 'Comune',
        cr: '1',
        xp: 200,
        traits: <Map<String, dynamic>>[],
        actions: <Map<String, dynamic>>[],
        bonusActions: <Map<String, dynamic>>[],
        reactions: <Map<String, dynamic>>[],
        legendaryActions: <Map<String, dynamic>>[],
        notes: '',
      );

  factory NpcStatBlockData.fromJson(Map<String, dynamic> m) => NpcStatBlockData(
        name: m['name'] as String? ?? '',
        size: m['size'] as String? ?? '',
        type: m['type'] as String? ?? '',
        alignment: m['alignment'] as String? ?? '',
        ac: m['ac'] as int? ?? 10,
        acType: m['acType'] as String? ?? '',
        hp: m['hp'] as String? ?? '',
        speed: m['speed'] as String? ?? '',
        str: m['str'] as int? ?? 10,
        dex: m['dex'] as int? ?? 10,
        con: m['con'] as int? ?? 10,
        int_: m['int'] as int? ?? 10,
        wis: m['wis'] as int? ?? 10,
        cha: m['cha'] as int? ?? 10,
        savingThrows: m['savingThrows'] as String? ?? '',
        skills: m['skills'] as String? ?? '',
        damageResistances: m['damageResistances'] as String? ?? '',
        damageImmunities: m['damageImmunities'] as String? ?? '',
        conditionImmunities: m['conditionImmunities'] as String? ?? '',
        senses: m['senses'] as String? ?? '',
        languages: m['languages'] as String? ?? '',
        cr: m['cr'] as String? ?? '',
        xp: m['xp'] as int? ?? 0,
        traits: _mapList(m['traits']),
        actions: _mapList(m['actions']),
        bonusActions: _mapList(m['bonusActions']),
        reactions: _mapList(m['reactions']),
        legendaryActions: _mapList(m['legendaryActions']),
        notes: m['notes'] as String? ?? '',
      );

  @override
  String toJson() => jsonEncode({
        'name': name,
        'size': size,
        'type': type,
        'alignment': alignment,
        'ac': ac,
        'acType': acType,
        'hp': hp,
        'speed': speed,
        'str': str,
        'dex': dex,
        'con': con,
        'int': int_,
        'wis': wis,
        'cha': cha,
        'savingThrows': savingThrows,
        'skills': skills,
        'damageResistances': damageResistances,
        'damageImmunities': damageImmunities,
        'conditionImmunities': conditionImmunities,
        'senses': senses,
        'languages': languages,
        'cr': cr,
        'xp': xp,
        'traits': traits,
        'actions': actions,
        'bonusActions': bonusActions,
        'reactions': reactions,
        'legendaryActions': legendaryActions,
        'notes': notes,
      });

  @override
  String get dbKey => NpcStatBlockData.key;
}

class InitiativeTrackerData extends ComponentData {
  static const key = 'initiativeTracker';

  List<Map<String, dynamic>> combatants;
  int round;
  int currentTurn;

  InitiativeTrackerData({
    required this.combatants,
    required this.round,
    required this.currentTurn,
  });

  static InitiativeTrackerData empty() => InitiativeTrackerData(
        combatants: <Map<String, dynamic>>[],
        round: 1,
        currentTurn: 0,
      );

  factory InitiativeTrackerData.fromJson(Map<String, dynamic> m) => InitiativeTrackerData(
        combatants: _mapList(m['combatants']),
        round: m['round'] as int? ?? 1,
        currentTurn: m['currentTurn'] as int? ?? 0,
      );

  @override
  String toJson() => jsonEncode({
        'combatants': combatants,
        'round': round,
        'currentTurn': currentTurn,
      });

  @override
  String get dbKey => InitiativeTrackerData.key;
}

class CustomTableData extends ComponentData {
  static const key = 'customTable';

  String title;
  List<String> headers;
  List<List<String>> rows;

  CustomTableData({
    required this.title,
    required this.headers,
    required this.rows,
  });

  static CustomTableData empty() => CustomTableData(
        title: 'Tabella',
        headers: <String>[],
        rows: <List<String>>[],
      );

  factory CustomTableData.fromJson(Map<String, dynamic> m) => CustomTableData(
        title: m['title'] as String? ?? '',
        headers: List<String>.from(m['headers'] as List? ?? []),
        rows: (m['rows'] as List? ?? []).map((r) => List<String>.from(r as List)).toList(),
      );

  @override
  String toJson() => jsonEncode({
        'title': title,
        'headers': headers,
        'rows': rows,
      });

  @override
  String get dbKey => CustomTableData.key;
}

class ImageData extends ComponentData {
  static const key = 'image';

  String title;
  String path;
  String caption;

  ImageData({
    required this.title,
    required this.path,
    required this.caption,
  });

  static ImageData empty() => ImageData(
        title: '',
        path: '',
        caption: '',
      );

  factory ImageData.fromJson(Map<String, dynamic> m) => ImageData(
        title: m['title'] as String? ?? '',
        path: m['path'] as String? ?? '',
        caption: m['caption'] as String? ?? '',
      );

  @override
  String toJson() => jsonEncode({
        'title': title,
        'path': path,
        'caption': caption,
      });

  @override
  String get dbKey => ImageData.key;
}

/// An unrecognized `dbKey`, or a recognized `dbKey` whose persisted JSON
/// failed to decode. Either way, the original bytes are preserved rather
/// than dropped, so a DM's content survives even when this build can't
/// render it.
class UnknownComponentData extends ComponentData {
  final String rawType;
  final String rawJson;

  UnknownComponentData({required this.rawType, required this.rawJson});

  @override
  String toJson() => rawJson;

  @override
  String get dbKey => rawType;
}
