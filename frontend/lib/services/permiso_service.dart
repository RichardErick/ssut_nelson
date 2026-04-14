import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/permiso.dart';
import '../models/permiso_usuario_registro.dart';
import 'api_service.dart';

class PermisoService {
  final ApiService _apiService;

  PermisoService(this._apiService);

  /// Lista todos los permisos (catálogo) - requiere rol AdministradorSistema
  Future<List<Permiso>> getAll() async {
    try {
      final response = await _apiService.get('/permisos');
      final list = response.data as List;
      return list
          .map((p) => Permiso.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Permisos de un usuario (admin) - GET api/permisos/usuarios/{id}
  Future<List<PermisoUsuarioEntry>> getPermisosUsuarioAdmin(int userId) async {
    try {
      final response = await _apiService.get('/permisos/usuarios/$userId');
      final data = response.data as Map<String, dynamic>;
      final permisosList = data['permisos'] as List? ?? [];
      return permisosList
          .map((p) {
            final map = p as Map<String, dynamic>;
            final permiso = Permiso.fromJson({
              'id': map['id'],
              'codigo': map['codigo'],
              'nombre': map['nombre'],
              'descripcion': map['descripcion'],
              'modulo': map['modulo'],
              'activo': map['activo'] ?? true,
            });
            return PermisoUsuarioEntry(
              permiso: permiso,
              roleHas: map['roleHas'] as bool? ?? false,
              userHas: map['userHas'] as bool? ?? false,
              isDenied: map['isDenied'] as bool? ?? false,
            );
          })
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Asignar permiso a usuario - POST api/permisos/usuarios/asignar
  Future<void> asignarPermiso(int usuarioId, int permisoId) async {
    await _apiService.post(
      '/permisos/usuarios/asignar',
      data: {'usuarioId': usuarioId, 'permisoId': permisoId},
    );
  }

  /// Revocar permiso a usuario - POST api/permisos/usuarios/revocar
  Future<void> revocarPermiso(int usuarioId, int permisoId) async {
    await _apiService.post(
      '/permisos/usuarios/revocar',
      data: {'usuarioId': usuarioId, 'permisoId': permisoId},
    );
  }

  /// Obtiene todos los permisos del usuario actual (logueado)
  Future<List<Permiso>> getPermisosUsuario() async {
    try {
      final response = await _apiService.get('/permisos/usuario');
      final data = response.data as Map<String, dynamic>;
      final permisosList =
          (data['permisos'] as List)
              .map((p) => Permiso.fromJson(p as Map<String, dynamic>))
              .toList();
      return permisosList;
    } catch (e) {
      return [];
    }
  }

  /// Verifica si el usuario tiene un permiso específico
  Future<bool> tienePermiso(String codigoPermiso) async {
    try {
      final permisos = await getPermisosUsuario();
      return permisos.any((p) => p.codigo == codigoPermiso);
    } catch (e) {
      return false;
    }
  }

  /// Obtiene los permisos del usuario de forma estática (usando Provider)
  static Future<List<Permiso>> getPermisosUsuarioStatic(
    BuildContext context,
  ) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final service = PermisoService(apiService);
    return await service.getPermisosUsuario();
  }

  /// Verifica si el usuario tiene un permiso de forma estática
  static Future<bool> tienePermisoStatic(
    BuildContext context,
    String codigoPermiso,
  ) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final service = PermisoService(apiService);
    return await service.tienePermiso(codigoPermiso);
  }
}
