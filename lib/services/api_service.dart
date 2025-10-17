import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // MediaType을 위해 import 추가
import 'dart:convert';
import 'package:plant_care_app/models/auth_response_model.dart';
import 'package:plant_care_app/models/plant_model.dart';
import 'package:plant_care_app/models/plant_create_model.dart';
import 'package:plant_care_app/models/push_message_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/plant_update_model.dart';
import '../screens/login_screen.dart';
import '../utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/navigator_service.dart';

// 커스텀 예외 클래스
class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
}

class ApiService {
  // Android 에뮬레이터에서는 localhost 대신 10.0.2.2를 사용해야 합니다.
  // 실제 기기에서 테스트 시에는 컴퓨터의 IP 주소 (예: http://192.168.1.10:8080)를 사용하세요.
  // static const String _baseUrl = 'http://10.0.2.2:8080';
  static final String _baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://192.168.35.145:8080';
  static const _storage = FlutterSecureStorage();

  // 중앙 집중식 응답 및 에러 처리 메서드
  static Future<String> _handleResponse(http.Response response) async {
    // 401 Unauthorized 에러 발생 시 (토큰 만료 등)
    if (response.statusCode == 401) {
      await logout(); // 토큰 삭제
      // 전역 navigatorKey를 사용하여 로그인 화면으로 이동
      NavigatorService.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
      );
      throw UnauthorizedException('세션이 만료되었습니다. 다시 로그인해주세요.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return utf8.decode(response.bodyBytes);
    } else {
      final errorBody = utf8.decode(response.bodyBytes);
      throw Exception('API 요청 실패: ${response.statusCode}, Body: $errorBody');
    }
  }

  // Multipart 요청을 위한 별도의 핸들러
  static Future<String> _handleMultipartResponse(http.StreamedResponse response) async {
    if (response.statusCode == 401) {
      await logout();
      NavigatorService.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
      );
      throw UnauthorizedException('세션이 만료되었습니다. 다시 로그인해주세요.');
    }

    final responseBody = await response.stream.bytesToString();
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    } else {
      throw Exception('API 요청 실패: ${response.statusCode}, Body: $responseBody');
    }
  }

  // 카카오 로그인 후 우리 앱 서버에 로그인/가입 요청
  static Future<AuthResponse> kakaoLogin(String kakaoAccessToken, String? fcmToken) async {
    final url = Uri.parse('$_baseUrl/plant-app/auth/kakao');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'accessToken': kakaoAccessToken,
        'fcmToken': fcmToken,
      }),
    );

    if (response.statusCode == 200) {
      final authResponse = AuthResponse.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      // 발급받은 우리 앱 토큰을 안전하게 저장
      await _storage.write(key: 'appToken', value: authResponse.appToken);
      return authResponse;
    } else {
      throw Exception('Failed to login with server. url : $url, body : ${response.body}');
    }
  }

  // 식물 리스트 조회
  static Future<List<Plant>> getPlants(int page, String sort) async {
    final token = await _storage.read(key: 'appToken');
    if (token == null) throw Exception('No auth token found.');

    final url = Uri.parse('$_baseUrl/plant-app/plants?page=$page&size=20&sort=$sort');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    final responseBody = await _handleResponse(response);
    final Map<String, dynamic> body = jsonDecode(responseBody);
    final List<dynamic> content = body['content'];
    return content.map((json) => Plant.fromJson(json)).toList();
  }

  // 식물 종류 목록
  static Future<List<String>> getPlantTypes() async {
    final prefs = await SharedPreferences.getInstance();
    const cacheKey = 'plant_types_cache';
    const timestampKey = 'plant_types_timestamp';

    final cachedTimestamp = prefs.getInt(timestampKey);

    // 캐시가 존재하고, 저장된 지 24시간이 지나지 않았다면 캐시된 데이터를 사용합니다.
    if (cachedTimestamp != null) {
      final cacheAge = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(cachedTimestamp));
      if (cacheAge.inHours < 24) {
        final cachedData = prefs.getString(cacheKey);
        if (cachedData != null) {
          logger.i("식물 종류: 캐시에서 로드합니다.");
          final List<dynamic> body = jsonDecode(cachedData);
          return body.map((json) => json['plantTypeName'] as String).toList();
        }
      }
    }

    // 캐시가 없거나 만료되었다면 API를 호출합니다.
    logger.i("식물 종류: API에서 새로고침합니다.");
    final token = await _storage.read(key: 'appToken');
    if (token == null) throw Exception('No auth token found.');

    final url = Uri.parse('$_baseUrl/plant-app/plants/plant-types');
    final response = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
    });

    // API 응답의 원본(문자열)을 그대로 저장해야 jsonDecode가 가능합니다.
    final responseBody = await _handleResponse(response);
    final List<dynamic> body = jsonDecode(responseBody);

    // API 호출 성공 시, 새로운 데이터와 현재 시간을 기기에 저장합니다.
    await prefs.setString(cacheKey, responseBody);
    await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);

    return body.map((json) => json['plantTypeName'] as String).toList();
  }

  // 식물 등록
  static Future<Plant> createPlant(PlantCreate plant, File? imageFile) async {
    final token = await _storage.read(key: 'appToken');
    if (token == null) throw Exception('No auth token found.');

    final url = Uri.parse('$_baseUrl/plant-app/plants');
    final request = http.MultipartRequest('POST', url);

    // 헤더 추가
    request.headers['Authorization'] = 'Bearer $token';

    // JSON 파트 추가
    request.files.add(http.MultipartFile.fromString(
      'request',
      jsonEncode(plant.toJson()),
      contentType: MediaType('application', 'json'),
    ));

    // 이미지 파일 파트 추가 (있는 경우)
    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      ));
    }

    final response = await request.send();
    final responseBody = await _handleMultipartResponse(response);
    return Plant.fromJson(jsonDecode(responseBody));
  }

  // 식물 상세 정보 조회
  static Future<Plant> getPlantDetail(int plantId) async {
    final token = await _storage.read(key: 'appToken');
    if (token == null) throw Exception('No auth token found.');
    final url = Uri.parse('$_baseUrl/plant-app/plants/$plantId');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    final responseBody = await _handleResponse(response);
    return Plant.fromJson(jsonDecode(responseBody));
  }

  // 식물 정보 수정
  static Future<Plant> updatePlant(int plantId, PlantUpdate plant, File? imageFile) async {
    final token = await _storage.read(key: 'appToken');
    if (token == null) throw Exception('No auth token found.');

    final url = Uri.parse('$_baseUrl/plant-app/plants/$plantId');
    final request = http.MultipartRequest('PUT', url);
    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(http.MultipartFile.fromString(
      'request',
      jsonEncode(plant.toJson()),
      contentType: MediaType('application', 'json'),
    ));

    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    }

    final response = await request.send();
    final responseBody = await _handleMultipartResponse(response);
    return Plant.fromJson(jsonDecode(responseBody));
  }

  // 식물 삭제
  static Future<void> deletePlant(int plantId) async {
    final token = await _storage.read(key: 'appToken');
    if (token == null) throw Exception('No auth token found.');
    final url = Uri.parse('$_baseUrl/plant-app/plants/$plantId');
    final response = await http.delete(url, headers: {'Authorization': 'Bearer $token'});
    await _handleResponse(response); // 응답 처리만 하고 반환값은 없음
  }

  // 물 줬음
  static Future<Plant> waterPlant(int plantId) async {
    final token = await _storage.read(key: 'appToken');
    if (token == null) throw Exception('No auth token found.');
    final url = Uri.parse('$_baseUrl/plant-app/plants/$plantId/water');
    final response = await http.put(url, headers: {'Authorization': 'Bearer $token'});
    final responseBody = await _handleResponse(response);
    return Plant.fromJson(jsonDecode(responseBody));
  }

  // 메시지 목록 조회
  static Future<List<PushMessage>> getPushMessages() async {
    final token = await _storage.read(key: 'appToken');
    if (token == null) throw Exception('No auth token found.');

    final url = Uri.parse('$_baseUrl/plant-app/push-messages');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    final responseBody = await _handleResponse(response);
    final List<dynamic> body = jsonDecode(responseBody);
    return body.map((json) => PushMessage.fromJson(json)).toList();
  }

  // 메시지 읽음 처리
  static Future<PushMessage> markMessageAsRead(int messageId) async {
    final token = await _storage.read(key: 'appToken');
    if (token == null) throw Exception('No auth token found.');

    final url = Uri.parse('$_baseUrl/plant-app/push-messages/$messageId/read');
    final response = await http.put(url, headers: {'Authorization': 'Bearer $token'});
    final responseBody = await _handleResponse(response);
    return PushMessage.fromJson(jsonDecode(responseBody));
  }

  // 메시지 삭제
  static Future<void> deleteMessage(int messageId) async {
    final token = await _storage.read(key: 'appToken');
    if (token == null) throw Exception('No auth token found.');

    final url = Uri.parse('$_baseUrl/plant-app/push-messages/$messageId');
    final response = await http.delete(url, headers: {'Authorization': 'Bearer $token'});
    await _handleResponse(response);
  }

  static Future<bool> hasUnreadMessages() async {
    final token = await _storage.read(key: 'appToken');
    if (token == null) throw Exception('No auth token found.');

    final url = Uri.parse('$_baseUrl/plant-app/push-messages/unread-status');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    final responseBody = await _handleResponse(response);
    final Map<String, dynamic> body = jsonDecode(responseBody);
    return body['hasUnread'] ?? false;
  }

  // 로그아웃
  static Future<void> logout() async {
    await _storage.delete(key: 'appToken');
  }

}
