import 'dart:async';

// 앱 전역에서 이미지 처리 완료 이벤트를 방송하기 위한 스트림 서비스 (싱글턴)
class FcmUpdateStream {
  static final FcmUpdateStream _instance = FcmUpdateStream._internal();
  factory FcmUpdateStream() => _instance;
  FcmUpdateStream._internal();

  // plantId를 전달하는 스트림 컨트롤러.
  // 여러 곳에서 구독할 수 있도록 broadcast 스트림으로 생성합니다.
  final _controller = StreamController<int>.broadcast();

  // 외부에서 이 스트림을 구독(listen)할 수 있도록 getter를 제공합니다.
  Stream<int> get stream => _controller.stream;

  // 외부(예: main.dart의 FCM 리스너)에서 이벤트를 방송하는 메서드입니다.
  void notifyUpdate(int plantId) {
    _controller.sink.add(plantId);
  }

  // 앱이 종료될 때 스트림 컨트롤러를 닫아 메모리 누수를 방지합니다. (필요 시 호출)
  void dispose() {
    _controller.close();
  }
}