import 'package:provider/provider.dart';

import '../main.dart';
import '../models/movimiento.dart';
import 'api_service.dart';

class MovimientoService {
  Future<List<Movimiento>> getAll() async {
    final apiService = Provider.of<ApiService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    final response = await apiService.get('/movimientos');
    return (response.data as List)
        .map((json) => Movimiento.fromJson(json))
        .toList();
  }

  Future<List<Movimiento>> getByDocumentoId(int documentoId) async {
    final apiService = Provider.of<ApiService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    final response = await apiService.get(
      '/movimientos/documento/$documentoId',
    );
    return (response.data as List)
        .map((json) => Movimiento.fromJson(json))
        .toList();
  }

  Future<Movimiento> create(CreateMovimientoDTO dto) async {
    final apiService = Provider.of<ApiService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    final response = await apiService.post('/movimientos', data: dto.toJson());
    return Movimiento.fromJson(response.data);
  }

  Future<Movimiento> devolverDocumento(
    int movimientoId, {
    String? observaciones,
  }) async {
    final apiService = Provider.of<ApiService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    final response = await apiService.post(
      '/movimientos/devolver',
      data: {'movimientoId': movimientoId, 'observaciones': observaciones},
    );
    return Movimiento.fromJson(response.data);
  }
}
