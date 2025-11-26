import 'dart:async'; // Completer를 위해 import 추가
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/logger.dart';

// 앱 오픈 광고 로드 및 표시를 관리하는 서비스
class AppOpenAdService {
  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  bool _isAdLoaded = false;

  // 로드 중인지 확인하는 플래그 (중복 로드 방지)
  bool _isLoadingAd = false;

  // 광고 로드 완료를 보장하기 위한 Completer 추가
  Completer<void> _appOpenAdCompleter = Completer<void>();

  String? get _adUnitId {
    if (kIsWeb) return '';
    return dotenv.env['GOOGLE_ADMOB_ID_ANDROID_APP_OPEN']!;
  }

  // 모든 광고를 미리 로드합니다. (스플래시 화면에서 호출)
  Future<void> preloadAd() async {
    if (_adUnitId == null) {
      logger.e('앱 오픈 광고 ID가 .env 파일에 설정되지 않았습니다.');
      return;
    }

    // Completer 초기화
    _appOpenAdCompleter = Completer<void>();

    // await 없이 로드 "시작"
    _loadAppOpenAd();

    // 로드가 완료될 때까지 기다립니다. (성공/실패 모두 포함)
    await _appOpenAdCompleter.future;
  }

  // --- 앱 오프닝 광고 (App Open) ---
  Future<void> _loadAppOpenAd() async {
    // 이미 로드되어 있거나, 로딩 중이면 중단
    if (_isAdLoaded || _isLoadingAd) return;

    if (_adUnitId == null) {
      logger.e('앱 오픈 광고 ID가 없습니다.');
      if (!_appOpenAdCompleter.isCompleted) {
        _appOpenAdCompleter.complete();
      }
      return;
    }

    _isLoadingAd = true; // 로딩 시작

    await AppOpenAd.load(
      adUnitId: _adUnitId!,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isAdLoaded = true;
          _isLoadingAd = false; // 로딩 종료
          logger.i('AppOpenAd loaded.');
          _completeCompleter();
        },
        onAdFailedToLoad: (error) {
          _isAdLoaded = false;
          _isLoadingAd = false; // 로딩 종료
          logger.e('AppOpenAd failed to load: $error');
          _completeCompleter();

          // 로드 실패 시 30초 후 재시도 (무한 재시도 방지를 위해 횟수 제한을 둘 수도 있음)
          Future.delayed(const Duration(seconds: 30), () {
            // 앱이 여전히 활성 상태일 때만 재시도
            if (!_isAdLoaded) {
              logger.i('Retrying to load AppOpenAd...');
              _loadAppOpenAd();
            }
          });
        },
      ),
    );
  }

  void _completeCompleter() {
    if (!_appOpenAdCompleter.isCompleted) {
      _appOpenAdCompleter.complete();
    }
  }

  void showAdIfAvailable({required VoidCallback onAdDismissed}) {
    if (_isShowingAd || !_isAdLoaded || _appOpenAd == null) {
      logger.w('AppOpenAd not available or already showing.');
      onAdDismissed();
      // 광고가 없으면 다음을 위해 로드 시도
      if (!_isLoadingAd) {
        _loadAppOpenAd();
      }
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        _isAdLoaded = false;
        onAdDismissed();
        // 다음 광고를 미리 로드
        _loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        _isAdLoaded = false;
        logger.e('AppOpenAd failed to show: $error');
        onAdDismissed();
      },
    );

    _appOpenAd!.show();
  }
}
