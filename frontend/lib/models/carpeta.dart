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
  final int? numeroCarpeta;
  final String? codigoRomano;
  final int? rangoInicio;
  final int? rangoFin;
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
    this.numeroCarpeta,
    this.codigoRomano,
    this.rangoInicio,
    this.rangoFin,
    this.subcarpetas = const [],
  });

  factory Carpeta.fromJson(Map<String, dynamic> json) {
    final fechaCreacionRaw = json['fechaCreacion'];
    return Carpeta(
      id: json['id'],
      nombre: json['nombre'],
      codigo: json['codigo'],
      gestion: json['gestion']?.toString() ?? '',
      descripcion: json['descripcion'],
      carpetaPadreId: json['carpetaPadreId'],
      carpetaPadreNombre: json['carpetaPadreNombre'],
      activo: (json['activo'] ?? true) as bool,
      fechaCreacion: fechaCreacionRaw != null
          ? DateTime.parse(fechaCreacionRaw.toString())
          : DateTime.now(),
      usuarioCreacionNombre: json['usuarioCreacionNombre'],
      numeroSubcarpetas: json['numeroSubcarpetas'] ?? 0,
      numeroDocumentos: json['numeroDocumentos'] ?? 0,
      numeroCarpeta: json['numeroCarpeta'],
      codigoRomano: json['codigoRomano'],
      rangoInicio: json['rangoInicio'],
      rangoFin: json['rangoFin'],
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
