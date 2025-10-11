class PlantUpdate {
  final String? nickname;
  final DateTime? startDate;
  final DateTime? lastWateredDate;
  final DateTime? lastRepottedDate;
  final String? plantType;
  // plantType은 수정 불가 항목으로 가정하고 제외

  PlantUpdate({
    this.nickname,
    this.startDate,
    this.lastWateredDate,
    this.lastRepottedDate,
    this.plantType,
  });

  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'startDate': startDate?.toIso8601String().substring(0, 10),
      'lastWateredDate': lastWateredDate?.toIso8601String().substring(0, 10),
      'lastRepottedDate': lastRepottedDate?.toIso8601String().substring(0, 10),
      'plantType': plantType,
    }..removeWhere((key, value) => value == null);
  }
}
