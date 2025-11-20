class SystemConfig {
  final UpdateConfig? forceUpdate;
  final UpdateConfig? updateNotice;
  final NoticeConfig? notice;

  SystemConfig({this.forceUpdate, this.updateNotice, this.notice});

  factory SystemConfig.fromJson(Map<String, dynamic> json) {
    return SystemConfig(
      forceUpdate: json['forceUpdate'] != null ? UpdateConfig.fromJson(json['forceUpdate']) : null,
      updateNotice: json['updateNotice'] != null ? UpdateConfig.fromJson(json['updateNotice']) : null,
      notice: json['notice'] != null ? NoticeConfig.fromJson(json['notice']) : null,
    );
  }
}

class UpdateConfig {
  final String version;
  final String startDate;
  final String endDate;

  UpdateConfig({required this.version, required this.startDate, required this.endDate});

  factory UpdateConfig.fromJson(Map<String, dynamic> json) {
    return UpdateConfig(
      version: json['version'] ?? '0.0.0',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
    );
  }
}

class NoticeConfig {
  final String title;
  final String content;
  final String startDate;
  final String endDate;

  NoticeConfig({required this.title, required this.content, required this.startDate, required this.endDate});

  factory NoticeConfig.fromJson(Map<String, dynamic> json) {
    return NoticeConfig(
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
    );
  }
}