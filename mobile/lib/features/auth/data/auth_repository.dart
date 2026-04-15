import 'package:dio/dio.dart';
import 'package:crosssync/core/api/api_client.dart';
import 'package:crosssync/shared/models/user.dart';

class AuthRepository {
  AuthRepository() : _dio = ApiClient.instance.dio;

  final Dio _dio;
  final _client = ApiClient.instance;

  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final res = await _dio.post('/auth/register', data: {
      'email': email,
      'password': password,
      'name': name,
    });
    await _client.saveTokens(
      accessToken: res.data['access_token'] as String,
      refreshToken: res.data['refresh_token'] as String,
    );
    return getMe();
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    await _client.saveTokens(
      accessToken: res.data['access_token'] as String,
      refreshToken: res.data['refresh_token'] as String,
    );
    return getMe();
  }

  Future<UserModel> getMe() async {
    final res = await _dio.get('/auth/me');
    return UserModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> logout() => _client.clearTokens();
}
