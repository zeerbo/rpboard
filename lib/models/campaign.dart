class Campaign {
  final String id;
  String name;
  String description;
  String setting;
  DateTime createdAt;
  DateTime updatedAt;

  Campaign({
    required this.id,
    this.name = '',
    this.description = '',
    this.setting = '',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Campaign.fromMap(Map<String, dynamic> m) => Campaign(
        id: m['id'] as String,
        name: m['name'] ?? '',
        description: m['description'] ?? '',
        setting: m['setting'] ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'setting': setting,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
