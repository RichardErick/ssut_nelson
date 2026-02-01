class Documento {
  final int id;
  final String idDocumento;
  final String codigo;
  final String numeroCorrelativo;
  final int tipoDocumentoId;
  final String? tipoDocumentoNombre;
  final String? tipoDocumentoCodigo;
  final int areaOrigenId;
  final String? areaOrigenNombre;
  final String? areaOrigenCodigo;
  final String gestion;
  final DateTime fechaDocumento;
  final String? descripcion;
  final int? responsableId;
  final String? responsableNombre;
  final String? codigoQR;
  final String? urlQR;
  final String? ubicacionFisica;
  final String estado;
  final bool activo;
  final int nivelConfidencialidad;
  final DateTime fechaRegistro;
  final DateTime fechaActualizacion;
  final int? carpetaId;
  final String? carpetaNombre;
  final String? carpetaPadreNombre;
  final List<String> palabrasClave;

  Documento({
    required this.id,
    this.idDocumento = '',
    required this.codigo,
    required this.numeroCorrelativo,
    required this.tipoDocumentoId,
    this.tipoDocumentoNombre,
    this.tipoDocumentoCodigo,
    required this.areaOrigenId,
    this.areaOrigenNombre,
    this.areaOrigenCodigo,
    required this.gestion,
    required this.fechaDocumento,
    this.descripcion,
    this.responsableId,
    this.responsableNombre,
    this.codigoQR,
    this.urlQR,
    this.ubicacionFisica,
    required this.estado,
    this.activo = true,
    this.nivelConfidencialidad = 1,
    required this.fechaRegistro,
    required this.fechaActualizacion,
    this.carpetaId,
    this.carpetaNombre,
    this.carpetaPadreNombre,
    this.palabrasClave = const [],
  });

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  factory Documento.fromJson(Map<String, dynamic> json) {
    final v = (String key, [String? key2]) => json[key] ?? (key2 != null ? json[key2] : null);
    return Documento(
      id: json['id'],
      idDocumento: json['idDocumento'] ?? json['IdDocumento'] ?? '',
      codigo: json['codigo'] ?? json['Codigo'] ?? '',
      numeroCorrelativo: json['numeroCorrelativo'] ?? json['NumeroCorrelativo'] ?? '',
      tipoDocumentoId: json['tipoDocumentoId'] ?? json['TipoDocumentoId'],
      tipoDocumentoNombre: json['tipoDocumentoNombre'] ?? json['TipoDocumentoNombre'],
      tipoDocumentoCodigo: json['tipoDocumentoCodigo'] ?? json['TipoDocumentoCodigo'],
      areaOrigenId: json['areaOrigenId'] ?? json['AreaOrigenId'],
      areaOrigenNombre: json['areaOrigenNombre'] ?? json['AreaOrigenNombre'],
      areaOrigenCodigo: json['areaOrigenCodigo'] ?? json['AreaOrigenCodigo'],
      gestion: json['gestion'] ?? json['Gestion'] ?? '',
      fechaDocumento: DateTime.tryParse((json['fechaDocumento'] ?? json['FechaDocumento'] ?? '').toString()) ?? DateTime.now(),
      descripcion: json['descripcion'] ?? json['Descripcion'],
      responsableId: _parseInt(v('responsableId', 'ResponsableId')),
      responsableNombre: json['responsableNombre']?.toString() ?? json['ResponsableNombre']?.toString(),
      codigoQR: json['codigoQR'],
      urlQR: json['urlQR'],
      ubicacionFisica: json['ubicacionFisica'],
      estado: json['estado'] ?? 'Activo',
      activo: json['activo'] ?? true,
      nivelConfidencialidad: json['nivelConfidencialidad'] ?? 1,
      fechaRegistro: DateTime.parse(json['fechaRegistro']),
      fechaActualizacion: json['fechaActualizacion'] != null 
          ? DateTime.parse(json['fechaActualizacion']) 
          : DateTime.parse(json['fechaRegistro']),
      carpetaId: _parseInt(v('carpetaId', 'CarpetaId')),
      carpetaNombre: json['carpetaNombre']?.toString() ?? json['CarpetaNombre']?.toString(),
      carpetaPadreNombre: json['carpetaPadreNombre'],
      palabrasClave: json['palabrasClave'] != null 
          ? List<String>.from(json['palabrasClave']) 
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idDocumento': idDocumento,
      'codigo': codigo,
      'numeroCorrelativo': numeroCorrelativo,
      'tipoDocumentoId': tipoDocumentoId,
      'areaOrigenId': areaOrigenId,
      'gestion': gestion,
      'fechaDocumento': fechaDocumento.toIso8601String(),
      'descripcion': descripcion,
      'responsableId': responsableId,
      'ubicacionFisica': ubicacionFisica,
      'estado': estado,
      'activo': activo,
      'nivelConfidencialidad': nivelConfidencialidad,
      'carpetaId': carpetaId,
    };
  }
}

class CreateDocumentoDTO {
  final String numeroCorrelativo;
  final int tipoDocumentoId;
  final int areaOrigenId;
  final String gestion;
  final DateTime fechaDocumento;
  final String? descripcion;
  final int? responsableId;
  final String? ubicacionFisica;
  final int? carpetaId;
  final List<int>? palabrasClaveIds;
  final int nivelConfidencialidad;

  CreateDocumentoDTO({
    required this.numeroCorrelativo,
    required this.tipoDocumentoId,
    required this.areaOrigenId,
    required this.gestion,
    required this.fechaDocumento,
    this.descripcion,
    this.responsableId,
    this.ubicacionFisica,
    this.carpetaId,
    this.palabrasClaveIds,
    this.nivelConfidencialidad = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'numeroCorrelativo': numeroCorrelativo,
      'tipoDocumentoId': tipoDocumentoId,
      'areaOrigenId': areaOrigenId,
      'gestion': gestion,
      'fechaDocumento': fechaDocumento.toIso8601String(),
      'descripcion': descripcion,
      'responsableId': responsableId,
      'ubicacionFisica': ubicacionFisica,
      'carpetaId': carpetaId,
      'palabrasClaveIds': palabrasClaveIds,
      'nivelConfidencialidad': nivelConfidencialidad,
    };
  }
}

class UpdateDocumentoDTO {
  final String? numeroCorrelativo;
  final int? tipoDocumentoId;
  final int? areaOrigenId;
  final String? gestion;
  final DateTime? fechaDocumento;
  final String? descripcion;
  final int? responsableId;
  final String? ubicacionFisica;
  final int? carpetaId;
  final List<int>? palabrasClaveIds;
  final String? estado;
  final int? nivelConfidencialidad;

  UpdateDocumentoDTO({
    this.numeroCorrelativo,
    this.tipoDocumentoId,
    this.areaOrigenId,
    this.gestion,
    this.fechaDocumento,
    this.descripcion,
    this.responsableId,
    this.ubicacionFisica,
    this.carpetaId,
    this.palabrasClaveIds,
    this.estado,
    this.nivelConfidencialidad,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (numeroCorrelativo != null) data['numeroCorrelativo'] = numeroCorrelativo;
    if (tipoDocumentoId != null) data['tipoDocumentoId'] = tipoDocumentoId;
    if (areaOrigenId != null) data['areaOrigenId'] = areaOrigenId;
    if (gestion != null) data['gestion'] = gestion;
    if (fechaDocumento != null) data['fechaDocumento'] = fechaDocumento!.toIso8601String();
    if (descripcion != null) data['descripcion'] = descripcion;
    if (responsableId != null) data['responsableId'] = responsableId;
    if (ubicacionFisica != null) data['ubicacionFisica'] = ubicacionFisica;
    if (carpetaId != null) data['carpetaId'] = carpetaId;
    if (palabrasClaveIds != null) data['palabrasClaveIds'] = palabrasClaveIds;
    if (estado != null) data['estado'] = estado;
    if (nivelConfidencialidad != null) data['nivelConfidencialidad'] = nivelConfidencialidad;
    return data;
  }
}

class BusquedaDocumentoDTO {
  final String? codigo;
  final String? numeroCorrelativo;
  final int? tipoDocumentoId;
  final int? areaOrigenId;
  final String? gestion;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final String? estado;
  final String? codigoQR;
  final int? responsableId;
  final List<String>? palabrasClave;
  final int? carpetaId;
  final String? textoBusqueda;
  final bool incluirInactivos;
  final int page;
  final int pageSize;
  final String? orderBy;
  final String? orderDirection;

  BusquedaDocumentoDTO({
    this.codigo,
    this.numeroCorrelativo,
    this.tipoDocumentoId,
    this.areaOrigenId,
    this.gestion,
    this.fechaDesde,
    this.fechaHasta,
    this.estado,
    this.codigoQR,
    this.responsableId,
    this.palabrasClave,
    this.carpetaId,
    this.textoBusqueda,
    this.incluirInactivos = false,
    this.page = 1,
    this.pageSize = 20,
    this.orderBy,
    this.orderDirection,
  });

  Map<String, dynamic> toJson() {
    return {
      'codigo': codigo,
      'numeroCorrelativo': numeroCorrelativo,
      'tipoDocumentoId': tipoDocumentoId,
      'areaOrigenId': areaOrigenId,
      'gestion': gestion,
      'fechaDesde': fechaDesde?.toIso8601String(),
      'fechaHasta': fechaHasta?.toIso8601String(),
      'estado': estado,
      'codigoQR': codigoQR,
      'responsableId': responsableId,
      'palabrasClave': palabrasClave,
      'carpetaId': carpetaId,
      'textoBusqueda': textoBusqueda,
      'incluirInactivos': incluirInactivos,
      'page': page,
      'pageSize': pageSize,
      'orderBy': orderBy,
      'orderDirection': orderDirection,
    };
  }
}

class PaginatedResponse<T> {
  final List<T> items;
  final int totalItems;
  final int page;
  final int pageSize;
  final int totalPages;

  PaginatedResponse({
    required this.items,
    required this.totalItems,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PaginatedResponse.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJson) {
    return PaginatedResponse<T>(
      items: (json['items'] as List).map((e) => fromJson(e)).toList(),
      totalItems: json['totalItems'],
      page: json['page'],
      pageSize: json['pageSize'],
      totalPages: json['totalPages'],
    );
  }
}
