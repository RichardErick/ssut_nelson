import 'package:provider/provider.dart';

import '../main.dart';
import '../models/documento.dart';
import 'api_service.dart';

class DocumentoService {
  Future<PaginatedResponse<Documento>> getAll({
    bool incluirInactivos = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final apiService = Provider.of<ApiService>(
        navigatorKey.currentContext!,
        listen: false,
      );
      final response = await apiService.get(
        '/documentos', 
        queryParameters: {
          'incluirInactivos': incluirInactivos,
          'page': page,
          'pageSize': pageSize,
        }
      );
      return PaginatedResponse.fromJson(response.data, Documento.fromJson);
    } catch (e) {
      print('API Error: $e. Returning mock data.');
      return PaginatedResponse(
        items: _getMockDocumentos(),
        totalItems: 4,
        page: 1,
        pageSize: 20,
        totalPages: 1
      );
    }
  }

  List<Documento> _getMockDocumentos() {
    return [
      Documento(
        id: 1,
        idDocumento: 'INF-CONT-2024-001',
        codigo: 'INF-2024-001',
        numeroCorrelativo: '001',
        tipoDocumentoId: 1,
        tipoDocumentoNombre: 'Informe',
        areaOrigenId: 1,
        areaOrigenNombre: 'Contabilidad',
        gestion: '2024',
        fechaDocumento: DateTime.now().subtract(const Duration(days: 2)),
        descripcion: 'Informe de gestión financiera Q1',
        estado: 'activo',
        fechaRegistro: DateTime.now().subtract(const Duration(days: 2)),
        fechaActualizacion: DateTime.now(),
        responsableNombre: 'Juan Perez',
        carpetaNombre: 'Informes 2024',
      ),
      Documento(
        id: 2,
        idDocumento: 'MEM-RH-2024-045',
        codigo: 'MEM-2024-045',
        numeroCorrelativo: '045',
        tipoDocumentoId: 2,
        tipoDocumentoNombre: 'Memorandum',
        areaOrigenId: 2,
        areaOrigenNombre: 'Recursos Humanos',
        gestion: '2024',
        fechaDocumento: DateTime.now().subtract(const Duration(days: 5)),
        descripcion: 'Asignación de nuevo personal',
        estado: 'archivado',
        fechaRegistro: DateTime.now().subtract(const Duration(days: 5)),
        fechaActualizacion: DateTime.now(),
        responsableNombre: 'Maria Diaz',
      ),
      Documento(
        id: 3,
        idDocumento: 'FAC-VEN-2024-789',
        codigo: 'FAC-2024-789',
        numeroCorrelativo: '789',
        tipoDocumentoId: 3,
        tipoDocumentoNombre: 'Factura',
        areaOrigenId: 3,
        areaOrigenNombre: 'Ventas',
        gestion: '2024',
        fechaDocumento: DateTime.now().subtract(const Duration(days: 1)),
        descripcion: 'Factura de servicios cloud',
        estado: 'prestado',
        fechaRegistro: DateTime.now().subtract(const Duration(days: 1)),
        fechaActualizacion: DateTime.now(),
        responsableNombre: 'Carlos Ruiz',
      ),
       Documento(
        id: 4,
        idDocumento: 'CON-LEG-2024-102',
        codigo: 'CON-2024-102',
        numeroCorrelativo: '102',
        tipoDocumentoId: 4,
        tipoDocumentoNombre: 'Contrato',
        areaOrigenId: 4,
        areaOrigenNombre: 'Legal',
        gestion: '2024',
        fechaDocumento: DateTime.now().subtract(const Duration(days: 10)),
        descripcion: 'Contrato de servicios de mantenimiento',
        estado: 'activo',
        fechaRegistro: DateTime.now().subtract(const Duration(days: 10)),
        fechaActualizacion: DateTime.now(),
        responsableNombre: 'Ana Lopez',
      ),
    ];
  }

  Future<Documento?> getById(int id) async {
    final apiService = Provider.of<ApiService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    final response = await apiService.get('/documentos/$id');
    return Documento.fromJson(response.data);
  }
  
  Future<Documento?> getByIdDocumento(String idDocumento) async {
    final apiService = Provider.of<ApiService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    final response = await apiService.get('/documentos/ficha/$idDocumento');
    return Documento.fromJson(response.data);
  }

  Future<PaginatedResponse<Documento>> buscar(BusquedaDocumentoDTO busqueda) async {
    final apiService = Provider.of<ApiService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    final response = await apiService.post(
      '/documentos/buscar',
      data: busqueda.toJson(),
    );
    return PaginatedResponse.fromJson(response.data, Documento.fromJson);
  }

  Future<Documento> create(CreateDocumentoDTO dto) async {
    final apiService = Provider.of<ApiService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    final response = await apiService.post('/documentos', data: dto.toJson());
    return Documento.fromJson(response.data);
  }

  Future<Documento> update(int id, UpdateDocumentoDTO dto) async {
    final apiService = Provider.of<ApiService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    final response = await apiService.put('/documentos/$id', data: dto.toJson());
    // El backend devuelve solo confirmación parcial, mejor hacer getById o asumir éxito
    return await getById(id) as Documento; 
  }

  Future<void> delete(int id, {bool hard = false}) async {
    final apiService = Provider.of<ApiService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    await apiService.delete('/documentos/$id?hard=$hard');
  }
  
  Future<Map<String, dynamic>> generarQR(int id) async {
    final apiService = Provider.of<ApiService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    final response = await apiService.post('/documentos/$id/qr');
    return response.data;
  }
  
  Future<void> moverLote(List<int> documentoIds, int carpetaDestinoId, {String? observaciones}) async {
    final apiService = Provider.of<ApiService>(
      navigatorKey.currentContext!,
      listen: false,
    );
    await apiService.post('/documentos/mover-lote', data: {
      'documentoIds': documentoIds,
      'carpetaDestinoId': carpetaDestinoId,
      'observaciones': observaciones
    });
  }
}
