class WorkflowNotification {
  const WorkflowNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.concertId,
    this.readAt,
    this.resolvedAt,
  });

  factory WorkflowNotification.fromJson(Map<String, dynamic> json) {
    return WorkflowNotification(
      id: json['id'] as String,
      concertId: json['concert_id'] as String?,
      type: json['notification_type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String),
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String? concertId;
  final String type;
  final String title;
  final String body;
  final DateTime? readAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  /// The action this notification asked for was completed (e.g. the
  /// volunteer confirmed, or the ask became moot) before it was ever
  /// opened - it shouldn't keep demanding attention either way.
  bool get isResolved => resolvedAt != null;

  bool get needsAttention => !isRead && !isResolved;
}
