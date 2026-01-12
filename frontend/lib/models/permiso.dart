class Permiso {
  final int id;
  final String codigo;
  final String nombre;
  final String? descripcion;
  final String modulo;
  final bool activo;

  Permiso({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.descripcion,
    required this.modulo,
    required this.activo,
  });

  factory Permiso.fromJson(Map<String, dynamic> json) {
    return Permiso(
      id: json['id'] as int,
      codigo: json['codigo'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      modulo: json['modulo'] as String,
      activo: json['activo'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigo': codigo,
      'nombre': nombre,
      'descripcion': descripcion,
      'modulo': modulo,
      'activo': activo,
    };
  }
}
