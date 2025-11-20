class PlantUpdate {
  final String? nickname;
  final DateTime? startDate;
  final DateTime? lastWateredDate;
  final DateTime? lastRepottedDate;
  final String? plantType;
  final String? description;
  final String? careInfo;
  final bool? isImageDeleted;

  PlantUpdate({
    this.nickname,
    this.startDate,
    this.lastWateredDate,
    this.lastRepottedDate,
    this.plantType,
    this.description,
    this.careInfo,
    this.isImageDeleted,
  });

  Map<String, dynamic> toJson() {
    return {
      'nickname': nickname,
      'startDate': startDate?.toIso8601String().substring(0, 10),
      'lastWateredDate': lastWateredDate?.toIso8601String().substring(0, 10),
      'lastRepottedDate': lastRepottedDate?.toIso8601String().substring(0, 10),
      'plantType': plantType,
      'description': description,
      'careInfo': careInfo,
      'isImageDeleted': isImageDeleted,
    }..removeWhere((key, value) => value == null);
  }
}
