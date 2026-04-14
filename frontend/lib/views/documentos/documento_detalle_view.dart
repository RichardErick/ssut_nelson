import 'package:flutter/material.dart';
import '../../models/documento.dart';

/// Vista de detalle de documento (stub - pendiente implementación completa)
class DocumentoDetailView extends StatelessWidget {
  final Documento documento;

  const DocumentoDetailView({
    super.key,
    required this.documento,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Implementar vista de detalle usando DocumentoDetailController
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalle: ${documento.codigo}'),
      ),
      body: const Center(
        child: Text('Vista en construcción - Usar DocumentoDetailController'),
      ),
    );
  }
}
