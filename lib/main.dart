import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:plant_care_app/screens/splash_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // main 함수에서 비동기 작업을 수행하기 위해 필요
  WidgetsFlutterBinding.ensureInitialized();

  // .env 파일 로드. 앱 시작 시 딱 한 번만 호출하면 됩니다.
  await dotenv.load(fileName: ".env");

  MobileAds.instance.initialize();

  KakaoSdk.init(nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY']!);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '내 화초 시들기 전에: 물주기 알림',
      theme: ThemeData(
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: const Color(0xFFF5F5F3),
          fontFamily: 'Pretendard'
      ),
      home: const SplashScreen(),
    );
  }
}