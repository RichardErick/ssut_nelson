class PalabraClave {
  final int id;
  final String palabra;
  final String? descripcion;
  final bool activo;
  final int numeroDocumentos;

  PalabraClave({
    required this.id,
    required this.palabra,
    this.descripcion,
    required this.activo,
    this.numeroDocumentos = 0,
  });

  factory PalabraClave.fromJson(Map<String, dynamic> json) {
    return PalabraClave(
      id: json['id'],
      palabra: json['palabra'],
      descripcion: json['descripcion'],
      activo: json['activo'],
      numeroDocumentos: json['numeroDocumentos'] ?? 0,
    );
  }
}

class CreatePalabraClaveDTO {
  final String palabra;
  final String? descripcion;

  CreatePalabraClaveDTO({
    required this.palabra,
    this.descripcion,
  });

  Map<String, dynamic> toJson() {
    return {
      'palabra': palabra,
      'descripcion': descripcion,
    };
  }
}
