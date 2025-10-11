import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:plant_care_app/models/plant_model.dart';

class PlantCard extends StatefulWidget {
  final Plant plant;
  final VoidCallback onWatered; // 부모로부터 "물 줬음" 로직을 전달받음

  const PlantCard({super.key, required this.plant, required this.onWatered});

  @override
  State<PlantCard> createState() => _PlantCardState();
}

class _PlantCardState extends State<PlantCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isWatering = false; // 물 주기 API 호출 중 상태를 관리

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.plant.isWateringNeeded) {
      _animationController.repeat(reverse: true);
    }
  }

  // 위젯이 업데이트될 때 isWateringNeeded 상태 변경을 감지
  @override
  void didUpdateWidget(covariant PlantCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // isWateringNeeded 상태가 변경되면 애니메이션을 제어
    if (widget.plant.isWateringNeeded != oldWidget.plant.isWateringNeeded) {
      if (widget.plant.isWateringNeeded) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    }
    // "물 줬음" 버튼 처리 후 로딩 상태 해제
    setState(() {
      _isWatering = false;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // "물 줬음" 버튼을 눌렀을 때 실행될 함수
  void _onWaterButtonPressed() {
    setState(() {
      _isWatering = true;
    });
    widget.onWatered();
  }

  @override
  Widget build(BuildContext context) {
    final plant = widget.plant;

    String nextWateringText;
    if (plant.nextWateringDDay == null) {
      nextWateringText = '정보 없음';
    } else if (plant.nextWateringDDay! > 0) {
      nextWateringText = 'D-${plant.nextWateringDDay}';
    } else if (plant.nextWateringDDay == 0) {
      nextWateringText = 'D-Day!';
    } else {
      nextWateringText = 'D+${-plant.nextWateringDDay!}';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastWateredDay = plant.lastWateredDate != null
        ? DateTime(plant.lastWateredDate!.year, plant.lastWateredDate!.month, plant.lastWateredDate!.day)
        : null;
    final bool isWateredToday = lastWateredDay != null && lastWateredDay.isAtSameMomentAs(today);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 5,
              ),
            ],
            // isWateringNeeded가 true일 때만 깜빡이는 테두리 적용
            border: plant.isWateringNeeded
                ? Border.all(
                    color: Color.lerp(Colors.red.withOpacity(0.5), Colors.red.withOpacity(0.1), _animationController.value)!,
                    width: 2,
                  )
                : null,
          ),
          child: child,
        );
      },
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: plant.imageUrl != null
                    ? NetworkImage(plant.imageUrl!)
                    : const AssetImage('assets/default_plant.png') as ImageProvider, // ❗️'assets/default_plant.png' 이미지 필요
                backgroundColor: Colors.grey[200],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plant.nickname ?? '이름 없는 식물', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '함께한 지 ${plant.decisionDay + 1}일째',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: (_isWatering || isWateredToday) ? null : _onWaterButtonPressed, // ❗️ 로딩 상태에 따라 버튼 비활성화
                style: ElevatedButton.styleFrom(
                  backgroundColor: isWateredToday ? Colors.grey[300] : Colors.green,
                  disabledBackgroundColor: Colors.grey[300], // 비활성화 시 회색
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: _isWatering
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('물 줬음', style: TextStyle(color: isWateredToday ? Colors.black54 : Colors.white)),
              )
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoColumn('마지막 물 준 날', plant.lastWateredDate != null ? DateFormat('yy/MM/dd').format(plant.lastWateredDate!) : '-'),
              _buildInfoColumn('다음 물 줄 날', nextWateringText, isAlert: plant.isWateringNeeded),
              _buildInfoColumn('분갈이', plant.lastRepottedDate != null ? DateFormat('yy/MM/dd').format(plant.lastRepottedDate!) : '-'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String title, String value, {bool isAlert = false}) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isAlert ? Colors.red : Colors.black87,
          ),
        ),
      ],
    );
  }
}
