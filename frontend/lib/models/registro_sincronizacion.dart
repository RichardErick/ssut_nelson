enum SyncStatus {
  exitoso,
  fallido,
  parcial,
  enProceso
}

class SyncLog {
  final String id;
  final DateTime fecha;
  final SyncStatus estado;
  final int usuariosProcesados;
  final int usuariosActualizados;
  final int errores;
  final String mensaje;

  SyncLog({
    required this.id,
    required this.fecha,
    required this.estado,
    required this.usuariosProcesados,
    required this.usuariosActualizados,
    required this.errores,
    required this.mensaje,
  });

  factory SyncLog.fromJson(Map<String, dynamic> json) {
    return SyncLog(
      id: json['id'],
      fecha: DateTime.parse(json['fecha']),
      estado: SyncStatus.values.firstWhere((e) => e.toString() == 'SyncStatus.${json['estado']}'),
      usuariosProcesados: json['usuariosProcesados'],
      usuariosActualizados: json['usuariosActualizados'],
      errores: json['errores'],
      mensaje: json['mensaje'],
    );
  }
}
