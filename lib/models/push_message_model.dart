class PushMessage {
  final int messageId;
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
      messageId: json['messageId'],
      title: json['title'],
      body: json['body'],
      isRead: json['isRead'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}