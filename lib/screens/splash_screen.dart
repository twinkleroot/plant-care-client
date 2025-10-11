import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:plant_care_app/screens/login_screen.dart';
import 'package:plant_care_app/screens/plant_list_screen.dart';

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
    const storage = FlutterSecureStorage();
    // 저장된 토큰이 있는지 확인
    final token = await storage.read(key: 'appToken');

    // 잠시 후 화면 전환
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return; // 위젯이 unmounted된 경우를 대비한 방어 코드

      if (token != null) {
        // 토큰이 있으면 식물 리스트 화면으로
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PlantListScreen()),
        );
      } else {
        // 토큰이 없으면 로그인 화면으로
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
            Text('내 손안의 작은 정원', style: TextStyle(fontSize: 18, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
