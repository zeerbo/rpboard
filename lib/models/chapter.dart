import '../core/ordering/ordered.dart';

class Chapter implements Ordered<Chapter> {
  @override
  final String id;
  final String campaignId;
  String title;
  String summary;
  @override
  int order;

  Chapter({
    required this.id,
    required this.campaignId,
    this.title = '',
    this.summary = '',
    required this.order,
  });

  factory Chapter.fromMap(Map<String, dynamic> m) => Chapter(
        id: m['id'] as String,
        campaignId: m['campaign_id'] as String,
        title: m['title'] ?? '',
        summary: m['summary'] ?? '',
        order: m['order_index'] ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'campaign_id': campaignId,
        'title': title,
        'summary': summary,
        'order_index': order,
      };

  Chapter copyWith({String? title, String? summary, int? order}) => Chapter(
        id: id,
        campaignId: campaignId,
        title: title ?? this.title,
        summary: summary ?? this.summary,
        order: order ?? this.order,
      );

  @override
  Chapter withOrder(int order) => copyWith(order: order);
}
