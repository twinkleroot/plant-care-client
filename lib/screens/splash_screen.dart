import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:plant_care_app/screens/login_screen.dart';
import 'package:plant_care_app/screens/plant_list_screen.dart';
import 'package:plant_care_app/services/app_open_ad_service.dart';
import 'package:provider/provider.dart';
import '../utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        _navigateToNextScreen(token);
      } else {
        // 광고가 닫힌 후(또는 로드 실패 시)에만 화면 전환을 실행합니다.
        adService.showAppOpenAdIfAvailable(onAdDismissed: () {
          _navigateToNextScreen(token);
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
  void _navigateToNextScreen(String? token) {
    if (!mounted) return;
    if (token != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PlantListScreen()),
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
