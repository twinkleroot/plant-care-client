class AuthResponse {
  final String appToken;
  final int userId;
  final String? nickname;

  AuthResponse({required this.appToken, required this.userId, this.nickname});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      appToken: json['appToken'],
      userId: json['userId'],
      nickname: json['nickname'],
    );
  }
}
