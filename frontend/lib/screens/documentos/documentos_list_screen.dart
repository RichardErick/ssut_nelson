import 'package:flutter/material.dart';
import 'package:frontend/providers/data_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/carpeta.dart';
import '../../models/documento.dart';
import '../../models/usuario.dart';
import '../../providers/auth_provider.dart';
import '../../services/carpeta_service.dart';
import '../../services/documento_service.dart';
import '../../services/usuario_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helper.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_shimmer.dart';
import 'documento_detail_screen.dart';
import 'documento_form_screen.dart';
import 'subcarpeta_form_screen.dart';

class DocumentosListScreen extends StatefulWidget {
  final int? initialCarpetaId;
  const DocumentosListScreen({super.key, this.initialCarpetaId});

  @override
  State<DocumentosListScreen> createState() => DocumentosListScreenState();
}

class DocumentosListScreenState extends State<DocumentosListScreen>
    with AutomaticKeepAliveClientMixin {
  Carpeta? get carpetaSeleccionada => _carpetaSeleccionada;

  List<Documento> _documentos = [];
  List<Documento> _documentosCarpeta = [];
  List<Carpeta> _carpetas = [];
  bool _estaCargando = true;
  bool _estaCargandoCarpetas = true;
  bool _estaCargandoDocumentosCarpeta = false;
  List<Carpeta> _subcarpetas = [];
  Carpeta? _carpetaSeleccionada;
  bool _estaCargandoSubcarpetas = false;
  bool _vistaGrid = true;
  String _consultaBusqueda = '';
  String _filtroSeleccionado = 'todos';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Búsqueda avanzada: número comprobante, fecha, responsable, código QR (vista documentos)
  String _numeroComprobanteFilter = '';
  DateTime? _fechaDesdeFilter;
  DateTime? _fechaHastaFilter;
  int? _responsableIdFilter;
  String _codigoQrFilter = '';
  final TextEditingController _codigoQrFilterController =
      TextEditingController();
  final TextEditingController _numeroComprobanteFilterController =
      TextEditingController();

  /// Filtro por gestión en la vista Carpetas (solo aplica cuando _carpetaSeleccionada == null).
  String? _gestionFilterCarpetas;
  static const List<String> _gestionesCarpetas = ['2024', '2025', '2026'];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.initialCarpetaId != null) {
      // Si venimos con un ID, cargamos directamente esa carpeta y sus cosas
      _cargarCarpetaInicial(widget.initialCarpetaId!);
    } else {
      // Cargar todas las carpetas al iniciar (sin filtro por año) para que no aparezca vacío
      _cargarCarpetas(todasLasGestiones: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) cargarDocumentos();
      });
    }
    _searchController.addListener(_alCambiarBusqueda);
  }

  Future<void> _cargarCarpetaInicial(int id) async {
    setState(() {
      _estaCargando = true;
      _estaCargandoCarpetas = true;
    });

    try {
      final service = Provider.of<CarpetaService>(context, listen: false);
      final carpeta = await service.getById(id);

      if (mounted) {
        // Set state directly
        _carpetaSeleccionada = carpeta;
        _estaCargandoCarpetas = false;
        // Cargar todas las carpetas para el panel lateral
        await _cargarCarpetas(todasLasGestiones: true);
        if (!mounted) return;
        // Load content
        await _abrirCarpeta(carpeta);
      }
    } catch (e) {
      print('Error cargando carpeta inicial $id: $e');
      if (mounted)
        _mostrarSnackBarError('No se pudo cargar la carpeta solicitada');
    } finally {
      if (mounted) {
        setState(() {
          _estaCargando = false;
          _estaCargandoCarpetas = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _codigoQrFilterController.dispose();
    _numeroComprobanteFilterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _alCambiarBusqueda() {
    setState(() {
      _consultaBusqueda = _searchController.text;
    });
  }

  Future<void> cargarDocumentos() async {
    setState(() => _estaCargando = true);
    try {
      final service = Provider.of<DocumentoService>(context, listen: false);
      final documentos = await service.getAll();
      setState(() {
        _documentos = documentos.items;
        _estaCargando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _estaCargando = false);
        _mostrarSnackBarError(ErrorHelper.getErrorMessage(e));
      }
    }
  }

  /// [todasLasGestiones] true = cargar todas (sin filtro año), para que al crear una carpeta el panel se actualice.
  Future<void> _cargarCarpetas({bool todasLasGestiones = false}) async {
    setState(() => _estaCargandoCarpetas = true);
    try {
      final carpetaService = Provider.of<CarpetaService>(
        context,
        listen: false,
      );
      final todasLasCarpetas = await carpetaService.getAll(
        gestion: todasLasGestiones ? null : DateTime.now().year.toString(),
      );
      if (!mounted) return;
      setState(() {
        _carpetas =
            todasLasCarpetas.where((c) => c.carpetaPadreId == null).toList();
        _estaCargandoCarpetas = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _estaCargandoCarpetas = false);
        _mostrarSnackBarError(ErrorHelper.getErrorMessage(e));
      }
    }
  }

  Future<void> _cargarDocumentosCarpeta(int carpetaId) async {
    setState(() => _estaCargandoDocumentosCarpeta = true);
    try {
      final service = Provider.of<DocumentoService>(context, listen: false);
      final n = _numeroComprobanteFilter.trim();
      final dto = BusquedaDocumentoDTO(
        carpetaId: carpetaId,
        numeroCorrelativo: n.isEmpty ? null : n,
        fechaDesde: _fechaDesdeFilter,
        fechaHasta: _fechaHastaFilter,
        responsableId: _responsableIdFilter,
        codigoQR: _codigoQrFilter.trim().isEmpty ? null : _codigoQrFilter.trim(),
        page: 1,
        pageSize: 100,
        orderBy: 'fechaDocumento',
        orderDirection: 'DESC',
      );
      final documentos = await service.buscar(dto);
      if (mounted) {
        setState(() {
          _documentosCarpeta = documentos.items;
          _estaCargandoDocumentosCarpeta = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _estaCargandoDocumentosCarpeta = false);
        _mostrarSnackBarError(ErrorHelper.getErrorMessage(e));
      }
    }
  }

  Future<void> _cargarSubcarpetas(int padreId) async {
    setState(() => _estaCargandoSubcarpetas = true);
    try {
      final service = Provider.of<CarpetaService>(context, listen: false);
      final subcarpetas = await service.getAll();
      // Filtrar manualmente si el backend no soporta filtro por padreId en getAll
      // Asumimos que getAll trae todo o filtramos en memoria por ahora
      if (mounted) {
        setState(() {
          _subcarpetas =
              subcarpetas.where((c) => c.carpetaPadreId == padreId).toList();
          _estaCargandoSubcarpetas = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _estaCargandoSubcarpetas = false);
        // No mostramos error bloqeante por subcarpetas
      }
    }
  }

  Future<void> _navegarACarpetaPadre(int carpetaPadreId) async {
    print('DEBUG: Navegando a carpeta padre con ID: $carpetaPadreId');

    try {
      final carpetaService = Provider.of<CarpetaService>(
        context,
        listen: false,
      );
      final carpetaPadre = await carpetaService.getById(carpetaPadreId);

      print('DEBUG: Carpeta padre encontrada: "${carpetaPadre.nombre}"');
      await _abrirCarpeta(carpetaPadre);
    } catch (e) {
      print('DEBUG: Error navegando a carpeta padre: $e');
      // Si hay error, ir a vista principal
      setState(() {
        _carpetaSeleccionada = null;
      });
    }
  }

  Future<void> _abrirCarpeta(Carpeta carpeta) async {
    print(
      'DEBUG: Abriendo carpeta "${carpeta.nombre}" (ID: ${carpeta.id}, PadreID: ${carpeta.carpetaPadreId})',
    );

    setState(() {
      _carpetaSeleccionada = carpeta;
      _documentosCarpeta = [];
      _subcarpetas = [];
    });

    final esCarpeta = carpeta.carpetaPadreId == null;
    // SSUT: solo carpeta principal; al abrir una carpeta se muestran sus documentos (no subcarpetas).
    if (esCarpeta) {
      await _cargarDocumentosCarpeta(carpeta.id);
    } else {
      await Future.wait([
        _cargarDocumentosCarpeta(carpeta.id),
        _cargarSubcarpetas(carpeta.id),
      ]);
    }

    if (mounted) {
      setState(() {});
    }
  }

  /// Carpetas filtradas: solo carpetas principales (sin subcarpetas en la UI por indicación SSUT).
  List<Carpeta> get _carpetasFiltradas {
    var list = _carpetas.where((c) => c.carpetaPadreId == null).toList();
    if (_gestionFilterCarpetas != null && _gestionFilterCarpetas!.isNotEmpty) {
      list = list.where((c) => c.gestion == _gestionFilterCarpetas).toList();
    }
    if (_consultaBusqueda.trim().isEmpty) return list;
    final query = _consultaBusqueda.toLowerCase().trim();
    return list.where((c) {
      return (c.nombre.toLowerCase().contains(query)) ||
          (c.codigo?.toLowerCase().contains(query) ?? false) ||
          (c.gestion.toLowerCase().contains(query));
    }).toList();
  }

  /// Documentos de la carpeta actual. Filtros avanzados (número comprobante, fecha, responsable, QR) se aplican en el API; aquí solo búsqueda por texto y estado.
  List<Documento> get _documentosCarpetaFiltrados {
    var filtrados = _documentosCarpeta;
    if (_consultaBusqueda.trim().isNotEmpty) {
      final query = _consultaBusqueda.toLowerCase().trim();
      filtrados =
          filtrados.where((doc) {
            return doc.codigo.toLowerCase().contains(query) ||
                doc.numeroCorrelativo.toLowerCase().contains(query) ||
                (doc.tipoDocumentoNombre ?? '').toLowerCase().contains(query) ||
                (doc.descripcion ?? '').toLowerCase().contains(query);
          }).toList();
    }
    if (_filtroSeleccionado != 'todos') {
      filtrados =
          filtrados
              .where((doc) => doc.estado.toLowerCase() == _filtroSeleccionado)
              .toList();
    }
    return filtrados;
  }

  List<Documento> get _documentosFiltrados {
    var filtrados = _documentos;

    if (_consultaBusqueda.trim().isNotEmpty) {
      final query = _consultaBusqueda.toLowerCase().trim();
      filtrados =
          filtrados.where((doc) {
            return doc.codigo.toLowerCase().contains(query) ||
                doc.numeroCorrelativo.toLowerCase().contains(query) ||
                (doc.tipoDocumentoNombre ?? '').toLowerCase().contains(query) ||
                (doc.descripcion ?? '').toLowerCase().contains(query);
          }).toList();
    }

    if (_filtroSeleccionado != 'todos') {
      filtrados =
          filtrados
              .where((doc) => doc.estado.toLowerCase() == _filtroSeleccionado)
              .toList();
    }

    if (_fechaDesdeFilter != null) {
      final desde = DateTime(
        _fechaDesdeFilter!.year,
        _fechaDesdeFilter!.month,
        _fechaDesdeFilter!.day,
      );
      filtrados =
          filtrados.where((doc) {
            final docDate = DateTime(
              doc.fechaDocumento.year,
              doc.fechaDocumento.month,
              doc.fechaDocumento.day,
            );
            return !docDate.isBefore(desde);
          }).toList();
    }
    if (_fechaHastaFilter != null) {
      final hasta = DateTime(
        _fechaHastaFilter!.year,
        _fechaHastaFilter!.month,
        _fechaHastaFilter!.day,
      );
      filtrados =
          filtrados.where((doc) {
            final docDate = DateTime(
              doc.fechaDocumento.year,
              doc.fechaDocumento.month,
              doc.fechaDocumento.day,
            );
            return !docDate.isAfter(hasta);
          }).toList();
    }
    if (_responsableIdFilter != null) {
      filtrados =
          filtrados
              .where((doc) => doc.responsableId == _responsableIdFilter)
              .toList();
    }
    if (_codigoQrFilter.trim().isNotEmpty) {
      final qr = _codigoQrFilter.toLowerCase().trim();
      filtrados =
          filtrados
              .where((doc) => (doc.codigoQR ?? '').toLowerCase().contains(qr))
              .toList();
    }

    return filtrados;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AuthProvider>(context);

    int crossAxisCount = 1;
    if (size.width > 1200) {
      crossAxisCount = 3;
    } else if (size.width > 800) {
      crossAxisCount = 2;
    }

    return Consumer<DataProvider>(
      builder: (context, dataProvider, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: _buildFloatingActionButton(),
          body: Column(
            children: [
              _construirFiltrosSuperior(theme),
              Expanded(
                child:
                    _carpetaSeleccionada != null
                        ? _construirVistaDocumentosCarpeta(theme)
                        : _construirVistaCarpetas(theme),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _agregarDocumento(Carpeta carpeta) async {
    print(
      'DEBUG: Agregando documento a carpeta "${carpeta.nombre}" (ID: ${carpeta.id})',
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentoFormScreen(initialCarpetaId: carpeta.id),
      ),
    );

    if (result == true && mounted) {
      print('DEBUG: Documento creado exitosamente, manteniendo vista actual');
      final subcarpetaId = carpeta.id;

      await _cargarDocumentosCarpeta(subcarpetaId);
      if (!mounted) return;
      await _cargarCarpetas(todasLasGestiones: true);
      if (!mounted) return;
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.refresh();
      if (mounted) setState(() {});
      if (mounted) _mostrarSnackBarExito('Documento agregado correctamente.');
    }
  }

  Future<void> _crearSubcarpeta(int padreId) async {
    print('DEBUG: Creando subcarpeta para padre ID: $padreId');

    // Obtener información de la carpeta padre
    final carpetaService = Provider.of<CarpetaService>(context, listen: false);
    final carpetaPadre = await carpetaService.getById(padreId);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SubcarpetaFormScreen(
              carpetaPadreId: padreId,
              carpetaPadreNombre: carpetaPadre.nombre,
            ),
      ),
    );

    if (result == true && mounted) {
      print('DEBUG: Subcarpeta creada exitosamente, actualizando listas');

      // Reload subcarpetas
      await _cargarSubcarpetas(padreId);

      // También recargar carpetas principales por si acaso
      await _cargarCarpetas();

      // Notificar al DataProvider
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.refresh();

      // Forzar rebuild
      if (mounted) {
        setState(() {});
      }

      _mostrarSnackBarExito('Subcarpeta creada correctamente.');
    }
  }

  Widget _construirVistaCarpetas(ThemeData theme) {
    if (_estaCargandoCarpetas) {
      return const Center(child: CircularProgressIndicator());
    }
    final carpetas = _carpetasFiltradas;

    // Header: título "Carpetas" + botón "Agregar carpeta" (más intuitivo)
    final headerCarpetas = Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Row(
        children: [
          Icon(Icons.folder_rounded, color: Colors.blue.shade700, size: 28),
          const SizedBox(width: 12),
          Text(
            'Carpetas',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => _abrirAgregarCarpeta(),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Agregar carpeta'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );

    if (_carpetas.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          headerCarpetas,
          Expanded(
            child: EmptyState(
              icon: Icons.folder_open_outlined,
              title: 'No hay carpetas',
              subtitle: 'Cree la primera con el botón de abajo (rango y fecha).',
              action: FilledButton.icon(
                onPressed: () => _abrirAgregarCarpeta(),
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text('Agregar carpeta'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (carpetas.isEmpty) {
      final numDocsEncontrados = _carpetaSeleccionada == null
          ? _documentosFiltrados.length
          : _documentosCarpetaFiltrados.length;
      final hayDocumentosConBusqueda = _consultaBusqueda.trim().isNotEmpty && numDocsEncontrados > 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          headerCarpetas,
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hayDocumentosConBusqueda ? Icons.description_outlined : Icons.search_off_rounded,
                      size: 56,
                      color: hayDocumentosConBusqueda ? Colors.green.shade600 : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      hayDocumentosConBusqueda
                          ? 'La búsqueda encontró $numDocsEncontrados documento(s)'
                          : _consultaBusqueda.trim().isEmpty
                              ? 'Ninguna carpeta con el filtro actual'
                              : 'Ninguna carpeta coincide con "$_consultaBusqueda"',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hayDocumentosConBusqueda
                          ? 'Véalos en el contenido principal (derecha).'
                          : 'Pruebe otro filtro o búsqueda, o agregue una carpeta.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _abrirAgregarCarpeta(),
                      icon: const Icon(Icons.add_rounded, size: 22),
                      label: const Text('Agregar carpeta'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        headerCarpetas,
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              childAspectRatio: 0.78,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
            ),
            itemCount: carpetas.length,
            itemBuilder: (context, index) {
              final c = carpetas[index];
              return _buildCarpetaCard(c, theme);
            },
          ),
        ),
      ],
    );
  }

  /// Abre el formulario de carpeta (solo rango y fecha).
  Future<void> _abrirAgregarCarpeta() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SubcarpetaFormScreen(
          carpetaPadreId: null,
          carpetaPadreNombre: 'Carpeta principal',
        ),
      ),
    );
    if (result == true && mounted) {
      await _cargarCarpetas(todasLasGestiones: true);
      if (!mounted) return;
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.refresh();
      setState(() {});
      _mostrarSnackBarExito('Carpeta creada correctamente.');
    }
  }

  Widget _buildCarpetaCard(Carpeta carpeta, ThemeData theme) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canDelete = authProvider.hasPermission('borrar_documento');

    final gestionLine = carpeta.gestion.isNotEmpty ? carpeta.gestion : 'N/A';
    final nroLine = carpeta.numeroCarpeta?.toString() ?? 'N/A';
    final rangoLine =
        (carpeta.rangoInicio != null && carpeta.rangoFin != null)
            ? '${carpeta.rangoInicio} - ${carpeta.rangoFin}'
            : 'Sin rango';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final clampedValue = value.clamp(0.0, 1.0);
        return Transform.scale(
          scale: 0.95 + (0.05 * clampedValue),
          child: Opacity(opacity: clampedValue, child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 25,
              offset: const Offset(0, 12),
              spreadRadius: -5,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _abrirCarpeta(carpeta),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header con icono y botón de borrar
                  Row(
                    children: [
                      Hero(
                        tag: 'folder_${carpeta.id}',
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.amber.shade400,
                                Colors.orange.shade500,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.folder_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (canDelete)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.shade100,
                              width: 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _confirmarEliminarCarpeta(carpeta),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.red.shade600,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  // Nombre de la carpeta
                  Text(
                    carpeta.nombre,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Información en chips
                  Wrap(
                    spacing: 5,
                    runSpacing: 3,
                    children: [
                      _buildInfoChip('Gestión', gestionLine, Colors.blue),
                      _buildInfoChip('Nº', nroLine, Colors.green),
                      _buildInfoChip('Rango', rangoLine, Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Footer: SSUT solo carpeta principal, solo documentos
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          color: Colors.blue.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${carpeta.numeroDocumentos} documentos',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.blue.shade400,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirVistaDocumentosCarpeta(ThemeData theme) {
    final carpeta = _carpetaSeleccionada!;
    final docs = _documentosCarpetaFiltrados;
    final rango =
        _estaCargandoDocumentosCarpeta
            ? 'Cargando...'
            : _calcularRangoCorrelativos(docs);
    final width = MediaQuery.of(context).size.width;
    final mostrarPanelLateral = width >= 900;

    final contenidoPrincipal = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCarpetaHeader(carpeta, rango, theme, mostrarMenuDrawer: !mostrarPanelLateral),
        _buildViewControls(theme),
        Expanded(
          child:
              _estaCargandoDocumentosCarpeta
                  ? _buildDocumentosLoading()
                  : docs.isEmpty
                  ? _buildDocumentosEmpty()
                  : _vistaGrid
                  ? _construirGridDocumentosCarpeta(docs, theme)
                  : _construirListaDocumentos(docs, theme),
        ),
      ],
    );

    final panelCarpetas = _buildPanelCarpetasLateral(theme);

    if (mostrarPanelLateral) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          panelCarpetas,
          Expanded(child: contenidoPrincipal),
        ],
      );
    }

    return Scaffold(
      body: contenidoPrincipal,
      drawer: Drawer(
        child: panelCarpetas,
      ),
    );
  }

  /// Panel lateral de carpetas (lista + botón Agregar carpeta). Visible dentro de una carpeta.
  Widget _buildPanelCarpetasLateral(ThemeData theme) {
    var carpetas = _carpetas
        .where((c) => c.carpetaPadreId == null)
        .where((c) =>
            _gestionFilterCarpetas == null ||
            _gestionFilterCarpetas!.isEmpty ||
            c.gestion == _gestionFilterCarpetas)
        .toList();
    if (_consultaBusqueda.trim().isNotEmpty) {
      final q = _consultaBusqueda.toLowerCase().trim();
      carpetas = carpetas
          .where((c) =>
              c.nombre.toLowerCase().contains(q) ||
              (c.codigo?.toLowerCase().contains(q) ?? false) ||
              c.gestion.toLowerCase().contains(q))
          .toList();
    }
    final width = MediaQuery.of(context).size.width;
    final esDrawer = width < 900;
    final panelWidth = esDrawer ? null : 280.0;

    Widget header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Icon(Icons.folder_rounded, color: Colors.blue.shade700, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Carpetas',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              if (esDrawer) Navigator.pop(context);
              await _abrirAgregarCarpeta();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
            child: const Icon(Icons.add, size: 20),
          ),
        ],
      ),
    );

    final noHayNinguna = _carpetas.isEmpty;

    Widget listContent;
    if (_estaCargandoCarpetas) {
      listContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Cargando carpetas...',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    } else if (carpetas.isEmpty) {
      final numDocsEncontrados = _carpetaSeleccionada == null
          ? _documentosFiltrados.length
          : _documentosCarpetaFiltrados.length;
      final hayDocumentosConBusqueda = _consultaBusqueda.trim().isNotEmpty && numDocsEncontrados > 0;
      listContent = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                noHayNinguna
                    ? Icons.folder_open_outlined
                    : hayDocumentosConBusqueda ? Icons.description_outlined : Icons.search_off_rounded,
                size: 56,
                color: hayDocumentosConBusqueda ? Colors.green.shade600 : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                noHayNinguna
                    ? 'No hay carpetas'
                    : hayDocumentosConBusqueda
                        ? 'La búsqueda encontró $numDocsEncontrados documento(s)'
                        : 'Sin resultados',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                noHayNinguna
                    ? 'Cree la primera con el botón de abajo.'
                    : hayDocumentosConBusqueda
                        ? 'Véalos en el contenido principal (derecha).'
                        : 'Pruebe otro filtro o búsqueda, o agregue una carpeta.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  if (esDrawer) Navigator.pop(context);
                  await _abrirAgregarCarpeta();
                },
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text('Agregar carpeta'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  minimumSize: const Size(0, 48),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      listContent = ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        itemCount: carpetas.length,
        itemBuilder: (context, index) {
          final c = carpetas[index];
          final seleccionada = _carpetaSeleccionada?.id == c.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: seleccionada ? Colors.blue.shade50 : null,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  if (esDrawer) Navigator.pop(context);
                  _abrirCarpeta(c);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        seleccionada ? Icons.folder_open_rounded : Icons.folder_rounded,
                        size: 20,
                        color: seleccionada ? Colors.blue.shade700 : Colors.amber.shade700,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: seleccionada ? FontWeight.w600 : null,
                            color: seleccionada ? Colors.blue.shade800 : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    final panel = Container(
      width: panelWidth,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const Divider(height: 1),
          Expanded(child: listContent),
        ],
      ),
    );

    if (esDrawer) {
      return panel;
    }
    return panel;
  }

  /// Mensaje cuando estamos en una carpeta (sin subcarpetas aún): aquí solo se agregan subcarpetas.
  Widget _buildSoloSubcarpetasMessage(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 64,
              color: Colors.blue.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'En esta carpeta solo se agregan subcarpetas',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use el botón "Nueva Subcarpeta" para crear una. Dentro de cada subcarpeta podrá agregar documentos.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarpetaHeader(Carpeta carpeta, String rango, ThemeData theme, {bool mostrarMenuDrawer = false}) {
    final esCarpeta = carpeta.carpetaPadreId == null;
    final esSubcarpeta = !esCarpeta;
    final margin = esSubcarpeta ? 12.0 : 24.0;
    final padding = esSubcarpeta ? 12.0 : 24.0;

    return Container(
      margin: EdgeInsets.all(margin),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.indigo.shade50],
        ),
        borderRadius: BorderRadius.circular(esSubcarpeta ? 14 : 20),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: esSubcarpeta ? 12 : 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (mostrarMenuDrawer)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: Icon(Icons.menu_rounded, size: 22, color: Colors.blue.shade700),
                    padding: const EdgeInsets.all(10),
                    tooltip: 'Ver carpetas',
                  ),
                ),
              // Botón de regreso
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(esSubcarpeta ? 10 : 12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: () {
                    if (widget.initialCarpetaId != null) {
                      Navigator.pop(context);
                    } else {
                      if (_carpetaSeleccionada?.carpetaPadreId != null) {
                        _navegarACarpetaPadre(
                          _carpetaSeleccionada!.carpetaPadreId!,
                        );
                      } else {
                        setState(() => _carpetaSeleccionada = null);
                      }
                    }
                  },
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    size: esSubcarpeta ? 20 : 24,
                  ),
                  color: Colors.blue.shade700,
                  padding: EdgeInsets.all(esSubcarpeta ? 6 : 12),
                  constraints: BoxConstraints(
                    minWidth: esSubcarpeta ? 36 : 48,
                    minHeight: esSubcarpeta ? 36 : 48,
                  ),
                ),
              ),
              SizedBox(width: esSubcarpeta ? 10 : 16),
              // Icono de la carpeta
              Hero(
                tag: 'folder_icon_${carpeta.id}',
                child: Container(
                  padding: EdgeInsets.all(esSubcarpeta ? 10 : 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade800],
                    ),
                    borderRadius: BorderRadius.circular(esSubcarpeta ? 12 : 16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.folder_open_rounded,
                    color: Colors.white,
                    size: esSubcarpeta ? 22 : 32,
                  ),
                ),
              ),
              SizedBox(width: esSubcarpeta ? 10 : 16),
              // Información de la carpeta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      carpeta.nombre,
                      style: GoogleFonts.poppins(
                        fontSize: esSubcarpeta ? 16 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: esSubcarpeta ? 2 : 4),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: esSubcarpeta ? 8 : 12,
                        vertical: esSubcarpeta ? 4 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rango,
                        style: GoogleFonts.inter(
                          fontSize: esSubcarpeta ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Estadísticas: una fila más compacta en subcarpetas
          SizedBox(height: esSubcarpeta ? 10 : 20),
          Row(
            children: [
              Expanded(
                child: _buildCarpetaStat(
                  'Subcarpetas',
                  '${_subcarpetas.length}',
                  Icons.folder_copy,
                  Colors.orange,
                  compact: esSubcarpeta,
                ),
              ),
              SizedBox(width: esSubcarpeta ? 8 : 16),
              Expanded(
                child: _buildCarpetaStat(
                  esCarpeta ? 'Docs (total)' : 'Documentos',
                  esCarpeta
                      ? '${_subcarpetas.fold<int>(0, (sum, sub) => sum + sub.numeroDocumentos)}'
                      : '${_documentosCarpeta.length}',
                  Icons.description,
                  Colors.green,
                  compact: esSubcarpeta,
                ),
              ),
              SizedBox(width: esSubcarpeta ? 8 : 16),
              Expanded(
                child: _buildCarpetaStat(
                  'Gestión',
                  carpeta.gestion,
                  Icons.calendar_today,
                  Colors.blue,
                  compact: esSubcarpeta,
                ),
              ),
            ],
          ),
          // Botón Agregar documento visible al entrar a la carpeta
          if (Provider.of<AuthProvider>(context).hasPermission('subir_documento')) ...[
            SizedBox(height: esSubcarpeta ? 12 : 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _agregarDocumento(carpeta),
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text('Agregar documento'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: EdgeInsets.symmetric(vertical: esSubcarpeta ? 10 : 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCarpetaStat(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool compact = false,
  }) {
    final pad = compact ? 8.0 : 16.0;
    final iconSize = compact ? 18.0 : 24.0;
    final valueSize = compact ? 14.0 : 18.0;
    final labelSize = compact ? 10.0 : 12.0;
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: iconSize),
          SizedBox(height: compact ? 4 : 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: valueSize,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: labelSize,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSubcarpetasSection(ThemeData theme) {
    // Altura suficiente para cabecera (~52px) + tarjeta subcarpeta (148px) sin overflow
    const double cardHeight = 148;
    const double sectionHeight = 52 + cardHeight; // 200
    return Container(
      height: sectionHeight,
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(
                  Icons.folder_copy,
                  color: Colors.orange.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Subcarpetas',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_subcarpetas.length} carpetas',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _subcarpetas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final sub = _subcarpetas[index];
                return _buildModernSubcarpetaCard(sub, theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSubcarpetaCard(Carpeta sub, ThemeData theme) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canDelete = authProvider.hasPermission('borrar_documento');

    return SizedBox(
      width: 200,
      height: 148,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.orange.shade50],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
              spreadRadius: -3,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _abrirCarpeta(sub),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Header con icono y botón de borrar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade400,
                              Colors.orange.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.folder_shared_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const Spacer(),
                      if (canDelete)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _confirmarEliminarCarpeta(sub),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red.shade600,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 6),
                  // Nombre de la subcarpeta
                  Flexible(
                    child: Text(
                      sub.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Información del rango
                  if (sub.rangoInicio != null && sub.rangoFin != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        'Rango ${sub.rangoInicio}-${sub.rangoFin}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 6),
                  // Footer con estadísticas
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description,
                          size: 12,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${sub.numeroDocumentos} docs',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewControls(ThemeData theme) {
    final compact = _carpetaSeleccionada?.carpetaPadreId != null;
    final marginV = compact ? 8.0 : 16.0;
    final marginH = compact ? 12.0 : 24.0;
    final height = compact ? 40.0 : 48.0;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: marginH, vertical: marginV),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _vistaGrid = true),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient:
                                _vistaGrid
                                    ? LinearGradient(
                                      colors: [
                                        Colors.blue.shade600,
                                        Colors.blue.shade700,
                                      ],
                                    )
                                    : null,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.grid_view_rounded,
                                size: 18,
                                color:
                                    _vistaGrid
                                        ? Colors.white
                                        : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Cuadrícula',
                                style: GoogleFonts.poppins(
                                  color:
                                      _vistaGrid
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, color: Colors.grey.shade200),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _vistaGrid = false),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient:
                                !_vistaGrid
                                    ? LinearGradient(
                                      colors: [
                                        Colors.blue.shade600,
                                        Colors.blue.shade700,
                                      ],
                                    )
                                    : null,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.list_rounded,
                                size: 18,
                                color:
                                    !_vistaGrid
                                        ? Colors.white
                                        : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Lista',
                                style: GoogleFonts.poppins(
                                  color:
                                      !_vistaGrid
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentosLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Cargando documentos...'),
        ],
      ),
    );
  }

  Widget _buildDocumentosEmpty() {
    final conFiltros = _tieneFiltrosAvanzados;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                conFiltros ? Icons.search_off_rounded : Icons.description_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              conFiltros ? 'Sin coincidencias' : 'Sin documentos',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              conFiltros
                  ? 'No se encontraron documentos con los criterios ingresados.\nPruebe ajustar el número de comprobante, fecha o responsable.'
                  : 'Agregue el primer documento a esta carpeta',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _calcularRangoCorrelativos(List<Documento> docs) {
    final nums = <int>[];
    for (final d in docs) {
      final n = int.tryParse(d.numeroCorrelativo);
      if (n != null) nums.add(n);
    }
    if (nums.isEmpty) return 'Sin correlativos';
    nums.sort();
    return 'Comprobantes ${nums.first} - ${nums.last}';
  }

  Widget _construirGridDocumentosCarpeta(
    List<Documento> docs,
    ThemeData theme,
  ) {
    final compact = _carpetaSeleccionada?.carpetaPadreId != null;
    final paddingH = compact ? 12.0 : 24.0;
    final paddingB = compact ? 16.0 : 24.0;
    final spacing = compact ? 12.0 : 20.0;
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(paddingH, 0, paddingH, paddingB),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: compact ? 380 : 420,
        childAspectRatio: compact ? 1.45 : 1.6,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: docs.length,
      itemBuilder:
          (context, index) => _buildModernCard(docs[index], theme, index),
    );
  }

  Widget _construirListaDocumentos(List<Documento> docs, ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final d = docs[index];
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            final clampedValue = value.clamp(0.0, 1.0);
            return Transform.translate(
              offset: Offset(0, 20 * (1 - clampedValue)),
              child: Opacity(opacity: clampedValue, child: child),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _navegarAlDetalle(d),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Icono del documento
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _obtenerIconoTipoDocumento(
                            d.tipoDocumentoNombre ?? '',
                          ),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Información del documento
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    d.codigo,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                                _buildEstadoBadge(d.estado),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              d.descripcion ?? 'Sin descripción',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 12,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatearFecha(d.fechaRegistro),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Nº ${d.numeroCorrelativo}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Botón de acción
                      _buildActionButton(d),

                      const SizedBox(width: 8),

                      // Icono de navegación
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _construirFiltrosSuperior(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      if (_consultaBusqueda != value) {
                        setState(() {
                          _consultaBusqueda = value;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar...',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary.withOpacity(0.5),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _buildFilterButton(theme),
            ],
          ),
        ],
      ),
    );
  }

  void _abrirFiltroCarpetas(ThemeData theme) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder:
          (ctx) => _DialogFiltroCarpetas(
            gestionActual: _gestionFilterCarpetas,
            gestiones: _gestionesCarpetas,
            onAplicar: (gestion) {
              setState(() => _gestionFilterCarpetas = gestion);
              Navigator.pop(ctx);
            },
            onLimpiar: () {
              setState(() {
                _gestionFilterCarpetas = null;
                _consultaBusqueda = '';
                _searchController.clear();
              });
              Navigator.pop(ctx);
            },
          ),
    );
  }

  bool get _tieneFiltrosAvanzados =>
      _numeroComprobanteFilter.trim().isNotEmpty ||
      _fechaDesdeFilter != null ||
      _fechaHastaFilter != null ||
      _responsableIdFilter != null ||
      _codigoQrFilter.trim().isNotEmpty;

  void _abrirBusquedaAvanzada(ThemeData theme) {
    _codigoQrFilterController.text = _codigoQrFilter;
    _numeroComprobanteFilterController.text = _numeroComprobanteFilter;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder:
          (context) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _FiltrosAvanzadosSheet(
                theme: theme,
                numeroComprobanteController: _numeroComprobanteFilterController,
                fechaDesde: _fechaDesdeFilter,
                fechaHasta: _fechaHastaFilter,
                responsableId: _responsableIdFilter,
                codigoQrController: _codigoQrFilterController,
                onAplicar: (numeroComprobante, fechaDesde, fechaHasta, responsableId, codigoQr) {
                  setState(() {
                    _numeroComprobanteFilter = numeroComprobante;
                    _fechaDesdeFilter = fechaDesde;
                    _fechaHastaFilter = fechaHasta;
                    _responsableIdFilter = responsableId;
                    _codigoQrFilter = codigoQr;
                  });
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted && _carpetaSeleccionada != null) {
                    _cargarDocumentosCarpeta(_carpetaSeleccionada!.id);
                  }
                },
                onLimpiar: () {
                  setState(() {
                    _numeroComprobanteFilter = '';
                    _numeroComprobanteFilterController.clear();
                    _fechaDesdeFilter = null;
                    _fechaHastaFilter = null;
                    _responsableIdFilter = null;
                    _codigoQrFilter = '';
                    _codigoQrFilterController.clear();
                    _consultaBusqueda = '';
                    _searchController.clear();
                    _filtroSeleccionado = 'todos';
                  });
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted && _carpetaSeleccionada != null) {
                    _cargarDocumentosCarpeta(_carpetaSeleccionada!.id);
                  }
                },
              ),
            ),
          ),
    );
  }

  Widget _buildFilterButton(ThemeData theme) {
    final enVistaCarpetas = _carpetaSeleccionada == null;
    final tieneFiltro =
        enVistaCarpetas
            ? (_gestionFilterCarpetas != null ||
                _consultaBusqueda.trim().isNotEmpty)
            : _tieneFiltrosAvanzados;
    return Container(
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        color:
            tieneFiltro
                ? theme.colorScheme.primary.withOpacity(0.25)
                : theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconButton(
        icon: Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
        onPressed: () {
          if (enVistaCarpetas) {
            _abrirFiltroCarpetas(theme);
          } else {
            _abrirBusquedaAvanzada(theme);
          }
        },
      ),
    );
  }

  Widget _construirChipsSelector(ThemeData theme) {
    final filtros = [
      {'value': 'todos', 'label': 'Todos', 'icon': Icons.grid_view_rounded},
      {
        'value': 'activo',
        'label': 'Activos',
        'icon': Icons.check_circle_rounded,
      },
      {
        'value': 'archivado',
        'label': 'Archivados',
        'icon': Icons.archive_rounded,
      },
      {
        'value': 'prestado',
        'label': 'Prestados',
        'icon': Icons.handshake_rounded,
      },
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filtros.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final f = filtros[index];
          final isSel = _filtroSeleccionado == f['value'];
          return ChoiceChip(
            avatar: Icon(
              f['icon'] as IconData,
              size: 16,
              color: isSel ? Colors.white : theme.colorScheme.primary,
            ),
            label: Text(f['label'] as String),
            selected: isSel,
            onSelected:
                (val) =>
                    setState(() => _filtroSeleccionado = f['value'] as String),
            selectedColor: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.surface,
            labelStyle: GoogleFonts.inter(
              color: isSel ? Colors.white : theme.colorScheme.onSurface,
              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(
              color:
                  isSel
                      ? Colors.transparent
                      : theme.colorScheme.outline.withOpacity(0.1),
            ),
          );
        },
      ),
    );
  }

  Widget _construirShimmerCarga(int columns) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: columns == 1 ? 2.5 : 1.4,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => _buildShimmerCard(),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const LoadingShimmer(
                width: 40,
                height: 40,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              LoadingShimmer(
                width: 60,
                height: 24,
                borderRadius: BorderRadius.circular(10),
              ),
            ],
          ),
          const Spacer(),
          const LoadingShimmer(width: 120, height: 24),
          const SizedBox(height: 8),
          const LoadingShimmer(width: double.infinity, height: 16),
          const SizedBox(height: 4),
          const LoadingShimmer(width: 100, height: 16),
          const Spacer(),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const LoadingShimmer(width: 80, height: 16),
              const Spacer(),
              const LoadingShimmer(width: 40, height: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirGridDocumentos(ThemeData theme, int columns) {
    final filtrados = _documentosFiltrados;
    return RefreshIndicator(
      onRefresh: cargarDocumentos,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          childAspectRatio: 1.4,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: filtrados.length,
        itemBuilder:
            (context, index) =>
                _buildModernCard(filtrados[index], theme, index),
      ),
    );
  }

  Widget _buildModernCard(Documento doc, ThemeData theme, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final clampedValue = value.clamp(0.0, 1.0);
        return Transform.scale(
          scale: 0.9 + (0.1 * clampedValue),
          child: Opacity(opacity: clampedValue, child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navegarAlDetalle(doc),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header con icono y estado
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _obtenerIconoTipoDocumento(
                            doc.tipoDocumentoNombre ?? '',
                          ),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      _buildEstadoBadge(doc.estado),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Código del documento
                  Text(
                    doc.codigo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey.shade800,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Descripción
                  Text(
                    doc.descripcion ?? 'Sin descripción',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),

                  const Spacer(),

                  // Divider
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey.shade200,
                          Colors.grey.shade100,
                          Colors.grey.shade200,
                        ],
                      ),
                    ),
                  ),

                  // Footer con información adicional
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _formatearFecha(doc.fechaRegistro),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Nº ${doc.numeroCorrelativo}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(doc),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoBadge(String estado) {
    final color = _obtenerColorEstado(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        estado.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildActionButton(Documento doc) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canDelete = authProvider.hasPermission('borrar_documento');

    if (!canDelete) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        onPressed: () => _confirmarEliminarDocumento(doc),
        icon: Icon(
          Icons.delete_outline_rounded,
          color: Colors.red.shade600,
          size: 18,
        ),
        iconSize: 18,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        tooltip: 'Eliminar documento',
      ),
    );
  }

  Widget _buildCardHeader(Documento doc, ThemeData theme) {
    final color = _obtenerColorEstado(doc.estado);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            _obtenerIconoTipoDocumento(doc.tipoDocumentoNombre ?? ''),
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              doc.estado.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardFooter(Documento doc, ThemeData theme) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canDelete = authProvider.hasPermission('borrar_documento');

    return Row(
      children: [
        Icon(
          Icons.calendar_today_rounded,
          size: 14,
          color: theme.colorScheme.onSurface.withOpacity(0.4),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _formatearFecha(doc.fechaRegistro),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ),
        const Spacer(),
        Text(
          'G-${doc.gestion}',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        if (canDelete)
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: Colors.red.shade600,
            ),
            onPressed: () => _confirmarEliminarDocumento(doc),
            tooltip: 'Eliminar documento',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  Color _obtenerColorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'activo':
        return AppTheme.colorExito;
      case 'archivado':
        return AppTheme.colorInfo;
      case 'prestado':
        return AppTheme.colorAdvertencia;
      default:
        return AppTheme.colorPrimario;
    }
  }

  IconData _obtenerIconoTipoDocumento(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'factura':
        return Icons.receipt_long_rounded;
      case 'contrato':
        return Icons.handshake_rounded;
      case 'informe':
        return Icons.analytics_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  void _navegarAlDetalle(Documento doc) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentoDetailScreen(documento: doc),
      ),
    );

    // Si se eliminó el documento desde el detalle, recargar la lista
    if (result == true) {
      cargarDocumentos();
      if (_carpetaSeleccionada != null) {
        _cargarDocumentosCarpeta(_carpetaSeleccionada!.id);
      }
    }
  }

  Future<void> _confirmarEliminarDocumento(Documento doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar documento'),
            content: Text(
              '¿Estás seguro de eliminar el documento "${doc.codigo}"?\n\nEsta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sí, Eliminar'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _eliminarDocumento(doc);
    }
  }

  Future<void> _eliminarDocumento(Documento doc) async {
    try {
      final service = Provider.of<DocumentoService>(context, listen: false);
      await service.delete(doc.id);

      if (!mounted) return;

      // Notificar al DataProvider
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.notifyDocumentoDeleted(doc.id);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Documento "${doc.codigo}" eliminado correctamente'),
            ],
          ),
          backgroundColor: AppTheme.colorExito,
        ),
      );

      // Recargar la lista de documentos
      await cargarDocumentos();
      if (_carpetaSeleccionada != null) {
        await _cargarDocumentosCarpeta(_carpetaSeleccionada!.id);
      }
    } catch (e) {
      if (!mounted) return;

      _mostrarSnackBarError(
        'Error al eliminar: ${ErrorHelper.getErrorMessage(e)}',
      );
    }
  }

  Future<void> _abrirDocumentoEnCarpeta(Carpeta carpeta) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentoFormScreen(initialCarpetaId: carpeta.id),
      ),
    );
    if (result == true) {
      await cargarDocumentos();
      await _cargarCarpetas();
      await _cargarDocumentosCarpeta(carpeta.id);
    }
  }

  /// Abre el formulario Nuevo Documento (N° Correlativo y Clasificación y Contenido).
  Future<void> _abrirNuevoDocumento() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DocumentoFormScreen(initialCarpetaId: null),
      ),
    );

    if (result == true && mounted) {
      await _cargarCarpetas(todasLasGestiones: true);
      if (!mounted) return;
      await cargarDocumentos();
      if (!mounted) return;
      if (_carpetaSeleccionada != null) {
        await _cargarDocumentosCarpeta(_carpetaSeleccionada!.id);
      }
      if (!mounted) return;
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.refresh();
      if (mounted) {
        setState(() {});
        _mostrarSnackBarExito('Documento registrado correctamente.');
      }
    }
  }

  void _mostrarSnackBarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(fontSize: 14),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.colorError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _mostrarSnackBarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _confirmarEliminarCarpeta(Carpeta carpeta) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar carpeta'),
            content: Text(
              '¿Estás seguro de eliminar la carpeta "${carpeta.nombre}"?\n\n'
              'Se eliminarán todas sus subcarpetas y documentos asociados de forma permanente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sí, Borrar Todo'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _eliminarCarpeta(carpeta);
    }
  }

  Future<void> _eliminarCarpeta(Carpeta carpeta) async {
    try {
      final carpetaService = Provider.of<CarpetaService>(
        context,
        listen: false,
      );
      final idEliminado = carpeta.id;
      final eraLaCarpetaActual = _carpetaSeleccionada?.id == idEliminado;

      await carpetaService.delete(idEliminado, hard: true);

      if (!mounted) return;

      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.notifyCarpetaDeleted(idEliminado);

      // Si estábamos dentro de la carpeta eliminada (o de una hija), volver a lista de carpetas
      if (eraLaCarpetaActual) {
        setState(() => _carpetaSeleccionada = null);
      } else if (carpeta.carpetaPadreId != null) {
        await _cargarSubcarpetas(carpeta.carpetaPadreId!);
      }

      // Recargar lista completa de carpetas para que la UI refleje el borrado
      await _cargarCarpetas(todasLasGestiones: true);

      if (!mounted) return;
      _mostrarSnackBarExito('Carpeta eliminada correctamente.');
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackBarError(
        'No se pudo eliminar: ${ErrorHelper.getErrorMessage(e)}',
      );
    }
  }

  Widget _buildSubcarpetaCard(Carpeta sub, ThemeData theme) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canDelete = authProvider.hasPermission('borrar_documento');

    return InkWell(
      onTap: () => _abrirCarpeta(sub),
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            width: 140,
            height: 120,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.folder_shared_rounded,
                  color: Colors.blue,
                  size: 28,
                ),
                const Spacer(),
                Text(
                  sub.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
                if (sub.rangoInicio != null && sub.rangoFin != null)
                  Text(
                    'Rango ${sub.rangoInicio} - ${sub.rangoFin}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.blueGrey,
                    ),
                  ),
              ],
            ),
          ),
          if (canDelete)
            Positioned(
              top: 6,
              right: 6,
              child: InkWell(
                onTap: () => _confirmarEliminarCarpeta(sub),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _canCreateDocument() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.hasPermission('subir_documento');
  }

  Widget? _buildFloatingActionButton() {
    final authProvider = Provider.of<AuthProvider>(context);

    // Vista carpetas (no estamos dentro de una carpeta): solo "Nueva carpeta"
    if (_carpetaSeleccionada == null) {
      return FloatingActionButton.extended(
        onPressed: () => _abrirAgregarCarpeta(),
        icon: const Icon(Icons.create_new_folder),
        label: const Text('Nueva carpeta'),
        backgroundColor: Colors.blue.shade700,
        heroTag: 'fab_carpeta',
      );
    }

    // Dentro de una carpeta: "Nuevo Documento" (solo si tiene permiso)
    if (!authProvider.hasPermission('subir_documento')) {
      return null;
    }
    return FloatingActionButton.extended(
      onPressed: () => _agregarDocumento(_carpetaSeleccionada!),
      icon: const Icon(Icons.add),
      label: const Text('Nuevo Documento'),
      backgroundColor: Colors.blue.shade700,
      heroTag: 'fab_documento',
    );
  }
}

/// Diálogo para filtrar carpetas por gestión (vista Carpetas).
class _DialogFiltroCarpetas extends StatefulWidget {
  const _DialogFiltroCarpetas({
    required this.gestionActual,
    required this.gestiones,
    required this.onAplicar,
    required this.onLimpiar,
  });

  final String? gestionActual;
  final List<String> gestiones;
  final void Function(String? gestion) onAplicar;
  final VoidCallback onLimpiar;

  @override
  State<_DialogFiltroCarpetas> createState() => _DialogFiltroCarpetasState();
}

class _DialogFiltroCarpetasState extends State<_DialogFiltroCarpetas> {
  late String? _gestion;

  @override
  void initState() {
    super.initState();
    _gestion = widget.gestionActual;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtrar carpetas'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Gestión:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _gestion,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas las gestiones'),
              ),
              ...widget.gestiones.map(
                (g) => DropdownMenuItem<String?>(
                  value: g,
                  child: Text('Gestión $g'),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _gestion = v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: widget.onLimpiar, child: const Text('Limpiar')),
        FilledButton(
          onPressed: () => widget.onAplicar(_gestion),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}

/// Bottom sheet para búsqueda avanzada: número comprobante, fecha, responsable, código QR.
class _FiltrosAvanzadosSheet extends StatefulWidget {
  const _FiltrosAvanzadosSheet({
    required this.theme,
    required this.numeroComprobanteController,
    required this.fechaDesde,
    required this.fechaHasta,
    required this.responsableId,
    required this.codigoQrController,
    required this.onAplicar,
    required this.onLimpiar,
  });

  final ThemeData theme;
  final TextEditingController numeroComprobanteController;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final int? responsableId;
  final TextEditingController codigoQrController;
  final void Function(
    String numeroComprobante,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int? responsableId,
    String codigoQr,
  )
  onAplicar;
  final VoidCallback onLimpiar;

  @override
  State<_FiltrosAvanzadosSheet> createState() => _FiltrosAvanzadosSheetState();
}

class _FiltrosAvanzadosSheetState extends State<_FiltrosAvanzadosSheet> {
  late DateTime? _fechaDesde;
  late DateTime? _fechaHasta;
  late int? _responsableId;
  List<Usuario> _usuarios = [];
  bool _loadingUsuarios = true;

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _fechaDesde = widget.fechaDesde;
    _fechaHasta = widget.fechaHasta;
    _responsableId = widget.responsableId;
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    try {
      final service = Provider.of<UsuarioService>(context, listen: false);
      final list = await service.getAll();
      if (mounted)
        setState(() {
          _usuarios = list;
          _loadingUsuarios = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingUsuarios = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Búsqueda avanzada',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Filtre por fecha, responsable y número de comprobante',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              // 1. FECHA (desde / hasta)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _fechaDesde ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null && mounted)
                          setState(() => _fechaDesde = picked);
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 20),
                      label: Text(
                        _fechaDesde == null
                            ? 'Fecha desde'
                            : _dateFormat.format(_fechaDesde!),
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _fechaHasta ?? DateTime.now(),
                          firstDate: _fechaDesde ?? DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null && mounted)
                          setState(() => _fechaHasta = picked);
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 20),
                      label: Text(
                        _fechaHasta == null
                            ? 'Fecha hasta'
                            : _dateFormat.format(_fechaHasta!),
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 2. RESPONSABLE
              if (_loadingUsuarios)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                DropdownButtonFormField<int?>(
                  value: _responsableId,
                  decoration: InputDecoration(
                    labelText: 'Responsable',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos'),
                    ),
                    ..._usuarios.map(
                      (u) => DropdownMenuItem<int?>(
                        value: u.id,
                        child: Text('${u.nombreCompleto} (${u.nombreUsuario})'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _responsableId = v),
                ),
              const SizedBox(height: 16),
              // 3. NÚMERO DE COMPROBANTE
              TextFormField(
                controller: widget.numeroComprobanteController,
                decoration: InputDecoration(
                  labelText: 'Número de comprobante',
                  hintText: 'Ej: 1, 5, 10',
                  prefixIcon: const Icon(Icons.numbers_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              // Código QR (opcional)
              TextFormField(
                controller: widget.codigoQrController,
                decoration: InputDecoration(
                  labelText: 'Código QR',
                  hintText: 'Parte del código QR del documento',
                  prefixIcon: const Icon(Icons.qr_code_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onLimpiar,
                      icon: const Icon(Icons.clear_all_rounded, size: 20),
                      label: const Text('Limpiar'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () {
                        widget.onAplicar(
                          widget.numeroComprobanteController.text.trim(),
                          _fechaDesde,
                          _fechaHasta,
                          _responsableId,
                          widget.codigoQrController.text.trim(),
                        );
                      },
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: const Text('Aplicar filtros'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
