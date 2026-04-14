import 'dart:async';

import '../models/registro_sincronizacion.dart';
import 'api_service.dart';
import 'auditoria_servicio.dart';

class SyncService {
  final ApiService _apiService;
  final AuditService _auditService;

  SyncService(this._apiService, this._auditService);

  // Simulación de historial local (en producción vendría de la BD)
  final List<SyncLog> _localHistory = [];

  List<SyncLog> get history => List.unmodifiable(_localHistory);

  Future<SyncLog> sincronizarUsuarios() async {
    // 1. Log de inicio
    await _auditService.logEvent(
      action: 'SYNC_START',
      module: 'SYNC',
      details: 'Iniciando sincronización con DB Institucional',
    );

    try {
      // Llamada real al endpoint de sincronización
      final response = await _apiService.post('/usuarios/sincronizar');
      
      // Parsear la respuesta del backend
      final log = SyncLog.fromJson(response.data);

      _localHistory.insert(0, log);

      await _auditService.logEvent(
        action: 'SYNC_SUCCESS',
        module: 'SYNC',
        details: 'Procesados: ${log.usuariosProcesados}, Actualizados: ${log.usuariosActualizados}',
      );

      return log;

    } catch (e) {
      final errorLog = SyncLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fecha: DateTime.now(),
        estado: SyncStatus.fallido,
        usuariosProcesados: 0,
        usuariosActualizados: 0,
        errores: 1,
        mensaje: 'Error de conexión con servicio LDAP/DB Institucional: $e',
      );
      
      _localHistory.insert(0, errorLog);

      await _auditService.logEvent(
        action: 'SYNC_ERROR',
        module: 'SYNC',
        details: 'Error: $e',
      );
      
      rethrow;
    }
  }
}
