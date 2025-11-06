import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:plant_care_app/screens/login_screen.dart';
import 'package:plant_care_app/screens/plant_list_screen.dart';
import 'package:plant_care_app/services/app_open_ad_service.dart';
import 'package:provider/provider.dart';

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

    // Future.wait를 사용하여 광고 로드(성공 또는 실패)와 토큰 확인을 병렬로 대기
    final results = await Future.wait([
      adService.preloadAd(), // 광고 로드를 시작하고 완료될 때까지 기다림
      storage.read(key: 'appToken'),
    ]);

    final token = results[1] as String?; // 토큰 확인 결과

    if (!mounted) return;

    // 광고가 닫힌 후(또는 로드 실패 시)에만 화면 전환을 실행합니다.
    adService.showAppOpenAdIfAvailable(onAdDismissed: () {
      if (!mounted) return; // 위젯이 unmounted된 경우를 대비한 방어 코드

      if (token != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PlantListScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
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
          ],
        ),
      ),
    );
  }
}
