import 'package:flutter/material.dart';
import 'package:plant_care_app/models/plant_model.dart';
import 'package:plant_care_app/screens/login_screen.dart';
import 'package:plant_care_app/screens/plant_add_screen.dart';
import 'package:plant_care_app/screens/plant_detail_screen.dart';
import 'package:plant_care_app/services/api_service.dart';
import 'package:plant_care_app/widgets/banner_ad_widget.dart';
import 'package:plant_care_app/widgets/plant_card.dart';
import '../utils/logger.dart';

// 정렬 옵션을 관리하기 위한 Enum
enum SortOption {
  latest('최신 등록순', 'plantId,desc'),
  nextWatering('다음 물 줄 날 순', 'nextWateringDate,asc'),
  startDate('함께한 날 순', 'startDate,asc');

  const SortOption(this.displayName, this.queryParam);
  final String displayName;
  final String queryParam;
}

class PlantListScreen extends StatefulWidget {
  const PlantListScreen({super.key});

  @override
  State<PlantListScreen> createState() => _PlantListScreenState();
}

class _PlantListScreenState extends State<PlantListScreen> {
  final List<Plant> _plants = [];
  bool _isLoading = false;
  int _currentPage = 0;
  bool _hasNextPage = true; // 더 불러올 페이지가 있는지 확인
  final ScrollController _scrollController = ScrollController();

  // 현재 정렬 상태를 관리하는 변수
  SortOption _currentSortOption = SortOption.latest;

  @override
  void initState() {
    super.initState();
    _loadPlants();
    _scrollController.addListener(() {
      // 스크롤이 끝에 도달했고, 로딩 중이 아니며, 다음 페이지가 있을 때
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && !_isLoading && _hasNextPage) {
        _loadPlants();
      }
    });
  }

  Future<void> _loadPlants() async {
    if (_isLoading) return; // 이미 로딩 중이면 중복 실행 방지
    setState(() {
      _isLoading = true;
    });

    try {
      // 현재 정렬 옵션을 API 호출 시 전달
      final newPlants = await ApiService.getPlants(_currentPage, _currentSortOption.queryParam);
      setState(() {
        if (newPlants.isEmpty) {
          _hasNextPage = false; // 새로 불러온 데이터가 없으면 더 이상 페이지 없음
        } else {
          _plants.addAll(newPlants);
          _currentPage++;
        }
        _isLoading = false;
      });
    } catch (e) {
      logger.e('식물 리스트 로딩 실패: $e');
      // TODO: 에러 처리 (예: 로그인 토큰 만료 시 로그인 화면으로 보내기)
      if (!mounted) return;
      setState(() { _isLoading = false; });
    }
  }

  // 리스트를 새로고침하는 로직
  Future<void> _refreshPlants() async {
    setState(() {
      _plants.clear();
      _currentPage = 0;
      _hasNextPage = true;
      _isLoading = false; // 기존 로딩 상태 초기화
    });
    // cancel any ongoing requests if necessary
    await _loadPlants();
  }

  // 정렬 옵션 변경 시 호출될 메서드
  void _sortAndRefresh(SortOption newSortOption) {
    if (_currentSortOption != newSortOption) {
      setState(() {
        _currentSortOption = newSortOption;
      });
      _refreshPlants(); // 리스트를 초기화하고 새로 불러옴
    }
  }

  void _handleWaterPlant(int plantId) async {
    try {
      final updatedPlant = await ApiService.waterPlant(plantId);
      final index = _plants.indexWhere((p) => p.plantId == plantId);
      if (index != -1) {
        setState(() {
          _plants[index] = updatedPlant;
        });
      }
    } catch (e) {
      logger.e('물 주기 업데이트 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('업데이트에 실패했습니다.')));
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 정렬 옵션을 보여주는 Modal Bottom Sheet
  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('정렬 기준', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 10),
                ...SortOption.values.map((option) {
                  return ListTile(
                    title: Text(option.displayName),
                    onTap: () {
                      Navigator.pop(context); // Bottom sheet 닫기
                      _sortAndRefresh(option);
                    },
                    trailing: _currentSortOption == option
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('내 식물들', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          // 정렬 버튼 및 로그아웃 버튼
          // ❗️ [수정] 정렬 버튼 UI 변경
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: '정렬',
            onPressed: _showSortOptions,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () {
              ApiService.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      // body 구조를 Column으로 변경하여 광고 추가
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshPlants,
              color: Colors.green,
              child: Column(
                children: [
                  // --- 새 식물 등록 버튼 ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(builder: (_) => const PlantAddScreen()),
                        );
                        if (result == true) {
                          _refreshPlants();
                        }
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('새 식물 등록', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  // --- 식물 리스트 ---
                  Expanded(
                    child: ListView.builder(
                      // ❗️ [수정] 하단 패딩 제거
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: _scrollController,
                      itemCount: _plants.length + 1,
                      itemBuilder: (context, index) {
                        if (index < _plants.length) {
                          final plant = _plants[index];
                          return GestureDetector(
                            onTap: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => PlantDetailScreen(plantId: plant.plantId)),
                              );

                              if (result is Plant) {
                                final plantIndex =
                                _plants.indexWhere((p) => p.plantId == result.plantId);
                                if (plantIndex != -1) {
                                  setState(() {
                                    _plants[plantIndex] = result;
                                  });
                                }
                              }
                              else if (result == true) {
                                _refreshPlants();
                              }
                            },
                            child: PlantCard(
                              plant: plant,
                              onWatered: () => _handleWaterPlant(plant.plantId),
                            ),
                          );
                        }
                        if (_isLoading) {
                          return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ));
                        }
                        if (!_hasNextPage && _plants.isNotEmpty) {
                          return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text("더 이상 식물이 없어요."),
                              ));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
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
  }
}
