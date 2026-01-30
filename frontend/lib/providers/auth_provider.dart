import 'dart:convert';

import 'package:dio/dio.dart';
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
  UserRole _role = UserRole.contador; // Rol por defecto

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

  DateTime? get lockoutEndTime => _lockoutEndTime;

  Duration get remainingLockoutTime {
    if (_lockoutEndTime == null) return Duration.zero;
    return _lockoutEndTime!.difference(DateTime.now());
  }

  List<String> _permissions = [];
  List<String> get permissions => _permissions;

  bool hasPermission(String permissionCode) {
    // Verificar permisos basados en la matriz de roles específica
    return _hasRoleBasedPermission(permissionCode);
  }

  bool _hasRoleBasedPermission(String permissionCode) {
    switch (_role) {
      case UserRole.administradorSistema:
        // Solo puede ver documentos
        return permissionCode == 'ver_documento';
        
      case UserRole.administradorDocumentos:
        // Puede ver, crear, subir, editar y borrar documentos + crear carpetas
        return [
          'ver_documento',
          'crear_documento',
          'subir_documento', 
          'editar_metadatos',
          'borrar_documento',
          'crear_carpeta',
          'borrar_carpeta'
        ].contains(permissionCode);
        
      case UserRole.contador:
        // Puede ver y subir documentos
        return [
          'ver_documento',
          'crear_documento',
          'subir_documento'
        ].contains(permissionCode);
        
      case UserRole.gerente:
        // Solo puede ver documentos
        return permissionCode == 'ver_documento';
        
      default:
        return false;
    }
  }

  // Función auxiliar para verificar si es administrador de sistema
  bool get isSystemAdmin => _role == UserRole.administradorSistema;
  
  // Función auxiliar para verificar si puede gestionar permisos de usuarios
  bool get canManageUserPermissions => _role == UserRole.administradorSistema;

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
        final permissionsString = prefs.getString('user_permissions');

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

        if (permissionsString != null) {
           try {
             _permissions = List<String>.from(jsonDecode(permissionsString));
           } catch (_) {
             _permissions = [];
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
      final permisosList = data['permisos'] as List?;

      if (token == null || user == null) {
        throw Exception('Respuesta inválida del servidor');
      }

      _resetLockout();
      _token = token;
      _isAuthenticated = true;
      _user = user;
      
      if (permisosList != null) {
        _permissions = permisosList.map((e) => e.toString()).toList();
      } else {
        _permissions = [];
      }

      final roleString = (user['rol'] as String?) ?? 'Invitado';
      _role = _parseRole(roleString);

      apiService.setAuthToken(_token!);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(_user));
      await prefs.setString('user_role', roleString);
      await prefs.setString('user_name', username);
      await prefs.setString('user_permissions', jsonEncode(_permissions));

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

      // Handle server-side lockout (HTTP 423)
      if (e is DioException && e.response?.statusCode == 423) {
        // Intentar leer los segundos de bloqueo desde el backend (preferir campo numérico)
        try {
          final data = e.response?.data;
          if (data is Map<String, dynamic>) {
            final seconds = data['remainingSeconds'];
            if (seconds is int) {
              _lockoutEndTime = DateTime.now().add(Duration(seconds: seconds));
            } else if (seconds is num) {
              _lockoutEndTime = DateTime.now().add(
                Duration(seconds: seconds.toInt()),
              );
            } else {
              final message = data['message']?.toString() ?? '';
              final regex = RegExp(r'(\d+)\s*segundos');
              final match = regex.firstMatch(message);
              if (match != null) {
                final parsedSeconds = int.parse(match.group(1)!);
                _lockoutEndTime = DateTime.now().add(
                  Duration(seconds: parsedSeconds),
                );
              } else {
                _lockoutEndTime = DateTime.now().add(
                  const Duration(seconds: 30),
                );
              }
            }
          } else {
            _lockoutEndTime = DateTime.now().add(const Duration(seconds: 30));
          }
        } catch (_) {
          _lockoutEndTime = DateTime.now().add(const Duration(seconds: 30));
        }
      }

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
    _permissions = [];

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
    await prefs.remove('user_permissions');

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
    final roleNameLower = roleName.toLowerCase().trim();
    switch (roleNameLower) {
      case 'administradorsistema':
      case 'administrador sistema':
      case 'admin sistema':
      case 'administrador':
      case 'admin':
      case 'administrator':
      case 'system admin':
      case 'sysadmin':
        return UserRole.administradorSistema;
      case 'administradordocumentos':
      case 'administrador documentos':
      case 'admin documentos':
      case 'document admin':
        return UserRole.administradorDocumentos;
      case 'contador':
      case 'accountant':
        return UserRole.contador;
      case 'gerente':
      case 'manager':
        return UserRole.gerente;
      default:
        // Si el rol no existe, asignar como Administrador de Sistema por defecto para admin users
        return UserRole.administradorSistema;
    }
  }
}
