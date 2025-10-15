import 'package:flutter/foundation.dart';

// 앱 전역에서 식물 정보 업데이트를 알리기 위한 서비스 (싱글턴)
class PlantUpdateService {
  static final PlantUpdateService _instance = PlantUpdateService._internal();
  factory PlantUpdateService() => _instance;
  PlantUpdateService._internal();

  final ValueNotifier<int?> plantIdToUpdate = ValueNotifier(null);

  void notifyUpdate(int plantId) {
    plantIdToUpdate.value = plantId;
    // 리스너에게 알린 후, 다시 null로 초기화하여 중복 업데이트 방지
    Future.delayed(const Duration(milliseconds: 100), () {
      plantIdToUpdate.value = null;
    });
  }
}
