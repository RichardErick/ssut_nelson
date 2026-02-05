import 'dart:async';
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
  int? get userId => _user?['id'] as int?;

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

  final Completer<void> _authStateCompleter = Completer<void>();
  Future<void> get authReady => _authStateCompleter.future;

  bool hasPermission(String permissionCode) {
    try {
      if (_permissions.isNotEmpty) {
        final has = _permissions.contains(permissionCode);
        debugPrint('[AUTH] Permiso "$permissionCode" (desde backend): $has');
        return has;
      }
    } catch (_) {
      debugPrint('[AUTH] hasPermission fallback por error en _permissions');
    }
    return _hasRoleBasedPermission(permissionCode);
  }

  bool _hasRoleBasedPermission(String permissionCode) {
    print('DEBUG: Verificando permiso "$permissionCode" para rol $_role');
    switch (_role) {
      case UserRole.administradorSistema:
        // Solo puede ver documentos
        final hasPermission = permissionCode == 'ver_documento';
        print('DEBUG: AdministradorSistema - Permiso "$permissionCode": $hasPermission');
        return hasPermission;
        
      case UserRole.administradorDocumentos:
        // Puede ver, subir, editar metadatos y borrar documentos (códigos alineados con permisos del sistema)
        final allowedPermissions = [
          'ver_documento',
          'subir_documento',
          'editar_metadatos',
          'borrar_documento'
        ];
        final hasPermission = allowedPermissions.contains(permissionCode);
        print('DEBUG: AdministradorDocumentos - Permiso "$permissionCode": $hasPermission');
        return hasPermission;
        
      case UserRole.contador:
        // Puede ver y subir documentos
        final allowedPermissions = [
          'ver_documento',
          'subir_documento'
        ];
        final hasPermission = allowedPermissions.contains(permissionCode);
        print('DEBUG: Contador - Permiso "$permissionCode": $hasPermission');
        return hasPermission;
        
      case UserRole.gerente:
        // Solo puede ver documentos
        final hasPermission = permissionCode == 'ver_documento';
        print('DEBUG: Gerente - Permiso "$permissionCode": $hasPermission');
        return hasPermission;
        
      default:
        print('DEBUG: Rol desconocido - Permiso "$permissionCode": false');
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
    debugPrint('[AUTH] _loadAuthState() iniciando...');
    try {
      // Cargar token de forma segura
      _token = await _secureStorage.read(key: 'auth_token');
      debugPrint('[AUTH] token leído: ${_token != null ? "SÍ (${_token!.length} chars)" : "null"}');

      if (_token != null) {
        final prefs = await SharedPreferences.getInstance();
        final roleString = prefs.getString('user_role');
        final userDataString = prefs.getString('user_data');
        final userNameString = prefs.getString('user_name');
        final permissionsString = prefs.getString('user_permissions');

        // 🔍 LOGGING EXHAUSTIVO para diagnosticar problema de cambio de usuario
        debugPrint('[AUTH] ==================== DATOS ALMACENADOS ====================');
        debugPrint('[AUTH] user_role: $roleString');
        debugPrint('[AUTH] user_name: $userNameString');
        debugPrint('[AUTH] user_data: $userDataString');
        debugPrint('[AUTH] user_permissions length: ${permissionsString?.length ?? 0}');
        debugPrint('[AUTH] ==========================================================');

        // Cargar datos de usuario primero (necesario para contexto de rol)
        if (userDataString != null) {
          try {
            _user = jsonDecode(userDataString);
            debugPrint('[AUTH] ✅ user_data parseado: id=${_user?['id']}, nombreUsuario=${_user?['nombreUsuario']}, nombreCompleto=${_user?['nombreCompleto']}');
          } catch (e) {
            debugPrint('[AUTH] ❌ Error parseando user_data: $e');
            // Fallback for old data format or persistent errors
            final username = prefs.getString('user_name');
            if (username != null) {
              _user = {'nombreUsuario': username};
              debugPrint('[AUTH] ⚠️ Usando fallback con user_name: $username');
            }
          }
        } else {
          debugPrint('[AUTH] ⚠️ user_data es NULL, usando fallback');
          // Fallback if user_data is missing
          final username = prefs.getString('user_name');
          if (username != null) {
            _user = {'nombreUsuario': username};
            debugPrint('[AUTH] Fallback user_name: $username');
          }
        }

        // Parsear rol CON contexto del usuario (username y nombre completo)
        if (roleString != null) {
          final userUsername = (_user?['nombreUsuario'] as String?) ?? '';
          final fullName = (_user?['nombreCompleto'] as String?) ?? '';
          _role = _parseRoleWithContext(roleString, userUsername, fullName);
          debugPrint('[AUTH] ✅ Rol parseado con contexto: $_role para usuario: $userUsername (fullName: $fullName)');
        }

        if (permissionsString != null) {
           try {
             final decoded = jsonDecode(permissionsString);
             if (decoded is List) {
               _permissions = decoded
                   .where((e) => e is String)
                   .map((e) => e as String)
                   .toList();
             } else {
               _permissions = [];
             }
           } catch (_) {
             _permissions = [];
           }
        }

        _isAuthenticated = true;
        debugPrint('[AUTH] _loadAuthState() -> isAuthenticated=true');

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
    } catch (e, st) {
      debugPrint('[AUTH] ERROR _loadAuthState: $e');
      debugPrint('[AUTH] stack: $st');
      _isAuthenticated = false;
      _token = null;
    }
    if (!_authStateCompleter.isCompleted) {
      _authStateCompleter.complete();
    }
    debugPrint('[AUTH] _loadAuthState() terminado -> isAuthenticated=$_isAuthenticated, notifyListeners()');
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
        _permissions = permisosList
            .map((e) => e is String ? e : (e is Map ? (e['codigo'] ?? e).toString() : e.toString()))
            .where((s) => s.isNotEmpty)
            .toList();
      } else {
        _permissions = [];
      }

      final roleString = (user['rol'] as String?) ?? 'Invitado';
      final userUsername = (user['nombreUsuario'] as String?) ?? '';
      final fullName = (user['nombreCompleto'] as String?) ?? '';
      _role = _parseRoleWithContext(roleString, userUsername, fullName);

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
                  const Duration(minutes: 10),
                );
              }
            }
          } else {
            _lockoutEndTime = DateTime.now().add(const Duration(minutes: 10));
          }
        } catch (_) {
          _lockoutEndTime = DateTime.now().add(const Duration(minutes: 10));
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

  UserRole _parseRoleWithContext(String roleName, String username, String fullName) {
    print('DEBUG: Parseando rol: "$roleName" para usuario: "$username" ($fullName)');
    final roleNameLower = roleName.toLowerCase().trim();
    final usernameLower = username.toLowerCase().trim();
    final fullNameLower = fullName.toLowerCase().trim();
    
    switch (roleNameLower) {
      case 'administradorsistema':
      case 'administrador sistema':
      case 'admin sistema':
      case 'system admin':
      case 'sysadmin':
        print('DEBUG: Rol mapeado a AdministradorSistema');
        return UserRole.administradorSistema;
      case 'administradordocumentos':
      case 'administrador documentos':
      case 'admin documentos':
      case 'document admin':
        print('DEBUG: Rol mapeado a AdministradorDocumentos');
        return UserRole.administradorDocumentos;
      case 'administrador':
      case 'admin':
      case 'administrator':
        // Para el rol genérico "Administrador", usar contexto del usuario
        // Si el nombre completo contiene "documentos" o el username es "doc_admin", es admin de documentos
        if (fullNameLower.contains('documentos') || 
            fullNameLower.contains('documento') ||
            usernameLower == 'doc_admin' ||
            usernameLower.contains('doc')) {
          print('DEBUG: Rol "Administrador" mapeado a AdministradorDocumentos por contexto (documentos)');
          return UserRole.administradorDocumentos;
        }
        // Si el nombre completo contiene "sistema" o el username es "admin", es admin de sistema
        else if (fullNameLower.contains('sistema') || 
                 usernameLower == 'admin') {
          print('DEBUG: Rol "Administrador" mapeado a AdministradorSistema por contexto (sistema)');
          return UserRole.administradorSistema;
        } else {
          // Por defecto, si no hay contexto claro, asignar AdministradorDocumentos
          print('DEBUG: Rol "Administrador" mapeado a AdministradorDocumentos por defecto');
          return UserRole.administradorDocumentos;
        }
      case 'contador':
      case 'accountant':
        print('DEBUG: Rol mapeado a Contador');
        return UserRole.contador;
      case 'gerente':
      case 'manager':
        print('DEBUG: Rol mapeado a Gerente');
        return UserRole.gerente;
      default:
        print('DEBUG: Rol no reconocido: "$roleName", asignando AdministradorDocumentos por defecto');
        return UserRole.administradorDocumentos;
    }
  }

  UserRole _parseRole(String roleName) {
    // Función de compatibilidad que llama a la nueva función con contexto vacío
    return _parseRoleWithContext(roleName, '', '');
  }
}
