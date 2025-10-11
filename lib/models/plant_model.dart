class Plant {
  final int plantId;
  final String? nickname;
  final String? imageUrl;
  final String? plantType;
  final DateTime startDate;
  final int decisionDay;
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
    this.plantType,
    required this.startDate,
    required this.decisionDay,
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
      plantId: json['plantId'],
      nickname: json['nickname'],
      imageUrl: json['imageUrl'],
      plantType: json['plantType'],
      startDate: DateTime.parse(json['startDate']),
      decisionDay: json['decisionDay'],
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
