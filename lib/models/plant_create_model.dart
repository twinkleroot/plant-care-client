class PlantCreate {
  final String? nickname;
  final String? plantType;
  final DateTime startDate;
  final DateTime? lastWateredDate;

  PlantCreate({
    this.nickname,
    this.plantType,
    required this.startDate,
    this.lastWateredDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'plantType': plantType,
      'startDate': startDate.toIso8601String().substring(0, 10), // "yyyy-MM-dd" 형식
      'lastWateredDate': lastWateredDate?.toIso8601String().substring(0, 10),
    };
  }
}
