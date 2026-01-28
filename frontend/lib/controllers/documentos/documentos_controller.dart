import 'package:flutter/material.dart';
import '../../models/documento.dart';
import '../../models/carpeta.dart';
import '../../services/documento_service.dart';
import '../../services/carpeta_service.dart';
import '../../utils/error_helper.dart';

/// Controlador para la lista de documentos
/// Maneja toda la lógica de negocio y estado
class DocumentosController extends ChangeNotifier {
  final DocumentoService _documentoService;
  final CarpetaService _carpetaService;

  DocumentosController({
    required DocumentoService documentoService,
    required CarpetaService carpetaService,
  })  : _documentoService = documentoService,
        _carpetaService = carpetaService;

  // ========== ESTADO ==========
  List<Documento> _documentos = [];
  List<Documento> _documentosCarpeta = [];
  List<Carpeta> _carpetas = [];
  List<Carpeta> _subcarpetas = [];
  Carpeta? _carpetaSeleccionada;

  bool _estaCargando = true;
  bool _estaCargandoCarpetas = true;
  bool _estaCargandoDocumentosCarpeta = false;
  bool _estaCargandoSubcarpetas = false;

  bool _vistaGrid = true;
  String _consultaBusqueda = '';
  String _filtroSeleccionado = 'todos';

  // ========== GETTERS ==========
  List<Documento> get documentos => _documentos;
  List<Documento> get documentosCarpeta => _documentosCarpeta;
  List<Carpeta> get carpetas => _carpetas;
  List<Carpeta> get subcarpetas => _subcarpetas;
  Carpeta? get carpetaSeleccionada => _carpetaSeleccionada;

  bool get estaCargando => _estaCargando;
  bool get estaCargandoCarpetas => _estaCargandoCarpetas;
  bool get estaCargandoDocumentosCarpeta => _estaCargandoDocumentosCarpeta;
  bool get estaCargandoSubcarpetas => _estaCargandoSubcarpetas;

  bool get vistaGrid => _vistaGrid;
  String get consultaBusqueda => _consultaBusqueda;
  String get filtroSeleccionado => _filtroSeleccionado;

  List<Documento> get documentosFiltrados {
    var filtrados = _documentos;

    if (_consultaBusqueda.isNotEmpty) {
      filtrados = filtrados.where((doc) {
        final query = _consultaBusqueda.toLowerCase();
        return doc.codigo.toLowerCase().contains(query) ||
            doc.numeroCorrelativo.toLowerCase().contains(query) ||
            (doc.tipoDocumentoNombre ?? '').toLowerCase().contains(query) ||
            (doc.descripcion ?? '').toLowerCase().contains(query);
      }).toList();
    }

    if (_filtroSeleccionado != 'todos') {
      filtrados = filtrados
          .where((doc) => doc.estado.toLowerCase() == _filtroSeleccionado)
          .toList();
    }

    return filtrados;
  }

  // ========== MÉTODOS PÚBLICOS ==========

  /// Cargar todos los documentos
  Future<void> cargarDocumentos() async {
    _estaCargando = true;
    notifyListeners();

    try {
      final response = await _documentoService.getAll();
      _documentos = response.items;
    } catch (e) {
      throw Exception(ErrorHelper.getErrorMessage(e));
    } finally {
      _estaCargando = false;
      notifyListeners();
    }
  }

  /// Cargar carpetas
  Future<void> cargarCarpetas() async {
    _estaCargandoCarpetas = true;
    notifyListeners();

    try {
      final gestion = DateTime.now().year.toString();
      _carpetas = await _carpetaService.getAll(gestion: gestion);
    } catch (e) {
      throw Exception(ErrorHelper.getErrorMessage(e));
    } finally {
      _estaCargandoCarpetas = false;
      notifyListeners();
    }
  }

  /// Cargar documentos de una carpeta específica
  Future<void> cargarDocumentosCarpeta(int carpetaId) async {
    _estaCargandoDocumentosCarpeta = true;
    notifyListeners();

    try {
      final documentos = await _documentoService.buscar(
        BusquedaDocumentoDTO(
          carpetaId: carpetaId,
          page: 1,
          pageSize: 50,
          orderBy: 'fechaDocumento',
          orderDirection: 'DESC',
        ),
      );
      _documentosCarpeta = documentos.items;
    } catch (e) {
      throw Exception(ErrorHelper.getErrorMessage(e));
    } finally {
      _estaCargandoDocumentosCarpeta = false;
      notifyListeners();
    }
  }

  /// Cargar subcarpetas de una carpeta padre
  Future<void> cargarSubcarpetas(int padreId) async {
    _estaCargandoSubcarpetas = true;
    notifyListeners();

    try {
      final todasCarpetas = await _carpetaService.getAll(
        gestion: DateTime.now().year.toString(),
      );
      _subcarpetas =
          todasCarpetas.where((c) => c.carpetaPadreId == padreId).toList();
    } catch (e) {
      // No mostramos error bloqueante por subcarpetas
      _subcarpetas = [];
    } finally {
      _estaCargandoSubcarpetas = false;
      notifyListeners();
    }
  }

  /// Abrir una carpeta
  Future<void> abrirCarpeta(Carpeta carpeta) async {
    _carpetaSeleccionada = carpeta;
    _documentosCarpeta = [];
    _subcarpetas = [];
    notifyListeners();

    await Future.wait([
      cargarDocumentosCarpeta(carpeta.id),
      cargarSubcarpetas(carpeta.id),
    ]);
  }

  /// Cerrar carpeta actual
  void cerrarCarpeta() {
    _carpetaSeleccionada = null;
    _documentosCarpeta = [];
    _subcarpetas = [];
    notifyListeners();
  }

  /// Eliminar un documento
  Future<void> eliminarDocumento(Documento doc) async {
    await _documentoService.delete(doc.id);
    await cargarDocumentos();
    if (_carpetaSeleccionada != null) {
      await cargarDocumentosCarpeta(_carpetaSeleccionada!.id);
    }
  }

  /// Eliminar una carpeta (o subcarpeta)
  Future<void> eliminarCarpeta(Carpeta carpeta) async {
    await _carpetaService.delete(carpeta.id, hard: false);
    await cargarCarpetas();
    if (_carpetaSeleccionada != null &&
        _carpetaSeleccionada!.id == carpeta.id) {
      cerrarCarpeta();
    }
  }

  /// Cambiar vista (grid/lista)
  void cambiarVista(bool esGrid) {
    _vistaGrid = esGrid;
    notifyListeners();
  }

  /// Actualizar búsqueda
  void actualizarBusqueda(String query) {
    _consultaBusqueda = query;
    notifyListeners();
  }

  /// Cambiar filtro
  void cambiarFiltro(String filtro) {
    _filtroSeleccionado = filtro;
    notifyListeners();
  }

  /// Calcular rango de correlativos
  String calcularRangoCorrelativos(List<Documento> docs) {
    final nums = <int>[];
    for (final d in docs) {
      final n = int.tryParse(d.numeroCorrelativo);
      if (n != null) nums.add(n);
    }
    if (nums.isEmpty) return 'Sin correlativos';
    nums.sort();
    return 'Comprobantes ${nums.first} - ${nums.last}';
  }
}
