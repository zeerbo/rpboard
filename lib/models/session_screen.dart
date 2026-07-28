import '../core/ordering/ordered.dart';

class SessionScreen implements Ordered<SessionScreen> {
  @override
  final String id;
  final String chapterId;
  String title;
  @override
  int order;

  SessionScreen({
    required this.id,
    required this.chapterId,
    this.title = '',
    required this.order,
  });

  factory SessionScreen.fromMap(Map<String, dynamic> m) => SessionScreen(
        id: m['id'] as String,
        chapterId: m['chapter_id'] as String,
        title: m['title'] ?? '',
        order: m['order_index'] ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'chapter_id': chapterId,
        'title': title,
        'order_index': order,
      };

  SessionScreen copyWith({String? title, int? order}) => SessionScreen(
        id: id,
        chapterId: chapterId,
        title: title ?? this.title,
        order: order ?? this.order,
      );

  @override
  SessionScreen withOrder(int order) => copyWith(order: order);
}
