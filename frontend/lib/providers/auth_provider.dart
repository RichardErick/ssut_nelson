import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/user_role.dart';
import '../services/api_service.dart';
import '../services/audit_service.dart';
import '../utils/error_helper.dart';

class AuthProvider extends ChangeNotifier {
  // Almacenamiento seguro para datos sensibles (token de autenticación)
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  AuditService? _auditService;

  void setAuditService(AuditService service) {
    _auditService = service;
  }

  bool _isAuthenticated = false;
  String? _token;
  Map<String, dynamic>? _user;
  UserRole _role = UserRole.invitado;

  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  UserRole get role => _role;

  int _failedAttempts = 0;
  DateTime? _lockoutEndTime;

  bool get isLocked {
    if (_lockoutEndTime == null) return false;
    if (DateTime.now().isAfter(_lockoutEndTime!)) {
      _resetLockout();
      return false;
    }
    return true;
  }

  Duration get remainingLockoutTime {
    if (_lockoutEndTime == null) return Duration.zero;
    return _lockoutEndTime!.difference(DateTime.now());
  }

  AuthProvider() {
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    try {
      // Cargar token de forma segura
      _token = await _secureStorage.read(key: 'auth_token');

      if (_token != null) {
        final prefs = await SharedPreferences.getInstance();
        final roleString = prefs.getString('user_role');
        final userDataString = prefs.getString('user_data');

        if (roleString != null) {
          _role = _parseRole(roleString);
        }

        if (userDataString != null) {
          try {
            _user = jsonDecode(userDataString);
          } catch (e) {
            // Fallback for old data format or persistent errors
            final username = prefs.getString('user_name');
            if (username != null) {
              _user = {'nombreUsuario': username};
            }
          }
        } else {
          // Fallback if user_data is missing
          final username = prefs.getString('user_name');
          if (username != null) {
            _user = {'nombreUsuario': username};
          }
        }
        _isAuthenticated = true;

        // Configurar header Authorization si ya hay contexto
        try {
          final apiService = Provider.of<ApiService>(
            navigatorKey.currentContext!,
            listen: false,
          );
          apiService.setAuthToken(_token!);
        } catch (_) {
          // Ignorar si aún no hay context
        }
      }
    } catch (e) {
      print('Error cargando estado de autenticación: $e');
      _isAuthenticated = false;
      _token = null;
    }
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    if (isLocked) {
      throw Exception(
        'Cuenta bloqueada temporalmente. Intente en ${remainingLockoutTime.inSeconds} segundos.',
      );
    }

    final apiService = Provider.of<ApiService>(
      navigatorKey.currentContext!,
      listen: false,
    );

    try {
      final response = await apiService.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String?;
      final user = data['user'] as Map<String, dynamic>?;

      if (token == null || user == null) {
        throw Exception('Respuesta inválida del servidor');
      }

      _resetLockout();
      _token = token;
      _isAuthenticated = true;
      _user = user;

      final roleString = (user['rol'] as String?) ?? 'Invitado';
      _role = _parseRole(roleString);

      apiService.setAuthToken(_token!);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(_user));
      await prefs.setString('user_role', roleString);
      await prefs.setString('user_name', username);

      await _secureStorage.write(key: 'auth_token', value: _token!);

      _auditService?.logEvent(
        action: 'LOGIN_SUCCESS',
        module: 'AUTH',
        details: 'Inicio de sesión exitoso',
        username: username,
      );

      notifyListeners();
    } catch (e) {
      _failedAttempts++;

      _auditService?.logEvent(
        action: 'LOGIN_FAILED',
        module: 'AUTH',
        details: 'Intentos: $_failedAttempts',
        username: username,
      );

      notifyListeners();

      final msg = ErrorHelper.getErrorMessage(e);
      throw Exception(msg);
    }
  }

  void _resetLockout() {
    _failedAttempts = 0;
    _lockoutEndTime = null;
  }

  Future<void> logout() async {
    _isAuthenticated = false;
    _token = null;
    _user = null;

    try {
      final apiService = Provider.of<ApiService>(
        navigatorKey.currentContext!,
        listen: false,
      );
      apiService.clearAuthToken();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    await prefs.remove('user_role');
    await prefs.remove('user_name');

    // Eliminar token del almacenamiento seguro
    await _secureStorage.delete(key: 'auth_token');

    _auditService?.logEvent(
      action: 'LOGOUT',
      module: 'AUTH',
      details: 'Cierre de sesión',
      username: _user?['nombreUsuario'],
    );

    notifyListeners();
  }

  UserRole _parseRole(String roleName) {
    switch (roleName) {
      case 'AdministradorSistema':
        return UserRole.administradorSistema;
      case 'Administrador':
        return UserRole.administradorSistema;
      case 'AdministradorDocumentos':
        return UserRole.administradorDocumentos;
      case 'ArchivoCentral':
        return UserRole.archivoCentral;
      case 'TramiteDocumentario':
        return UserRole.tramiteDocumentario;
      default:
        return UserRole.invitado;
    }
  }
}
