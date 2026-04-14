import 'package:dio/dio.dart';
import 'api_service.dart';

class AuditService {
  final ApiService _apiService;

  AuditService(this._apiService);

  Future<void> logEvent({
    required String action,
    required String module,
    required String details,
    String? username,
  }) async {
    try {
      await _apiService.post('/auditoria', data: {
        'accion': action,
        'modulo': module,
        'detalles': details,
        'usuario': username ?? 'Anonimo',
        'fecha': DateTime.now().toIso8601String(),
        'ip': '0.0.0.0', // En una app web real se obtendría del request server-side
      });
      print('Auditoria registrada: $action en $module');
    } catch (e) {
      // Fallar silenciosamente para no interrumpir el flujo del usuario
      print('Error registrando auditoria: $e');
    }
  }
}
