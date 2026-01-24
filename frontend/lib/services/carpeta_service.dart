import 'package:provider/provider.dart';

import '../main.dart';
import '../models/carpeta.dart';
import 'api_service.dart';

class CarpetaService {
  Future<List<Carpeta>> getAll({String? gestion, bool incluirInactivas = false}) async {
    try {
      final apiService = Provider.of<ApiService>(
        navigatorKey.currentContext!,
        listen: false,
      );
      final response = await apiService.get(
        '/carpetas', 
        queryParameters: {
          if (gestion != null) 'gestion': gestion,
          'incluirInactivas': incluirInactivas,
        }
      );
      return (response.data as List)
          .map((json) => Carpeta.fromJson(json))
          .toList();
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }

  Future<List<Carpeta>> getArbol(String gestion) async {
    try {
      final apiService = Provider.of<ApiService>(
        navigatorKey.currentContext!,
        listen: false,
      );
      final response = await apiService.get('/carpetas/arbol/$gestion');
      return (response.data as List)
          .map((json) => Carpeta.fromJson(json))
          .toList();
    } catch (e) {
      print('API Error: $e');
      rethrow;
    }
  }

  Future<Carpeta> create(CreateCarpetaDTO dto) async {
    final apiService = Provider.of<ApiService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    final response = await apiService.post('/carpetas', data: dto.toJson());
    // El response solo devuelve id, nombre, codigo, gestion, fecha. 
    // Para devolver una Carpeta completa con campos por defecto, creamos una instancia
    // o hacemos getById. Por rendimiento, asumimos campos.
    return Carpeta(
      id: response.data['id'],
      nombre: response.data['nombre'],
      codigo: response.data['codigo'],
      gestion: response.data['gestion'],
      fechaCreacion: DateTime.parse(response.data['fechaCreacion']),
      activo: true,
      subcarpetas: [],
    );
  }

  Future<void> update(int id, UpdateCarpetaDTO dto) async {
    final apiService = Provider.of<ApiService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    await apiService.put('/carpetas/$id', data: dto.toJson());
  }

  Future<void> delete(int id, {bool hard = false}) async {
    final apiService = Provider.of<ApiService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    await apiService.delete('/carpetas/$id?hard=$hard');
  }
}
