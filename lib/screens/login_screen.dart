import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:plant_care_app/screens/plant_list_screen.dart';
import 'package:plant_care_app/services/api_service.dart';
import '../utils/logger.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _loginWithKakao(BuildContext context) async {
    try {
      // 카카오톡 설치 여부 확인
      final installed = await isKakaoTalkInstalled();
      // 카카오톡으로 로그인 시도
      OAuthToken token = await (installed
          ? UserApi.instance.loginWithKakaoTalk()
          : UserApi.instance.loginWithKakaoAccount());

      // 카카오 로그인 성공 후, 우리 서버에 로그인 요청
      await ApiService.kakaoLogin(token.accessToken);

      if (!context.mounted) return; // 비동기 작업 후 context 사용 전 확인

      // 로그인 성공 시 식물 리스트 화면으로 이동
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
          child: GestureDetector(
            onTap: () => _loginWithKakao(context),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE500), // 카카오 노란색
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/kakao_symbol.png', width: 24), // ❗️'assets/kakao_symbol.png' 이미지 필요
                  const SizedBox(width: 10),
                  const Text(
                    '카카오로 시작하기',
                    style: TextStyle(
                      color: Color.fromRGBO(0, 0, 0, 0.85),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
