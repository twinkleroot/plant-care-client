import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/login_screen.dart';
import '../screens/plant_list_screen.dart';
import '../services/app_open_ad_service.dart';
import '../models/system_config_model.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // 날짜 비교 유틸 (Asia/Seoul 기준)
  bool _isWithinDate(String startDate, String endDate) {
    // 단순 문자열 비교도 가능하지만 (YYYY-MM-DD 포맷이므로), 정확성을 위해 파싱
    // 여기서는 간단히 현재 한국 시간 날짜 문자열과 비교
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    return todayStr.compareTo(startDate) >= 0 && todayStr.compareTo(endDate) <= 0;
  }

  // 버전 비교 유틸 (current < target 이면 true)
  bool _isUpdateNeeded(String currentVersion, String targetVersion) {
    List<int> c = currentVersion.split('.').map(int.parse).toList();
    List<int> t = targetVersion.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      if (c[i] < t[i]) return true;
      if (c[i] > t[i]) return false;
    }
    return false;
  }

  void _checkLoginStatus() async {
    // 광고 로드와 토큰 확인을 동시에 진행
    final adService = Provider.of<AppOpenAdService>(context, listen: false);
    const storage = FlutterSecureStorage();

    // 광고 로드에 최대 3초의 제한 시간을 둡니다.
    // 3초가 지나도 로드가 안 되면 강제로 완료 처리하고 넘어갑니다.
    // Future.wait를 사용하여 광고 로드(성공 또는 실패)와 토큰 확인을 병렬로 대기
    try {
      // SharedPreferences를 통해 첫 실행 여부 확인
      final prefs = await SharedPreferences.getInstance();
      final bool isFirstRun = prefs.getBool('is_first_run') ?? true;

      // 시스템 설정 조회 및 강제 업데이트 체크
      final systemConfig = await ApiService.getSystemConfig();
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 강제 업데이트 체크
      if (systemConfig.forceUpdate != null &&
          _isWithinDate(systemConfig.forceUpdate!.startDate, systemConfig.forceUpdate!.endDate) &&
          _isUpdateNeeded(currentVersion, systemConfig.forceUpdate!.version)) {

        if (!mounted) return;
        // 강제 업데이트 다이얼로그 표시 (barrierDismissible: false)
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('필수 업데이트 안내'),
            content: const Text('원활한 서비스 이용을 위해 최신 버전으로 업데이트가 필요합니다.'),
            actions: [
              TextButton(
                child: const Text('업데이트 하러 가기'),
                onPressed: () {
                  // 스토어 이동 로직 (패키지명 수정 필요)
                  launchUrl(Uri.parse("https://play.google.com/store/apps/details?id=com.heeblings.plant_care_app"), mode: LaunchMode.externalApplication);
                },
              ),
            ],
          ),
        );
        return; // 진행 중단
      }

      final results = await Future.wait([
        !isFirstRun
          ? adService.preloadAd().timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                logger.w('앱 오픈 광고 로드 시간 초과. 광고 없이 진행합니다.');
                return null;
              },
            )
          : Future.value(null),

        storage.read(key: 'appToken'),
        // 최소 스플래시 표시 시간 2초도 함께 기다립니다.
        Future.delayed(const Duration(seconds: 2)),
      ]);

      final token = results[1] as String?; // 토큰 확인 결과

      // 첫 실행 플래그를 false로 변경 (다음 실행부터는 광고 나옴)
      if (isFirstRun) {
        await prefs.setBool('is_first_run', false);
        logger.i('앱 최초 실행 감지: 앱 오픈 광고를 건너뜁니다.');
      }

      if (!mounted) return;

      if (isFirstRun) {
        // 시스템 설정을 다음 화면으로 넘겨서 공지사항 등을 처리할 수 있게 함
        _navigateToNextScreen(token, systemConfig);
      } else {
        adService.showAdIfAvailable(onAdDismissed: () {
          _navigateToNextScreen(token, systemConfig);
        });
      }
    } catch (e) {
      // 만약 예상치 못한 에러가 발생하더라도 앱이 멈추지 않도록 안전장치 추가
      logger.e('스플래시 초기화 중 에러 발생: $e');
      if (!mounted) return;
      // 에러 발생 시 안전하게 로그인 화면으로 이동 (또는 토큰 확인 후 이동)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // 화면 이동 로직을 분리하여 재사용
  void _navigateToNextScreen(String? token, SystemConfig? config) {
    if (!mounted) return;
    if (token != null) {
      Navigator.of(context).pushReplacement(
        // config를 전달
        MaterialPageRoute(builder: (_) => PlantListScreen(systemConfig: config)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 60, color: Colors.green),
            SizedBox(height: 20),
            Text('오늘, 초록 한 스푼', style: TextStyle(fontSize: 20, color: Colors.black54)),
            SizedBox(height: 48),
            // 로딩 인디케이터
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
