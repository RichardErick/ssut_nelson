import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/usuario.dart';
import 'api_service.dart';

class UsuarioService {
  Future<List<Usuario>> getAll({bool incluirInactivos = false}) async {
    try {
      final apiService = Provider.of<ApiService>(
        navigatorKey.currentContext!,
        listen: false,
      );
      final response = await apiService.get(
        '/usuarios',
        queryParameters: {'incluirInactivos': incluirInactivos},
      );
      return (response.data as List)
          .map((json) => Usuario.fromJson(json))
          .toList();
    } catch (e) {
      print('Error al obtener usuarios: $e');
      rethrow;
    }
  }

  Future<Usuario> create(CreateUsuarioDTO dto) async {
    try {
      final apiService = Provider.of<ApiService>(
        navigatorKey.currentContext!,
        listen: false,
      );
      final response = await apiService.post('/usuarios', data: dto.toJson());
      return Usuario.fromJson(response.data);
    } catch (e) {
      print('Error al crear usuario: $e');
      rethrow;
    }
  }

  Future<void> deleteUsuario(int id, {bool hard = false}) async {
    try {
      final apiService = Provider.of<ApiService>(
        navigatorKey.currentContext!,
        listen: false,
      );
      await apiService.delete('/usuarios/$id?hard=$hard');
    } catch (e) {
      print('Error al eliminar usuario: $e');
      rethrow;
    }
  }

  /// Rechazar solicitud de registro: borra la solicitud y deniega el registro (solo Admin).
  Future<void> rechazarSolicitudRegistro(int id) async {
    try {
      final apiService = Provider.of<ApiService>(
        navigatorKey.currentContext!,
        listen: false,
      );
      await apiService.post('/usuarios/$id/rechazar');
    } catch (e) {
      print('Error al rechazar solicitud: $e');
      rethrow;
    }
  }

  Future<Usuario> getById(int id) async {
    try {
      final apiService = Provider.of<ApiService>(
        navigatorKey.currentContext!,
        listen: false,
      );
      final response = await apiService.get('/usuarios/$id');
      return Usuario.fromJson(response.data);
    } catch (e) {
      print('Error al obtener usuario: $e');
      rethrow;
    }
  }

  /// Obtiene el usuario actual (perfil). Pasa [context] desde la pantalla para cargar con el contexto correcto.
  Future<Usuario> getCurrent([BuildContext? context]) async {
    try {
      final ctx = context ?? navigatorKey.currentContext;
      if (ctx == null) throw Exception('No hay contexto disponible para cargar el perfil');
      final apiService = Provider.of<ApiService>(ctx, listen: false);
      final meResponse = await apiService.get('/auth/me');
      final data = meResponse.data is Map<String, dynamic> ? meResponse.data as Map<String, dynamic> : Map<String, dynamic>.from(meResponse.data as Map);
      final idRaw = data['id'] ?? data['Id'];
      final id = idRaw is int ? idRaw : int.tryParse(idRaw?.toString() ?? '');
      if (id != null && id > 0) {
        final response = await apiService.get('/usuarios/$id');
        return Usuario.fromJson(response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : Map<String, dynamic>.from(response.data as Map));
      }
      return Usuario.fromJson(data);
    } catch (e) {
      print('Error al obtener perfil: $e');
      rethrow;
    }
  }

  Future<void> updateRol(int id, String rol) async {
    try {
      final apiService = Provider.of<ApiService>(
        navigatorKey.currentContext!,
        listen: false,
      );
      await apiService.put('/usuarios/$id/rol', data: {'rol': rol});
    } catch (e) {
      print('Error al actualizar rol: $e');
      rethrow;
    }
  }

  Future<void> updateEstado(int id, bool activo) async {
    try {
      final apiService = Provider.of<ApiService>(
        navigatorKey.currentContext!,
        listen: false,
      );
      await apiService.put('/usuarios/$id/estado', data: {'activo': activo});
    } catch (e) {
      print('Error al actualizar estado: $e');
      rethrow;
    }
  }

  Future<void> updateUsuario(int id, UpdateUsuarioDTO dto) async {
    try {
      final apiService = Provider.of<ApiService>(
        navigatorKey.currentContext!,
        listen: false,
      );
      await apiService.put('/usuarios/$id', data: dto.toJson());
    } catch (e) {
      print('Error al actualizar usuario: $e');
      rethrow;
    }
  }
}
