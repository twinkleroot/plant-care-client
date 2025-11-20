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

    // 날짜 파싱 안전하게 처리
    final startDate = json['startDate'] != null
        ? DateTime.parse(json['startDate'])
        : DateTime.now();

    // dDay를 클라이언트에서 직접 계산
    // 오늘 날짜와 시작 날짜의 시간(Time) 성분을 제거하고 날짜 차이만 계산합니다.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final calculatedDDay = today.difference(start).inDays;

    return Plant(
      plantId: json['plantId'].toString(),
      nickname: json['nickname'],
      imageUrl: json['imageUrl'],
      imageStatus: json['imageStatus'],
      plantType: json['plantType'],
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'])
          : DateTime.now(),
      // 서버 값 대신 계산된 값 사용
      dDay: calculatedDDay,
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
