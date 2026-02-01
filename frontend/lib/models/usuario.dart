class Usuario {
  final int id;
  final String nombreUsuario;
  final String nombreCompleto;
  final String email;
  final String rol;
  final int? areaId;
  final String? areaNombre;
  final bool activo;
  /// True si un admin rechazó la solicitud de registro; no se muestra en pendientes.
  final bool solicitudRechazada;
  final DateTime? ultimoAcceso;
  final int intentosFallidos;
  final DateTime? bloqueadoHasta;
  final DateTime fechaRegistro;
  final DateTime fechaActualizacion;

  Usuario({
    required this.id,
    required this.nombreUsuario,
    required this.nombreCompleto,
    required this.email,
    required this.rol,
    this.areaId,
    this.areaNombre,
    required this.activo,
    this.solicitudRechazada = false,
    this.ultimoAcceso,
    required this.intentosFallidos,
    this.bloqueadoHasta,
    required this.fechaRegistro,
    required this.fechaActualizacion,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    dynamic v(String a, [String? b]) => json[a] ?? (b != null ? json[b] : null);
    String? s(String a, [String? b]) => v(a, b)?.toString();
    DateTime? parseDate(dynamic x) => x == null ? null : DateTime.tryParse(x.toString());
    final idRaw = v('id', 'Id');
    final id = idRaw is int ? idRaw : (int.tryParse(idRaw?.toString() ?? '') ?? 0);
    final fechaReg = parseDate(v('fechaRegistro', 'FechaRegistro'));
    final fechaAct = parseDate(v('fechaActualizacion', 'FechaActualizacion'));
    return Usuario(
      id: id,
      nombreUsuario: s('nombreUsuario', 'NombreUsuario') ?? '',
      nombreCompleto: s('nombreCompleto', 'NombreCompleto') ?? '',
      email: s('email', 'Email') ?? '',
      rol: s('rol', 'Rol') ?? 'Contador',
      areaId: v('areaId', 'AreaId') is int ? v('areaId', 'AreaId') as int? : int.tryParse(s('areaId', 'AreaId') ?? ''),
      areaNombre: s('areaNombre', 'AreaNombre'),
      activo: v('activo', 'Activo') == true,
      solicitudRechazada: v('solicitudRechazada', 'SolicitudRechazada') == true,
      ultimoAcceso: parseDate(v('ultimoAcceso', 'UltimoAcceso')),
      intentosFallidos: (v('intentosFallidos', 'IntentosFallidos') is int) ? v('intentosFallidos', 'IntentosFallidos') as int : (int.tryParse(s('intentosFallidos', 'IntentosFallidos') ?? '0') ?? 0),
      bloqueadoHasta: parseDate(v('bloqueadoHasta', 'BloqueadoHasta')),
      fechaRegistro: fechaReg ?? DateTime.now(),
      fechaActualizacion: fechaAct ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombreUsuario': nombreUsuario,
      'nombreCompleto': nombreCompleto,
      'email': email,
      'rol': rol,
      'areaId': areaId,
      'activo': activo,
    };
  }
}

class CreateUsuarioDTO {
  final String nombreUsuario;
  final String nombreCompleto;
  final String email;
  final String password;
  final String rol;
  final int? areaId;
  final bool activo;

  CreateUsuarioDTO({
    required this.nombreUsuario,
    required this.nombreCompleto,
    required this.email,
    required this.password,
    this.rol = 'Contador', // Rol por defecto
    this.areaId,
    this.activo = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'nombreUsuario': nombreUsuario,
      'nombreCompleto': nombreCompleto,
      'email': email,
      'password': password,
      'rol': rol,
      'areaId': areaId,
      'activo': activo,
    };
  }
}

class UpdateUsuarioDTO {
  final String? nombreCompleto;
  final String? email;
  final String? password;
  final String? rol;
  final int? areaId;
  final bool? activo;

  UpdateUsuarioDTO({
    this.nombreCompleto,
    this.email,
    this.password,
    this.rol,
    this.areaId,
    this.activo,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (nombreCompleto != null) map['nombreCompleto'] = nombreCompleto;
    if (email != null) map['email'] = email;
    if (password != null) map['password'] = password;
    if (rol != null) map['rol'] = rol;
    if (areaId != null) map['areaId'] = areaId;
    if (activo != null) map['activo'] = activo;
    return map;
  }
}
