class PushMessage {
  final String messageId;
  final String title;
  final String body;
  bool isRead;
  final DateTime createdAt;

  PushMessage({
    required this.messageId,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory PushMessage.fromJson(Map<String, dynamic> json) {
    return PushMessage(
      messageId: json['messageId'].toString(),
      title: json['title'],
      body: json['body'],
      isRead: json['isRead'] ?? json['read'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}