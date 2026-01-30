import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio;
  final String baseUrl;

  ApiService({required this.baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ) {
    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, handler) {
          if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
            // TODO: Trigger logout or token refresh
            // navigatorKey.currentState?.pushReplacementNamed('/login');
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> getBytes(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(
        path, 
        queryParameters: queryParameters,
        options: Options(responseType: ResponseType.bytes),
      );
    } catch (e) {
      rethrow;
    }
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }
}
