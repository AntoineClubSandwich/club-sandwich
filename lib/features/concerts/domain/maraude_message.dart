class MaraudeMessage {
  const MaraudeMessage({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.message,
    required this.createdAt,
  });

  factory MaraudeMessage.fromJson(Map<String, dynamic> json) {
    final name = (json['author_name'] as String?)?.trim() ?? '';
    return MaraudeMessage(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      authorName: name.isEmpty ? 'Bénévole' : name,
      message: json['message'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  final String id;
  final String userId;
  final String authorName;
  final String message;
  final DateTime createdAt;
}
