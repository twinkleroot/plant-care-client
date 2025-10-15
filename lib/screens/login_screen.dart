import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:plant_care_app/screens/plant_list_screen.dart';
import 'package:plant_care_app/services/api_service.dart';
import '../utils/logger.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _loginWithKakao(BuildContext context) async {
    try {
      // 1. FCM 토큰을 먼저 발급받습니다.
      final fcmToken = await FirebaseMessaging.instance.getToken();
      logger.i('✅ FCM Token: $fcmToken');
      if (fcmToken == null) {
        logger.i('⛔️ FCM Token 발급에 실패했습니다.');
        // 사용자에게 알림을 표시할 수 있습니다.
      }

      // 2. 카카오톡으로 로그인 시도
      final installed = await isKakaoTalkInstalled();
      OAuthToken token = await (installed
          ? UserApi.instance.loginWithKakaoTalk()
          : UserApi.instance.loginWithKakaoAccount());

      // 3. 카카오 accessToken과 발급받은 fcmToken을 함께 우리 서버로 전송합니다.
      await ApiService.kakaoLogin(token.accessToken, fcmToken);

      if (!context.mounted) return; // 비동기 작업 후 context 사용 전 확인

      // 4. 로그인 성공 시 식물 리스트 화면으로 이동합니다.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PlantListScreen()),
      );
    } catch (error) {
      logger.e('카카오 로그인 실패: $error');
      if (!context.mounted) return;
      // 에러 처리 (예: 스낵바 표시)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인에 실패했습니다. 다시 시도해주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 50.0),
          // GestureDetector와 Container를 ElevatedButton으로 변경
          child: ElevatedButton(
            onPressed: () => _loginWithKakao(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, // 배경색을 흰색으로 변경
              foregroundColor: Colors.grey[300], // 클릭 시 효과 색상
              elevation: 2, // 약간의 그림자 효과
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 50), // 버튼 높이 및 너비 설정
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/kakao_symbol.png', width: 24),
                const SizedBox(width: 10),
                const Text(
                  '카카오로 시작하기',
                  style: TextStyle(
                    color: Color.fromRGBO(0, 0, 0, 0.85), // 카카오 공식 텍스트 색상
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
