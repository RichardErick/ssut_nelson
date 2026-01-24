class Carpeta {
  final int id;
  final String nombre;
  final String? codigo;
  final String gestion;
  final String? descripcion;
  final int? carpetaPadreId;
  final String? carpetaPadreNombre;
  final bool activo;
  final DateTime fechaCreacion;
  final String? usuarioCreacionNombre;
  final int numeroSubcarpetas;
  final int numeroDocumentos;
  final List<Carpeta> subcarpetas;

  Carpeta({
    required this.id,
    required this.nombre,
    this.codigo,
    required this.gestion,
    this.descripcion,
    this.carpetaPadreId,
    this.carpetaPadreNombre,
    required this.activo,
    required this.fechaCreacion,
    this.usuarioCreacionNombre,
    this.numeroSubcarpetas = 0,
    this.numeroDocumentos = 0,
    this.subcarpetas = const [],
  });

  factory Carpeta.fromJson(Map<String, dynamic> json) {
    return Carpeta(
      id: json['id'],
      nombre: json['nombre'],
      codigo: json['codigo'],
      gestion: json['gestion'],
      descripcion: json['descripcion'],
      carpetaPadreId: json['carpetaPadreId'],
      carpetaPadreNombre: json['carpetaPadreNombre'],
      activo: json['activo'],
      fechaCreacion: DateTime.parse(json['fechaCreacion']),
      usuarioCreacionNombre: json['usuarioCreacionNombre'],
      numeroSubcarpetas: json['numeroSubcarpetas'] ?? 0,
      numeroDocumentos: json['numeroDocumentos'] ?? 0,
      subcarpetas: json['subcarpetas'] != null
          ? (json['subcarpetas'] as List)
              .map((e) => Carpeta.fromJson(e))
              .toList()
          : [],
    );
  }
}

class CreateCarpetaDTO {
  final String nombre;
  final String? codigo;
  final String gestion;
  final String? descripcion;
  final int? carpetaPadreId;

  CreateCarpetaDTO({
    required this.nombre,
    this.codigo,
    required this.gestion,
    this.descripcion,
    this.carpetaPadreId,
  });

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'codigo': codigo,
      'gestion': gestion,
      'descripcion': descripcion,
      'carpetaPadreId': carpetaPadreId,
    };
  }
}

class UpdateCarpetaDTO {
  final String? nombre;
  final String? codigo;
  final String? descripcion;
  final bool? activo;

  UpdateCarpetaDTO({
    this.nombre,
    this.codigo,
    this.descripcion,
    this.activo,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (nombre != null) data['nombre'] = nombre;
    if (codigo != null) data['codigo'] = codigo;
    if (descripcion != null) data['descripcion'] = descripcion;
    if (activo != null) data['activo'] = activo;
    return data;
  }
}
