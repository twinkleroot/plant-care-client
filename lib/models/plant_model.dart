class Plant {
  final String plantId;
  final String? nickname;
  String? imageUrl;
  String? imageStatus;
  final String? plantType;
  final DateTime startDate;
  final int dDay;
  final DateTime? lastWateredDate;
  final DateTime? nextWateringDate;
  final int? nextWateringDDay;
  final bool isWateringNeeded;
  final DateTime? lastRepottedDate;
  final String? description;
  final String? careInfo;

  Plant({
    required this.plantId,
    this.nickname,
    this.imageUrl,
    this.imageStatus,
    this.plantType,
    required this.startDate,
    required this.dDay,
    this.lastWateredDate,
    this.nextWateringDate,
    this.nextWateringDDay,
    required this.isWateringNeeded,
    this.lastRepottedDate,
    this.description,
    this.careInfo,
  });

  factory Plant.fromJson(Map<String, dynamic> json) {
    return Plant(
      plantId: json['plantId'].toString(),
      nickname: json['nickname'],
      imageUrl: json['imageUrl'],
      imageStatus: json['imageStatus'],
      plantType: json['plantType'],
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : DateTime.now(),
      // ❗️ [핵심 수정] dDay가 null이면 0으로 처리하여 에러 방지
      dDay: json['dDay'] ?? 0,
      lastWateredDate: json['lastWateredDate'] != null
          ? DateTime.parse(json['lastWateredDate'])
          : null,
      nextWateringDate: json['nextWateringDate'] != null
          ? DateTime.parse(json['nextWateringDate'])
          : null,
      nextWateringDDay: json['nextWateringDDay'],
      isWateringNeeded: json['isWateringNeeded'],
      lastRepottedDate: json['lastRepottedDate'] != null
          ? DateTime.parse(json['lastRepottedDate'])
          : null,
      description: json['description'],
      careInfo: json['careInfo'],
    );
  }
}
