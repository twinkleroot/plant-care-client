import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:plant_care_app/models/plant_model.dart';
import 'package:plant_care_app/models/plant_update_model.dart';
import 'package:plant_care_app/services/ad_service.dart';
import 'package:plant_care_app/services/api_service.dart';
import 'package:plant_care_app/widgets/banner_ad_widget.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../utils/logger.dart';

class PlantDetailScreen extends StatefulWidget {
  final int plantId;
  const PlantDetailScreen({super.key, required this.plantId});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  Future<Plant>? _plantFuture;
  bool _isEditMode = false;
  bool _isSaving = false;

  // 뒤로가기 시 리스트 화면에 전달할 최종 결과값
  dynamic _resultForReturn;

  // 수정 모드를 위한 컨트롤러
  final _nicknameController = TextEditingController();
  final _startDateController = TextEditingController();
  final _lastWateredDateController = TextEditingController();
  final _lastRepottedDateController = TextEditingController();
  File? _selectedImage;
  DateTime? _startDate;
  DateTime? _lastWateredDate;
  DateTime? _lastRepottedDate;
  List<String> _plantTypeOptions = [];
  String? _selectedPlantType;
  bool _isLoadingTypes = false;

  @override
  void initState() {
    super.initState();
    _plantFuture = ApiService.getPlantDetail(widget.plantId);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _startDateController.dispose();
    _lastWateredDateController.dispose();
    _lastRepottedDateController.dispose();
    super.dispose();
  }

  void _toggleEditMode(Plant plant) {
    setState(() {
      _isEditMode = !_isEditMode;
      if (_isEditMode) {
        // 수정 모드 진입 시, 현재 데이터로 컨트롤러 및 변수 초기화
        _nicknameController.text = plant.nickname ?? '';
        _startDate = plant.startDate;
        _startDateController.text = DateFormat('yyyy-MM-dd').format(plant.startDate);
        _lastWateredDate = plant.lastWateredDate;
        _lastWateredDateController.text = plant.lastWateredDate != null ? DateFormat('yyyy-MM-dd').format(plant.lastWateredDate!) : '';
        _lastRepottedDate = plant.lastRepottedDate;
        _lastRepottedDateController.text = plant.lastRepottedDate != null ? DateFormat('yyyy-MM-dd').format(plant.lastRepottedDate!) : '';
        _selectedImage = null; // 이미지 선택 초기화
        _selectedPlantType = plant.plantType;
        _fetchPlantTypes(); // 식물 종류 목록 불러오기
      }
    });
  }

  // ❗️ [추가] 식물 종류 목록 불러오기 로직
  Future<void> _fetchPlantTypes() async {
    setState(() { _isLoadingTypes = true; });
    try {
      final types = await ApiService.getPlantTypes();
      if (mounted) {
        setState(() {
          _plantTypeOptions = types;
          _isLoadingTypes = false;
        });
      }
    } catch (e) {
      logger.e('식물 종류 목록 로딩 실패: $e');
      if (mounted) {
        setState(() { _isLoadingTypes = false; });
      }
    }
  }

  Future<void> _pickImage() async {
    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: const AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.image,
        themeColor: Colors.green,
      ),
    );

    if (assets != null && assets.isNotEmpty) {
      final file = await assets.first.file;
      if (file != null) {
        setState(() {
          _selectedImage = file;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context, {required DateTime? initialDate, required Function(DateTime) onDateSelected}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    setState(() { _isSaving = true; });

    final updateData = PlantUpdate(
      nickname: _nicknameController.text.isNotEmpty ? _nicknameController.text : null,
      plantType: _selectedPlantType, // 선택된 plantType 추가
      startDate: _startDate,
      lastWateredDate: _lastWateredDate,
      lastRepottedDate: _lastRepottedDate,
    );

    try {
      final updatedPlant = await ApiService.updatePlant(widget.plantId, updateData, _selectedImage);
      // 광고를 보여주고, 광고가 닫힌 후에 UI를 업데이트합니다.
      AdService.showInterstitialAd(onAdDismissed: () {
        if (mounted) {
          setState(() {
            _plantFuture = Future.value(updatedPlant);
            _isEditMode = false;
            _resultForReturn = updatedPlant;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('정보가 수정되었습니다.')));
        }
      });
    } catch (e) {
      logger.e('식물 정보 수정 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수정에 실패했습니다.')));
      }
    } finally {
      if (mounted) {
        setState(() { _isSaving = false; });
      }
    }
  }

  Future<void> _deletePlant() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('식물 삭제'),
        content: const Text('정말로 이 식물을 삭제하시겠어요? 이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deletePlant(widget.plantId);
        if(mounted) {
          // 삭제 성공 시, 이전 화면(리스트)에 true를 반환하며 즉시 닫습니다.
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        logger.e('식물 삭제 실패: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제에 실패했습니다.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        // 저장 중이 아닐 때만 뒤로가기가 동작하도록 합니다.
        if (!_isSaving) {
          Navigator.of(context).pop(_resultForReturn);
        }
      },
      child: FutureBuilder<Plant>(
        future: _plantFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !_isEditMode) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return Scaffold(body: Center(child: Text('정보를 불러오는데 실패했습니다: ${snapshot.error}')));
          }
          if (!snapshot.hasData) {
            return const Scaffold(body: Center(child: Text('식물 정보가 없습니다.')));
          }
          final plant = snapshot.data!;

          return Scaffold(
            appBar: AppBar(
              title: Text(_isEditMode ? '정보 수정' : plant.nickname ?? '식물 상세'),
              backgroundColor: Colors.white,
              actions: [
                if (!_isEditMode)
                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deletePlant),
                TextButton(
                  onPressed: _isSaving ? null : (_isEditMode ? _saveChanges : () => _toggleEditMode(plant)),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isEditMode ? '저장' : '수정'),
                ),
              ],
            ),
            // body 구조를 Column으로 변경하여 배너 광고 추가
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: _isEditMode ? _buildEditView(plant) : _buildDetailView(plant),
                  ),
                ),
                // --- 배너 광고 위젯 ---
                // SafeArea로 감싸서 시스템 네비게이션 바와 겹치지 않도록 합니다.
                SafeArea(
                  top: false, // 상단에는 SafeArea를 적용하지 않습니다.
                  child: const BannerAdWidget(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- 상세보기 위젯 ---
  Widget _buildDetailView(Plant plant) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[200],
            backgroundImage: plant.imageUrl != null
                ? NetworkImage(plant.imageUrl!)
                : const AssetImage('assets/default_plant.png') as ImageProvider,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            plant.nickname ?? '이름 없는 식물',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            plant.plantType ?? '종류 미지정',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
        const Divider(height: 48, thickness: 1),
        _buildDetailInfoRow(Icons.calendar_today_outlined, '함께한 지', '${plant.decisionDay + 1}일째'),
        _buildDetailInfoRow(
            Icons.water_drop_outlined,
            '마지막 물 준 날',
            plant.lastWateredDate != null ? DateFormat('yyyy.MM.dd').format(plant.lastWateredDate!) : '기록 없음'),
        _buildDetailInfoRow(
            Icons.update,
            '다음 물 줄 날',
            nextWateringText,
            highlight: plant.isWateringNeeded),
        _buildDetailInfoRow(
            Icons.yard_outlined,
            '마지막 분갈이',
            plant.lastRepottedDate != null ? DateFormat('yyyy.MM.dd').format(plant.lastRepottedDate!) : '기록 없음'),
        const Divider(height: 48, thickness: 1),
        const Text(
          '식물 정보',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          plant.description ?? '등록된 정보가 없습니다.',
          style: TextStyle(color: Colors.grey[700], height: 1.5),
        ),
        const SizedBox(height: 24),
        const Text(
          '관리 방법',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          plant.careInfo ?? '등록된 정보가 없습니다.',
          style: TextStyle(color: Colors.grey[700], height: 1.5),
        ),
      ],
    );
  }

  Widget _buildDetailInfoRow(IconData icon, String title, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          const SizedBox(width: 16),
          Text(title, style: TextStyle(fontSize: 15, color: Colors.grey[800])),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.redAccent : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // --- 수정하기 위젯 ---
  Widget _buildEditView(Plant plant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Center(
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[200],
              backgroundImage: _selectedImage != null
                  ? FileImage(_selectedImage!)
                  : (plant.imageUrl != null ? NetworkImage(plant.imageUrl!) : const AssetImage('assets/default_plant.png')) as ImageProvider?,
              child: _selectedImage == null && plant.imageUrl == null
                  ? const Icon(Icons.camera_alt, color: Colors.grey, size: 40)
                  : Stack(
                      children: [
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.edit, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        TextFormField(
          controller: _nicknameController,
          decoration: const InputDecoration(labelText: '식물 애칭'),
        ),
        const SizedBox(height: 24),
        // --- 식물 종류 드롭다운 ---
        _isLoadingTypes
            ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
            : DropdownButtonFormField<String>(
                value: _selectedPlantType,
                decoration: const InputDecoration(labelText: '식물 종류'),
                items: _plantTypeOptions
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPlantType = value;
                  });
                },
              ),
        const SizedBox(height: 24),
        TextFormField(
          readOnly: true,
          controller: _startDateController,
          decoration: const InputDecoration(labelText: '키우기 시작한 날짜', suffixIcon: Icon(Icons.calendar_today)),
          onTap: () => _selectDate(context, initialDate: _startDate, onDateSelected: (date) {
            setState(() {
              _startDate = date;
              _startDateController.text = DateFormat('yyyy-MM-dd').format(date);
            });
          }),
        ),
        const SizedBox(height: 24),
        TextFormField(
          readOnly: true,
          controller: _lastWateredDateController,
          decoration: const InputDecoration(labelText: '마지막으로 물 준 날짜', suffixIcon: Icon(Icons.water_drop_outlined)),
          onTap: () => _selectDate(context, initialDate: _lastWateredDate, onDateSelected: (date) {
            setState(() {
              _lastWateredDate = date;
              _lastWateredDateController.text = DateFormat('yyyy-MM-dd').format(date);
            });
          }),
        ),
        const SizedBox(height: 24),
        TextFormField(
          readOnly: true,
          controller: _lastRepottedDateController,
          decoration: const InputDecoration(labelText: '마지막 분갈이 날짜', suffixIcon: Icon(Icons.yard_outlined)),
          onTap: () => _selectDate(context, initialDate: _lastRepottedDate, onDateSelected: (date) {
            setState(() {
              _lastRepottedDate = date;
              _lastRepottedDateController.text = DateFormat('yyyy-MM-dd').format(date);
            });
          }),
        ),
      ],
    );
  }
}