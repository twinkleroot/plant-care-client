import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';

class AdService {
  static InterstitialAd? _interstitialAd;
  static bool _isAdLoaded = false;

  // 전면 광고를 미리 로드하는 메서드
  static void loadInterstitialAd() {
    // 이미 로드되었거나 로드 중이면 중복 실행 방지
    if (_isAdLoaded || _interstitialAd != null) return;

    final adUnitId = dotenv.env['GOOGLE_ADMOB_ID_ANDROID_FULLPAGE'];
    if (adUnitId == null) {
      logger.w('전면 광고 ID가 .env 파일에 설정되지 않았습니다.');
      return;
    }

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
          logger.i('전면 광고 로드 성공');
        },
        onAdFailedToLoad: (error) {
          _isAdLoaded = false;
          _interstitialAd?.dispose();
          logger.e('전면 광고 로드 실패: $error');
        },
      ),
    );
  }

  // 전면 광고를 표시하는 메서드
  // 광고가 닫힌 후 실행될 콜백 함수(onAdDismissed)를 인자로 받습니다.
  static void showInterstitialAd({required VoidCallback onAdDismissed}) {
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        // 광고가 닫혔을 때 호출
        onAdDismissedFullScreenContent: (ad) {
          onAdDismissed(); // 다음 액션 수행
          ad.dispose();
          _interstitialAd = null; // 광고 리소스 해제
          loadInterstitialAd(); // 다음 광고를 위해 미리 로드
        },
        // 광고 표시에 실패했을 때 호출
        onAdFailedToShowFullScreenContent: (ad, error) {
          logger.w('전면 광고 표시 실패: $error');
          onAdDismissed(); // 광고 없이 바로 다음 액션 수행
          ad.dispose();
          _interstitialAd = null;
          loadInterstitialAd(); // 다음 광고를 위해 미리 로드
        },
      );
      _interstitialAd!.show();
      _isAdLoaded = false; // 광고가 한번 표시되면 로드되지 않은 상태로 변경
    } else {
      logger.w('전면 광고가 준비되지 않았습니다.');
      onAdDismissed(); // 광고가 준비되지 않았으면 바로 다음 액션 수행
      loadInterstitialAd(); // 다음을 위해 로드 시도
    }
  }
}
