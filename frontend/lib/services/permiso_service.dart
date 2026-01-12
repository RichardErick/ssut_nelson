import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/permiso.dart';
import 'api_service.dart';

class PermisoService {
  final ApiService _apiService;

  PermisoService(this._apiService);

  /// Obtiene todos los permisos del usuario actual
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
