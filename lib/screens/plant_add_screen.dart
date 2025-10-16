import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:plant_care_app/models/plant_create_model.dart';
import 'package:plant_care_app/services/api_service.dart';
import 'package:plant_care_app/widgets/banner_ad_widget.dart';
import '../services/ad_service.dart';
import '../utils/logger.dart';

class PlantAddScreen extends StatefulWidget {
  const PlantAddScreen({super.key});

  @override
  State<PlantAddScreen> createState() => _PlantAddScreenState();
}

class _PlantAddScreenState extends State<PlantAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _customPlantTypeController = TextEditingController();

  final _startDateController = TextEditingController();
  final _lastWateredDateController = TextEditingController();

  File? _selectedImage;
  DateTime? _startDate;
  DateTime? _lastWateredDate;
  List<String> _plantTypeOptions = ['직접 입력'];
  String? _selectedPlantType;
  bool _showCustomPlantTypeInput = false;
  bool _isRegistering = false;
  bool _isLoadingTypes = true;

  @override
  void initState() {
    super.initState();
    _fetchPlantTypes();
  }

  Future<void> _fetchPlantTypes() async {
    try {
      final types = await ApiService.getPlantTypes();
      if (mounted) {
        setState(() {
          _plantTypeOptions.insertAll(0, types);
          _isLoadingTypes = false;
        });
      }
    } catch (e) {
      logger.e('식물 종류 목록 로딩 실패: $e');
      // 실패해도 '직접 입력'은 가능하므로 계속 진행
      if (mounted) {
        setState(() {
          _isLoadingTypes = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
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

  void _submitForm() async {
    if (_formKey.currentState!.validate() && !_isRegistering) {
      if (_startDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('키우기 시작한 날짜를 선택해주세요.')),
        );
        return;
      }

      setState(() { _isRegistering = true; });

      final plantData = PlantCreate(
        nickname: _nicknameController.text.isNotEmpty ? _nicknameController.text : null,
        plantType: _showCustomPlantTypeInput
            ? (_customPlantTypeController.text.isNotEmpty ? _customPlantTypeController.text : null)
            : (_selectedPlantType != '직접 입력' ? _selectedPlantType : null),
        startDate: _startDate!,
        lastWateredDate: _lastWateredDate,
      );

      File? imageFileToDelete = _selectedImage;

      try {
        await ApiService.createPlant(plantData, _selectedImage);

        // 광고를 보여주고, 광고가 닫힌 후에 후처리 작업을 수행합니다.
        AdService.showInterstitialAd(onAdDismissed: () async {
          // 임시 파일 삭제
          if (imageFileToDelete != null) {
            await imageFileToDelete.delete();
            logger.i('임시 이미지 파일 삭제 성공: ${imageFileToDelete.path}');
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('식물이 등록되었습니다!')),
            );
            Navigator.of(context).pop(true); // true를 반환하여 리스트 새로고침
          }
        });
      } catch (e) {
        logger.e('식물 등록 실패: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('등록에 실패했습니다. 다시 시도해주세요.')),
          );
        }
      } finally {
        if (mounted) {
          setState(() { _isRegistering = false; });
        }
      }
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _customPlantTypeController.dispose();
    _startDateController.dispose();
    _lastWateredDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 식물 등록'),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Center(
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                          child: _selectedImage == null
                              ? const Icon(Icons.camera_alt, color: Colors.grey, size: 40)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nicknameController,
                      decoration: const InputDecoration(labelText: '식물 애칭 (10자 이내로 입력해주세요.)'),
                      maxLength: 10, // ❗️ 글자 수 제한 UI 표시
                      validator: (value) { // ❗️ 유효성 검사 로직
                        if (value != null && value.length > 10) {
                          return '애칭은 10자 이내로 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    _isLoadingTypes
                        ? const Center(child: CircularProgressIndicator())
                        : DropdownButtonFormField<String>(
                      value: _selectedPlantType,
                      decoration: const InputDecoration(labelText: '식물 종류'),
                      items: _plantTypeOptions
                          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPlantType = value;
                          _showCustomPlantTypeInput = (value == '직접 입력');
                        });
                      },
                    ),
                    if (_showCustomPlantTypeInput) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _customPlantTypeController,
                        decoration: const InputDecoration(labelText: '식물 종류 직접 입력'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextFormField(
                      readOnly: true,
                      controller: _startDateController,
                      decoration: const InputDecoration(
                        labelText: '키우기 시작한 날짜 (필수)',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
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
                      decoration: const InputDecoration(
                        labelText: '마지막으로 물 준 날짜',
                        suffixIcon: Icon(Icons.water_drop_outlined),
                      ),
                      onTap: () => _selectDate(context, initialDate: _lastWateredDate, onDateSelected: (date) {
                        setState(() {
                          _lastWateredDate = date;
                          _lastWateredDateController.text = DateFormat('yyyy-MM-dd').format(date);
                        });
                      }),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _isRegistering ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isRegistering
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                          : const Text('등록하기', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // SafeArea로 감싸서 시스템 네비게이션 바와 겹치지 않도록 합니다.
          SafeArea(
            top: false, // 상단에는 SafeArea를 적용하지 않습니다.
            child: const BannerAdWidget(),
          ),
        ],
      ),
    );
  }
}
