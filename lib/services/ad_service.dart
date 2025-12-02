import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';

class AdService {
  static InterstitialAd? _interstitialAd;
  static bool _isLoading = false;  // 로드 중 중복 요청을 방지하기 위한 플래그

  // 광고 노출 빈도 제어를 위한 카운터
  static int _attemptCounter = 0;
  // 3번에 1번만 노출 (1, 2번째는 건너뛰고 3번째에 노출)
  static const int _frequencyCap = 3;

  // 마지막으로 전면 광고가 닫힌 시간
  static DateTime? _lastAdDismissedTime;

  // 최근에 전면 광고를 봤는지 확인하는 메서드 (5초 이내)
  static bool get recentlyShowedInterstitial {
    if (_lastAdDismissedTime == null) return false;
    final difference = DateTime.now().difference(_lastAdDismissedTime!);
    return difference.inSeconds < 5;
  }

  // 전면 광고를 미리 로드하는 메서드
  static void loadInterstitialAd() {
    // 이미 로드되었거나 로드 중이면 중복 실행 방지
    if (_isLoading || _interstitialAd != null) return;

    _isLoading = true; // 로딩 시작

    final adUnitId = dotenv.env['GOOGLE_ADMOB_ID_ANDROID_FULLPAGE'];
    if (adUnitId == null) {
      logger.w('전면 광고 ID가 .env 파일에 설정되지 않았습니다.');
      _isLoading = false;
      return;
    }

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          logger.i('전면 광고 로드 성공: $ad');
          _interstitialAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          logger.e('전면 광고 로드 실패: $error');
          _interstitialAd?.dispose();
          _interstitialAd = null;
          _isLoading = false;

          // 반복적인 충돌을 방지하기 위해, 실패 시 1분 후에 재시도를 예약합니다.
          Future.delayed(const Duration(minutes: 1), () {
            loadInterstitialAd();
          });
        },
      ),
    );
  }

  // 전면 광고를 표시하는 메서드
  // 광고가 닫힌 후 실행될 콜백 함수(onAdDismissed)를 인자로 받습니다.
  static void showInterstitialAd({required VoidCallback onAdDismissed}) {
    // 빈도 제어 로직
    _attemptCounter++;
    logger.i('전면 광고 요청 횟수: $_attemptCounter');

    // 설정한 빈도(3회)에 도달하지 않았다면 광고를 건너뛰고 바로 다음 동작 수행
    if (_attemptCounter % _frequencyCap != 0) {
      logger.i('빈도 제한에 의해 전면 광고를 건너뜁니다. (3번에 1번 노출)');
      onAdDismissed();
      return;
    }

    if (_interstitialAd == null) {
      logger.w('전면 광고가 준비되지 않았습니다. 다음 액션을 바로 실행합니다.');
      onAdDismissed(); // 광고가 준비되지 않았으면 바로 다음 액션 수행
      loadInterstitialAd(); // 다음을 위해 로드 시도
      return;
    }

    // 광고의 전체 화면 이벤트를 처리하는 콜백을 설정합니다.
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        // 광고가 닫혔을 때 호출
      onAdFailedToShowFullScreenContent: (ad, error) {
        logger.e('전면 광고 표시 실패: $error');
        onAdDismissed(); // 광고 표시 실패 시에도 반드시 다음 액션을 수행합니다.
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // 다음 광고를 위해 미리 로드합니다.
      },
      // 광고 표시에 실패했을 때 호출
      onAdDismissedFullScreenContent: (ad) {
        logger.i('전면 광고가 닫혔습니다.');
        // 광고가 닫힌 시간 기록
        _lastAdDismissedTime = DateTime.now();

        onAdDismissed(); // 광고가 정상적으로 닫혔을 때 다음 액션을 수행합니다.
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // 다음 광고를 위해 미리 로드합니다.
      },
    );

    // 광고를 표시합니다.
    _interstitialAd!.show();
    _interstitialAd = null; // 광고가 한번 표시되면 참조를 제거하여 중복 표시를 방지합니다.
  }
}
