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

  static int _intFromJson(Map<String, dynamic> json, String key, [String? keyPascal]) {
    final v = json[key] ?? (keyPascal != null ? json[keyPascal] : null);
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory Carpeta.fromJson(Map<String, dynamic> json) {
    final fechaCreacionRaw = json['fechaCreacion'] ?? json['FechaCreacion'];
    return Carpeta(
      id: json['id'] ?? json['Id'],
      nombre: json['nombre']?.toString() ?? json['Nombre']?.toString() ?? '',
      codigo: json['codigo']?.toString() ?? json['Codigo']?.toString(),
      gestion: json['gestion']?.toString() ?? json['Gestion']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? json['Descripcion']?.toString(),
      carpetaPadreId: json['carpetaPadreId'] ?? json['CarpetaPadreId'],
      carpetaPadreNombre: json['carpetaPadreNombre']?.toString() ?? json['CarpetaPadreNombre']?.toString(),
      activo: (json['activo'] ?? json['Activo'] ?? true) as bool,
      fechaCreacion: fechaCreacionRaw != null
          ? DateTime.tryParse(fechaCreacionRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
      usuarioCreacionNombre: json['usuarioCreacionNombre']?.toString() ?? json['UsuarioCreacionNombre']?.toString(),
      numeroSubcarpetas: _intFromJson(json, 'numeroSubcarpetas', 'NumeroSubcarpetas'),
      numeroDocumentos: _intFromJson(json, 'numeroDocumentos', 'NumeroDocumentos'),
      numeroCarpeta: json['numeroCarpeta'] ?? json['NumeroCarpeta'],
      codigoRomano: json['codigoRomano']?.toString() ?? json['CodigoRomano']?.toString(),
      rangoInicio: json['rangoInicio'] ?? json['RangoInicio'],
      rangoFin: json['rangoFin'] ?? json['RangoFin'],
      subcarpetas: json['subcarpetas'] != null || json['Subcarpetas'] != null
          ? ((json['subcarpetas'] ?? json['Subcarpetas']) as List)
              .map((e) => Carpeta.fromJson(e as Map<String, dynamic>))
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
  final int? rangoInicio;
  final int? rangoFin;

  CreateCarpetaDTO({
    required this.nombre,
    this.codigo,
    required this.gestion,
    this.descripcion,
    this.carpetaPadreId,
    this.rangoInicio,
    this.rangoFin,
  });

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'codigo': codigo,
      'gestion': gestion,
      'descripcion': descripcion,
      'carpetaPadreId': carpetaPadreId,
      'rangoInicio': rangoInicio,
      'rangoFin': rangoFin,
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
