import 'dart:async';
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
import '../../widgets/app_alert.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_shimmer.dart';
import 'documento_detail_screen.dart';
import 'documento_form_screen.dart';
import 'subcarpeta_form_screen.dart';

import 'components/carpeta_card.dart';
import 'components/subcarpeta_card.dart';
import 'components/documento_card.dart';
import 'components/documentos_filter_chips.dart';
import 'components/dialog_filtro_carpetas.dart';
import 'components/filtros_avanzados_sheet.dart';
import 'components/breadcrumb_header.dart';

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
  String _filtroTipoDocumento = 'todos';
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
  String _tipoCarpetaFiltro = 'Todos'; // Todos, Comprobante de Ingreso, Comprobante de Egreso

  /// Gestiones existentes en las carpetas cargadas, ordenadas descendente (2026, 2025, 2022...).
  List<String> get _gestionesCarpetasDisponibles {
    final set = <String>{};
    for (final c in _carpetas) {
      if (c.gestion.trim().isNotEmpty) set.add(c.gestion.trim());
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    return list.isNotEmpty ? list : ['2024', '2025', '2026'];
  }

  /// Debounce para recargar documentos al escribir en la búsqueda dentro de una carpeta.
  Timer? _debounceBusquedaCarpeta;

  /// En vista Carpetas: documentos encontrados por búsqueda (código/número).
  List<Documento> _documentosBusquedaCarpetas = [];
  bool _estaCargandoBusquedaDocumentos = false;
  Timer? _debounceBusquedaVistaCarpetas;

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
    _debounceBusquedaCarpeta?.cancel();
    _debounceBusquedaVistaCarpetas?.cancel();
    _searchController.dispose();
    _codigoQrFilterController.dispose();
    _numeroComprobanteFilterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _alCambiarBusqueda() {
    final texto = _searchController.text;
    setState(() {
      _consultaBusqueda = texto;
    });
    // Dentro de una carpeta: recargar documentos con el texto de búsqueda en el API (debounce).
    if (_carpetaSeleccionada != null) {
      _debounceBusquedaCarpeta?.cancel();
      _debounceBusquedaCarpeta = Timer(const Duration(milliseconds: 400), () {
        if (mounted && _carpetaSeleccionada != null) {
          _cargarDocumentosCarpeta(_carpetaSeleccionada!.id);
        }
      });
      return;
    }
    // Vista Carpetas: buscar documentos solo si hay 3+ caracteres; priorizar carpetas.
    _debounceBusquedaVistaCarpetas?.cancel();
    if (texto.trim().isEmpty) {
      setState(() {
        _documentosBusquedaCarpetas = [];
        _estaCargandoBusquedaDocumentos = false;
      });
      _cargarCarpetas(todasLasGestiones: true);
      return;
    }
    if (texto.trim().length < 3) {
      setState(() {
        _documentosBusquedaCarpetas = [];
        _estaCargandoBusquedaDocumentos = false;
      });
      _cargarCarpetas(todasLasGestiones: true);
      return;
    }
    _debounceBusquedaVistaCarpetas = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _carpetaSeleccionada == null) {
        _buscarDocumentosDesdeVistaCarpetas();
      }
    });
  }

  /// Busca documentos por texto (código, número) desde la vista Carpetas. Solo si hay 3+ caracteres.
  Future<void> _buscarDocumentosDesdeVistaCarpetas() async {
    final query = _consultaBusqueda.trim();
    if (query.isEmpty || query.length < 3) {
      if (mounted) setState(() {
        _documentosBusquedaCarpetas = [];
        _estaCargandoBusquedaDocumentos = false;
      });
      return;
    }
    setState(() => _estaCargandoBusquedaDocumentos = true);
    try {
      final service = Provider.of<DocumentoService>(context, listen: false);
      final dto = BusquedaDocumentoDTO(
        textoBusqueda: query,
        page: 1,
        pageSize: 50,
        orderBy: 'fechaDocumento',
        orderDirection: 'DESC',
      );
      final result = await service.buscar(dto);
      if (mounted && _carpetaSeleccionada == null) {
        setState(() {
          _documentosBusquedaCarpetas = result.items;
          _estaCargandoBusquedaDocumentos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _documentosBusquedaCarpetas = [];
          _estaCargandoBusquedaDocumentos = false;
        });
      }
    }
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
      final textoBusqueda = _consultaBusqueda.trim().isEmpty ? null : _consultaBusqueda.trim();
      final dto = BusquedaDocumentoDTO(
        carpetaId: carpetaId,
        numeroCorrelativo: n.isEmpty ? null : n,
        fechaDesde: _fechaDesdeFilter,
        fechaHasta: _fechaHastaFilter,
        responsableId: _responsableIdFilter,
        codigoQR: _codigoQrFilter.trim().isEmpty ? null : _codigoQrFilter.trim(),
        textoBusqueda: textoBusqueda,
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
      _filtroTipoDocumento = 'todos';
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
    if (_tipoCarpetaFiltro != 'Todos') {
      list = list.where((c) => c.tipo == _tipoCarpetaFiltro).toList();
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

    // Filtro texto
    if (_consultaBusqueda.trim().isNotEmpty) {
      final query = _consultaBusqueda.toLowerCase().trim();
      filtrados = filtrados.where((doc) {
        return doc.codigo.toLowerCase().contains(query) ||
            doc.numeroCorrelativo.toLowerCase().contains(query) ||
            (doc.tipoDocumentoNombre ?? '').toLowerCase().contains(query) ||
            (doc.descripcion ?? '').toLowerCase().contains(query);
      }).toList();
    }
    
    // Filtro estado
    if (_filtroSeleccionado != 'todos') {
      filtrados =
          filtrados
              .where((doc) => doc.estado.toLowerCase() == _filtroSeleccionado)
              .toList();
    }

    // Filtro tipo doc
    if (_filtroTipoDocumento != 'todos') {
      filtrados =
          filtrados
              .where(
                (doc) => (doc.tipoDocumentoNombre ?? '')
                    .toLowerCase()
                    .contains(_filtroTipoDocumento),
              )
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

  bool _sinPermisoAlertaMostrada = false;

  /// Pantalla que se muestra cuando el usuario no tiene permiso ver_documento.
  Widget _buildSinPermisoAcceso(BuildContext context) {
    final theme = Theme.of(context);
    if (!_sinPermisoAlertaMostrada) {
      _sinPermisoAlertaMostrada = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppAlert.warning(
            context,
            'Sin permisos',
            'No tienes permisos para acceder a esta pantalla.',
            buttonText: 'Entendido',
          );
        }
      });
    }
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_rounded, size: 80, color: Colors.orange.shade700),
              ),
              const SizedBox(height: 32),
              Text(
                'No tienes permisos para acceder a esta pantalla',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 12),
              Text(
                'El permiso "Ver documento" está desactivado para tu usuario. Contacta al administrador si necesitas acceso.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 15, color: theme.colorScheme.onSurfaceVariant, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authProvider = Provider.of<AuthProvider>(context);
    if (!authProvider.hasPermission('ver_documento')) {
      return _buildSinPermisoAcceso(context);
    }
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.hasPermission('subir_documento')) {
      AppAlert.warning(context, 'Sin permisos', 'No tienes permisos para agregar documentos.', buttonText: 'Entendido');
      return;
    }
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
      print('DEBUG: Documento creado exitosamente, actualizando lista');
      final subcarpetaId = carpeta.id;

      // Limpiar filtros para que el documento recién creado aparezca en la lista
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
      });

      await _cargarDocumentosCarpeta(subcarpetaId);
      if (!mounted) return;
      await _cargarCarpetas(todasLasGestiones: true);
      if (!mounted) return;
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.refresh();
      if (mounted) setState(() {});
      // Forzar otro rebuild en el siguiente frame para que la lista se pinte con los nuevos datos
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final puedeAgregarCarpeta = authProvider.hasPermission('subir_documento');

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
        ],
      ),
    );

    final tabsTipo = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabChip('Todos', 'Todos'),
            const SizedBox(width: 8),
            _buildTabChip('Comprobante de Ingreso', 'Ingresos'),
            const SizedBox(width: 8),
            _buildTabChip('Comprobante de Egreso', 'Egresos'),
          ],
        ),
      ),
    );

    return RefreshIndicator(
      onRefresh: () async => await _cargarCarpetas(todasLasGestiones: true),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(child: headerCarpetas),
          SliverToBoxAdapter(child: tabsTipo),
          if (_carpetas.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.folder_open_outlined,
                title: 'No hay carpetas',
                subtitle: puedeAgregarCarpeta
                    ? 'Cree la primera con el botón flotante de abajo (rango y fecha).'
                    : 'No tiene permiso para crear carpetas.',
                action: null,
              ),
            )
          else if (carpetas.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.filter_list_off_rounded,
                title: 'Sin coincidencias',
                subtitle: 'No se encontraron carpetas con los filtros aplicados.',
                action: null,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 360,
                  childAspectRatio: 0.78,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final c = carpetas[index];
                    return CarpetaCard(
                      carpeta: c,
                      theme: theme,
                      onOpen: _abrirCarpeta,
                      onEdit: _abrirEditarCarpeta,
                      onDelete: _confirmarEliminarCarpeta,
                    );
                  },
                  childCount: carpetas.length,
                ),
              ),
            ),
          
          // Documentos encontrados con búsqueda (si aplica)
          if (_consultaBusqueda.isNotEmpty && _consultaBusqueda.length >= 3)
            _construirSliverBusquedaDocumentos(theme),
        ],
      ),
    );
  }

  Widget _buildTabChip(String value, String label) {
    final isSelected = _tipoCarpetaFiltro == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _tipoCarpetaFiltro = value);
      },
      selectedColor: Colors.blue.shade100,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade800 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _construirSliverBusquedaDocumentos(ThemeData theme) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Icon(Icons.manage_search_rounded, color: Colors.green.shade700, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Documentos que coinciden',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        if (_estaCargandoBusquedaDocumentos)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (_documentosBusquedaCarpetas.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('Ningún documento coincide con la búsqueda')),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DocumentoCard(
                      doc: _documentosBusquedaCarpetas[index],
                      theme: theme,
                      index: index,
                      onDetail: _navegarAlDetalle,
                      onEdit: _abrirEditarDocumento,
                      onDelete: _confirmarEliminarDocumento,
                    ),
                  );
                },
                childCount: _documentosBusquedaCarpetas.length,
              ),
            ),
          ),
      ],
    );
  }

  /// Abre el formulario de carpeta (solo rango y fecha).
  Future<void> _abrirAgregarCarpeta() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.hasPermission('subir_documento')) {
      AppAlert.warning(context, 'Sin permisos', 'No tienes permisos para agregar carpetas.', buttonText: 'Entendido');
      return;
    }
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



  Widget _construirVistaDocumentosCarpeta(ThemeData theme) {
    final carpeta = _carpetaSeleccionada!;
    final docs = _documentosCarpetaFiltrados;
    final width = MediaQuery.of(context).size.width;
    final mostrarPanelLateral = width >= 900;

    final contenidoPrincipal = CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 220.0,
          floating: false,
          pinned: true,
          elevation: 0,
          stretch: true,
          backgroundColor: theme.scaffoldBackgroundColor,
          surfaceTintColor: theme.scaffoldBackgroundColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 20),
            onPressed: () {
              if (_carpetaSeleccionada?.carpetaPadreId != null) {
                _navegarACarpetaPadre(_carpetaSeleccionada!.carpetaPadreId!);
              } else {
                setState(() => _carpetaSeleccionada = null);
              }
            },
          ),
          title: BreadcrumbHeader(
            currentName: carpeta.nombre,
            parentName: carpeta.carpetaPadreNombre,
            onParentTap: () {
              if (carpeta.carpetaPadreId != null) {
                _navegarACarpetaPadre(carpeta.carpetaPadreId!);
              }
            },
            onRootTap: () => setState(() => _carpetaSeleccionada = null),
          ),
          centerTitle: false,
          actions: [
            if (!mostrarPanelLateral)
              IconButton(
                icon: Icon(Icons.menu_open_rounded, color: theme.colorScheme.onSurface),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [StretchMode.blurBackground, StretchMode.zoomBackground],
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.05),
                    theme.scaffoldBackgroundColor,
                  ],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                   // Decoración sutil de fondo
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Icon(
                      Icons.folder_copy_rounded,
                      size: 200,
                      color: (carpeta.carpetaPadreId == null ? Colors.amber : Colors.blue).withOpacity(0.03),
                    ),
                  ),
                  Positioned(
                    bottom: 30,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Hero(
                              tag: 'folder_icon_${carpeta.id}',
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: carpeta.carpetaPadreId == null
                                        ? [Colors.amber.shade400, Colors.orange.shade600]
                                        : [Colors.blue.shade400, Colors.blue.shade700],
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (carpeta.carpetaPadreId == null ? Colors.orange : Colors.blue).withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  carpeta.carpetaPadreId == null
                                      ? Icons.folder_rounded
                                      : Icons.folder_shared_rounded,
                                  size: 36,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    carpeta.nombre,
                                    style: GoogleFonts.poppins(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                      height: 1.1,
                                      letterSpacing: -0.5,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (carpeta.descripcion != null && carpeta.descripcion!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      carpeta.descripcion!,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                        fontWeight: FontWeight.w400,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        _buildHeaderStats(carpeta, docs, theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _SliverAppBarDelegate(
            minHeight: 80,
            maxHeight: 80,
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor.withOpacity(0.95),
                border: Border(
                  bottom: BorderSide(color: theme.dividerColor.withOpacity(0.05)),
                ),
              ),
              child: _buildViewControls(theme),
            ),
          ),
        ),
        if (_estaCargandoDocumentosCarpeta)
          SliverFillRemaining(
            child: _buildDocumentosLoading(),
          )
        else if (docs.isEmpty)
           SliverPadding(
             padding: const EdgeInsets.only(top: 40),
             sliver: SliverFillRemaining(
               hasScrollBody: false,
               child: _buildDocumentosEmpty(),
             ),
           )
        else
          _vistaGrid
              ? _construirSliverGrid(docs, theme)
              : _construirSliverList(docs, theme),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
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




  Widget _buildHeaderStats(Carpeta carpeta, List<Documento> docs, ThemeData theme) {
    final rango = _estaCargandoDocumentosCarpeta ? '...' : _calcularRangoCorrelativos(docs);
    return Row(
      children: [
        _buildStatChip(
          icon: Icons.calendar_today_rounded,
          label: 'Gestión ${carpeta.gestion}',
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 10),
        if (rango != 'Sin correlativos' && rango != '...')
          _buildStatChip(
            icon: Icons.tag_rounded,
            label: rango,
            color: Colors.orange.shade700,
            backgroundColor: Colors.orange.shade50,
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${docs.length} documentos',
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
    Color? backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Panel lateral de carpetas (lista). Agregar carpeta solo con el FAB de abajo.
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
          ? (_consultaBusqueda.trim().isNotEmpty
              ? _documentosBusquedaCarpetas.length
              : _documentosFiltrados.length)
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
      padding: EdgeInsets.symmetric(
        horizontal: pad,
        vertical: pad * 0.8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: iconSize * 0.9),
          ),
          SizedBox(width: compact ? 8 : 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: valueSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: labelSize,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
                return SubcarpetaCard(
                  subcarpeta: sub,
                  theme: theme,
                  onOpen: _abrirCarpeta,
                  onDelete: _confirmarEliminarCarpeta,
                );
              },
            ),
          ),
        ],
      ),
    );
  }







  Widget _buildViewControls(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            'Vista',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildViewToggleItem(
                  icon: Icons.grid_view_rounded,
                  selected: _vistaGrid,
                  onTap: () => setState(() => _vistaGrid = true),
                  theme: theme,
                ),
                _buildViewToggleItem(
                  icon: Icons.list_rounded,
                  selected: !_vistaGrid,
                  onTap: () => setState(() => _vistaGrid = false),
                  theme: theme,
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton.filledTonal(
            onPressed: () => _abrirBusquedaAvanzada(theme),
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: 'Filtros avanzados',
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleItem({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.4),
        ),
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

  Widget _construirSliverGrid(
    List<Documento> docs,
    ThemeData theme,
  ) {
    final compact = _carpetaSeleccionada?.carpetaPadreId != null;
    final paddingH = compact ? 12.0 : 16.0;
    final spacing = compact ? 12.0 : 16.0;
    
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(paddingH, 16, paddingH, 80),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: compact ? 380 : 300,
          childAspectRatio: 0.8,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => DocumentoCard(
            doc: docs[index],
            theme: theme,
            index: index,
            onDetail: _navegarAlDetalle,
            onEdit: _abrirEditarDocumento,
            onDelete: _confirmarEliminarDocumento,
          ),
          childCount: docs.length,
        ),
      ),
    );
  }

  Widget _construirSliverList(List<Documento> docs, ThemeData theme) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final d = docs[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 300 + (index * 50)),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final clampedValue = value.clamp(0.0, 1.0); // Ensure valid range
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
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          childCount: docs.length,
        ),
      ),
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
          (ctx) => DialogFiltroCarpetas(
            gestionActual: _gestionFilterCarpetas,
            gestiones: _gestionesCarpetasDisponibles,
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
              child: FiltrosAvanzadosSheet(
                theme: theme,
                numeroComprobanteController: _numeroComprobanteFilterController,
                fechaDesde: _fechaDesdeFilter,
                fechaHasta: _fechaHastaFilter,
                responsableId: _responsableIdFilter,
                codigoQrController: _codigoQrFilterController,
                onAplicar: (numeroComprobante, fechaDesde, fechaHasta, responsableId, codigoQr) async {
                  setState(() {
                    _numeroComprobanteFilter = numeroComprobante;
                    _fechaDesdeFilter = fechaDesde;
                    _fechaHastaFilter = fechaHasta;
                    _responsableIdFilter = responsableId;
                    _codigoQrFilter = codigoQr;
                  });
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted && _carpetaSeleccionada != null) {
                    await _cargarDocumentosCarpeta(_carpetaSeleccionada!.id);
                    if (context.mounted) setState(() {});
                  }
                },
                onLimpiar: () async {
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
                    await _cargarDocumentosCarpeta(_carpetaSeleccionada!.id);
                    if (context.mounted) setState(() {});
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
            (context, index) => DocumentoCard(
              doc: filtrados[index],
              theme: theme,
              index: index,
              onDetail: _navegarAlDetalle,
              onEdit: _abrirEditarDocumento,
              onDelete: _confirmarEliminarDocumento,
            ),
      ),
    );
  }



  Future<void> _abrirEditarDocumento(Documento doc) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.hasPermission('editar_metadatos')) {
      AppAlert.warning(context, 'Sin permisos', 'No tienes permisos para editar documentos.', buttonText: 'Entendido');
      return;
    }
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentoFormScreen(documento: doc),
      ),
    );
    if (updated == true && mounted) {
      if (_carpetaSeleccionada != null) {
        await _cargarDocumentosCarpeta(_carpetaSeleccionada!.id);
      }
      setState(() {});
    }
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
              _estadoParaMostrar(doc.estado).toUpperCase(),
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

  /// Texto de estado para mostrar en la UI: Disponible (Activo) o Prestado.
  String _estadoParaMostrar(String estado) {
    switch (estado.toLowerCase()) {
      case 'activo':
        return 'Disponible';
      case 'prestado':
        return 'Prestado';
      case 'archivado':
        return 'Archivado';
      default:
        return estado;
    }
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

  Widget _buildEstadoBadge(String estado) {
    final color = _obtenerColorEstado(estado);
    final texto = _estadoParaMostrar(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        texto.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  void _navegarAlDetalle(Documento doc) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentoDetailScreen(documento: doc),
      ),
    );

    // Si se editó o eliminó el documento desde el detalle, recargar la lista
    if (result == true && mounted) {
      await cargarDocumentos();
      if (!mounted) return;
      if (_carpetaSeleccionada != null) {
        await _cargarDocumentosCarpeta(_carpetaSeleccionada!.id);
      }
      if (mounted) setState(() {});
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.hasPermission('borrar_documento')) {
      AppAlert.warning(context, 'Sin permisos', 'No tienes permisos para eliminar documentos.', buttonText: 'Entendido');
      return;
    }
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

  Future<void> _abrirEditarCarpeta(Carpeta carpeta) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.hasPermission('editar_metadatos')) {
      AppAlert.warning(context, 'Sin permisos', 'No tienes permisos para editar carpetas.', buttonText: 'Entendido');
      return;
    }
    final nombreController = TextEditingController(text: carpeta.nombre);
    final descripcionController = TextEditingController(text: carpeta.descripcion ?? '');

    final guardado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar carpeta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (guardado != true || !mounted) return;

    final nombre = nombreController.text.trim();
    if (nombre.isEmpty) {
      _mostrarSnackBarError('El nombre de la carpeta es obligatorio.');
      return;
    }

    try {
      final carpetaService = Provider.of<CarpetaService>(context, listen: false);
      await carpetaService.update(
        carpeta.id,
        UpdateCarpetaDTO(
          nombre: nombre,
          descripcion: descripcionController.text.trim().isEmpty ? null : descripcionController.text.trim(),
        ),
      );
      if (mounted) {
        _mostrarSnackBarExito('Carpeta actualizada correctamente.');
        await _cargarCarpetas(todasLasGestiones: true);
        if (_carpetaSeleccionada?.id == carpeta.id) {
          final actualizada = await carpetaService.getById(carpeta.id);
          setState(() => _carpetaSeleccionada = actualizada);
        }
      }
    } catch (e) {
      if (mounted) _mostrarSnackBarError(ErrorHelper.getErrorMessage(e));
    }
  }

  Future<void> _confirmarEliminarCarpeta(Carpeta carpeta) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.hasPermission('borrar_documento')) {
      AppAlert.warning(context, 'Sin permisos', 'No tienes permisos para eliminar carpetas.', buttonText: 'Entendido');
      return;
    }
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



  bool _canCreateDocument() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.hasPermission('subir_documento');
  }

  Widget? _buildFloatingActionButton() {
    final authProvider = Provider.of<AuthProvider>(context);
    final width = MediaQuery.of(context).size.width;
    final useCompactFab = width < 400;

    // Vista carpetas (no estamos dentro de una carpeta): solo "Nueva carpeta"
    if (_carpetaSeleccionada == null) {
      if (useCompactFab) {
        return FloatingActionButton(
          onPressed: () => _abrirAgregarCarpeta(),
          tooltip: 'Nueva carpeta',
          backgroundColor: Colors.blue.shade700,
          heroTag: 'fab_carpeta',
          child: const Icon(Icons.create_new_folder),
        );
      }
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
    if (useCompactFab) {
      return FloatingActionButton(
        onPressed: () => _agregarDocumento(_carpetaSeleccionada!),
        tooltip: 'Nuevo Documento',
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        heroTag: 'fab_documento',
        child: const Icon(Icons.add),
      );
    }
    return FloatingActionButton.extended(
      onPressed: () => _agregarDocumento(_carpetaSeleccionada!),
      icon: const Icon(Icons.add),
      label: const Text('Nuevo Documento'),
      backgroundColor: Colors.green.shade700,
      foregroundColor: Colors.white,
      heroTag: 'fab_documento',
    );
  }
}



/// Bottom sheet para búsqueda avanzada: número comprobante, fecha, responsable, código QR.


class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
