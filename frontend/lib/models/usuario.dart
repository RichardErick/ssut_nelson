class Usuario {
  final int id;
  final String nombreUsuario;
  final String nombreCompleto;
  final String email;
  final String rol;
  final int? areaId;
  final String? areaNombre;
  final bool activo;
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
    this.ultimoAcceso,
    required this.intentosFallidos,
    this.bloqueadoHasta,
    required this.fechaRegistro,
    required this.fechaActualizacion,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'],
      nombreUsuario: json['nombreUsuario'],
      nombreCompleto: json['nombreCompleto'],
      email: json['email'],
      rol: json['rol'] ?? 'Contador', // Rol por defecto
      areaId: json['areaId'],
      areaNombre: json['areaNombre'],
      activo: json['activo'] ?? true,
      ultimoAcceso:
          json['ultimoAcceso'] != null
              ? DateTime.parse(json['ultimoAcceso'])
              : null,
      intentosFallidos: json['intentosFallidos'] ?? 0,
      bloqueadoHasta:
          json['bloqueadoHasta'] != null
              ? DateTime.parse(json['bloqueadoHasta'])
              : null,
      fechaRegistro: DateTime.parse(json['fechaRegistro']),
      fechaActualizacion: DateTime.parse(json['fechaActualizacion']),
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
