import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:provider/provider.dart';
import '../screens/plant_list_screen.dart';
import '../services/api_service.dart';
import '../services/app_open_ad_service.dart';
import '../utils/logger.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _loginWithKakao(BuildContext context) async {
    // Provider를 통해 인스턴스를 가져와서 pauseAds 호출
    context.read<AppOpenAdService>().pauseAds();

    try {
      // 1. FCM 토큰을 먼저 발급받습니다.
      final fcmToken = await FirebaseMessaging.instance.getToken();
      logger.i('✅ FCM Token: $fcmToken');
      if (fcmToken == null) {
        logger.i('⛔️ FCM Token 발급에 실패했습니다.');
        // 사용자에게 알림을 표시할 수 있습니다.
      }

      OAuthToken token;
      // 카카오톡 설치 여부 확인
      if (await isKakaoTalkInstalled()) {
        try {
          // 카카오톡이 설치되어 있으면, 카카오톡으로 로그인
          logger.i('카카오톡으로 로그인 시도');
          token = await UserApi.instance.loginWithKakaoTalk();
        } catch (error) {
          logger.i('카카오톡으로 로그인 실패 $error');
          // 사용자가 카카오톡 설치 후, 취소한 경우 등
          // 카카오 계정으로 로그인 시도 (웹 브라우저)
          if (error is PlatformException && error.code == 'CANCELED') {
            // 사용자가 명시적으로 취소한 것이므로 여기서 중단
            return;
          }
          logger.i('카카오 계정으로 로그인 재시도');
          token = await UserApi.instance.loginWithKakaoAccount(
            prompts: [Prompt.login],
          );
        }
      } else {
        // 카카오톡이 없으면, 웹 브라우저를 통해 카카오 계정으로 로그인
        logger.i('카카오 계정으로 로그인 시도');
        token = await UserApi.instance.loginWithKakaoAccount(
          prompts: [Prompt.login],
        );
      }

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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // assets/images/kakao_login_medium_narrow.png 파일이 존재해야 합니다.
              GestureDetector(
                onTap: () => _loginWithKakao(context),
                child: Image.asset('assets/images/kakao_login_medium_narrow.png'),
              ),
              const SizedBox(height: 24), // 간격 추가
              // 안내 문구
              const Text(
                "잊지 않고 물주기 알림을 보내드리기 위해\n회원가입 및 로그인이 필요합니다.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  height: 1.5, // 줄 간격 조절
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
