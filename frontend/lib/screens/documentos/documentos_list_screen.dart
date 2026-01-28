import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/carpeta.dart';
import '../../models/documento.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/carpeta_service.dart';
import '../../services/documento_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helper.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_shimmer.dart';
import 'carpeta_form_screen.dart';
import 'carpetas_screen.dart';
import 'documento_detail_screen.dart';
import 'documento_form_screen.dart';

class DocumentosListScreen extends StatefulWidget {
  const DocumentosListScreen({super.key});

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
  String _vistaSeleccionada = 'carpetas';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    cargarDocumentos();
    _cargarCarpetas();
    _searchController.addListener(_alCambiarBusqueda);
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _cargarCarpetas() async {
    setState(() => _estaCargandoCarpetas = true);
    try {
      final carpetaService = Provider.of<CarpetaService>(
        context,
        listen: false,
      );
      final gestion = DateTime.now().year.toString();
      final carpetas = await carpetaService.getAll(gestion: gestion);
      setState(() {
        _carpetas = carpetas;
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
      final documentos = await service.buscar(
        BusquedaDocumentoDTO(
          carpetaId: carpetaId,
          page: 1,
          pageSize: 50,
          orderBy: 'fechaDocumento',
          orderDirection: 'DESC',
        ),
      );
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
      final subcarpetas = await service.getAll(
        gestion: DateTime.now().year.toString(),
      );
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

  Future<void> _abrirCarpeta(Carpeta carpeta) async {
    setState(() {
      _carpetaSeleccionada = carpeta;
      _documentosCarpeta = [];
      _subcarpetas = [];
    });
    // Cargar documentos y subcarpetas en paralelo
    await Future.wait([
      _cargarDocumentosCarpeta(carpeta.id),
      _cargarSubcarpetas(carpeta.id),
    ]);
  }

  List<Documento> get _documentosFiltrados {
    var filtrados = _documentos;

    if (_consultaBusqueda.isNotEmpty) {
      filtrados =
          filtrados.where((doc) {
            final query = _consultaBusqueda.toLowerCase();
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final authProvider = Provider.of<AuthProvider>(context);
    final canCreate = authProvider.role != UserRole.gerente;

    int crossAxisCount = 1;
    if (size.width > 1200) {
      crossAxisCount = 3;
    } else if (size.width > 800) {
      crossAxisCount = 2;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _construirFiltrosSuperior(theme, canCreate),
          Expanded(
            child:
                _carpetaSeleccionada != null
                    ? _construirVistaDocumentosCarpeta(theme)
                    : _construirVistaCarpetas(theme),
          ),
        ],
      ),
    );
  }

  Widget _construirVistaCarpetas(ThemeData theme) {
    if (_estaCargandoCarpetas) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_carpetas.isEmpty) {
      return EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'No hay carpetas',
        subtitle: 'Cree su primera carpeta para comenzar',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        childAspectRatio: 1.2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: _carpetas.length,
      itemBuilder: (context, index) {
        final c = _carpetas[index];
        return _buildCarpetaCard(c, theme);
      },
    );
  }

  Widget _buildCarpetaCard(Carpeta carpeta, ThemeData theme) {
    final gestionLine =
        carpeta.gestion.isNotEmpty ? 'Gestion ${carpeta.gestion}' : null;
    final nroLine =
        carpeta.numeroCarpeta != null ? 'Nro ${carpeta.numeroCarpeta}' : null;
    final romano =
        (carpeta.codigoRomano ?? '').isNotEmpty
            ? carpeta.codigoRomano
            : carpeta.codigo;
    final romanoLine = (romano ?? '').isNotEmpty ? 'Romano $romano' : null;
    final rangoLine =
        (carpeta.rangoInicio != null && carpeta.rangoFin != null)
            ? 'Rango: ${carpeta.rangoInicio} - ${carpeta.rangoFin}'
            : 'Rango: sin documentos';
    return InkWell(
      onTap: () => _abrirCarpeta(carpeta),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade300, Colors.orange.shade400],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.folder_rounded, color: Colors.white),
            ),
            const Spacer(),
            Text(
              carpeta.nombre,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (gestionLine != null)
              Text(
                gestionLine,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            if (nroLine != null)
              Text(
                nroLine,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            if (romanoLine != null)
              Text(
                romanoLine,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            Text(
              rangoLine,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            Text(
              'Doc: ${carpeta.numeroDocumentos}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirVistaDocumentosCarpeta(ThemeData theme) {
    final carpeta = _carpetaSeleccionada!;
    final docs = _documentosCarpeta;
    final rango =
        _estaCargandoDocumentosCarpeta
            ? 'Cargando...'
            : _calcularRangoCorrelativos(docs);
    final romano =
        (carpeta.codigoRomano ?? '').isNotEmpty
            ? carpeta.codigoRomano
            : carpeta.codigo;
    final gestionLine =
        carpeta.gestion.isNotEmpty ? 'Gestion ${carpeta.gestion}' : null;
    final nroLine =
        carpeta.numeroCarpeta != null ? 'Nro ${carpeta.numeroCarpeta}' : null;
    final romanoLine = (romano ?? '').isNotEmpty ? 'Romano $romano' : null;
    final rangoLine = rango.isNotEmpty ? 'Rango: $rango' : null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _carpetaSeleccionada = null),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade400, Colors.blue.shade700],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      carpeta.nombre,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (gestionLine != null)
                      Text(
                        gestionLine,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
              ),
              // Acción: Nueva Carpeta (subcarpeta) siempre
              ElevatedButton.icon(
                onPressed: () => _crearSubcarpeta(carpeta.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text('Nueva Carpeta'),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),

        // Vista de Subcarpetas (si existen)
        if (_estaCargandoSubcarpetas)
          const LinearProgressIndicator(minHeight: 2)
        else if (_subcarpetas.isNotEmpty)
          Container(
            height: 140, // Altura fija para scroll horizontal horizontal
            margin: const EdgeInsets.only(bottom: 12),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _subcarpetas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final sub = _subcarpetas[index];
                return _buildSubcarpetaCard(sub, theme);
              },
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _vistaGrid = true),
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                    label: const Text('Cuadricula'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _vistaGrid
                              ? Colors.blue.shade600
                              : Colors.blue.shade50,
                      foregroundColor:
                          _vistaGrid ? Colors.white : Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _vistaGrid = false),
                    icon: const Icon(Icons.list_rounded, size: 18),
                    label: const Text('Lista'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          !_vistaGrid
                              ? Colors.blue.shade600
                              : Colors.blue.shade50,
                      foregroundColor:
                          !_vistaGrid ? Colors.white : Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child:
              _estaCargandoDocumentosCarpeta
                  ? const Center(child: CircularProgressIndicator())
                  : docs.isEmpty
                  ? EmptyState(
                    icon: Icons.description_outlined,
                    title: 'Sin documentos',
                    subtitle: 'Agregue el primer documento a esta carpeta',
                  )
                  : _vistaGrid
                  ? _construirGridDocumentosCarpeta(docs, theme)
                  : _construirListaDocumentos(docs, theme),
        ),
      ],
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
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        childAspectRatio: 1.6,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
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
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final d = docs[index];
        return InkWell(
          onTap: () => _navegarAlDetalle(d),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: Colors.blue,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.codigo,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        d.descripcion ?? 'Sin descripcion',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Nº ${d.numeroCorrelativo}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _construirFiltrosSuperior(ThemeData theme, bool canCreate) {
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

  Widget _buildFilterButton(ThemeData theme) {
    return Container(
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconButton(
        icon: Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
        onPressed: () {},
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
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navegarAlDetalle(doc),
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: const Icon(
                          Icons.description_rounded,
                          color: Colors.blue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _buildCardHeader(doc, theme)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    doc.codigo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doc.descripcion ?? 'Sin descripci??n',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const Spacer(),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  _buildCardFooter(doc, theme),
                ],
              ),
            ),
          ),
        ),
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
      cargarDocumentos();
      if (_carpetaSeleccionada != null) {
        _cargarDocumentosCarpeta(_carpetaSeleccionada!.id);
      }
    } catch (e) {
      if (!mounted) return;

      _mostrarSnackBarError(
        'Error al eliminar: ${ErrorHelper.getErrorMessage(e)}',
      );
    }
  }

  Future<void> _abrirNuevoDocumento() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DocumentoFormScreen()),
    );
    if (result == true) {
      cargarDocumentos();
      _cargarCarpetas();
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

  Future<void> _abrirNuevaCarpeta() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CarpetasScreen()),
    );
    // Puedes llamar a cargarDocumentos() si las carpetas afectan la lista visible
    cargarDocumentos();
    _cargarCarpetas();
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

  Future<void> _crearSubcarpeta(int padreId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarpetaFormScreen(padreId: padreId),
      ),
    );
    if (result == true) {
      _cargarSubcarpetas(padreId);
      _cargarCarpetas();
    }
  }

  Widget _buildSubcarpetaCard(Carpeta sub, ThemeData theme) {
    return InkWell(
      onTap: () => _abrirCarpeta(sub),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.folder_shared_rounded,
              color: Colors.blue,
              size: 32,
            ),
            const Spacer(),
            Text(
              sub.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade900,
              ),
            ),
            if (sub.rangoInicio != null && sub.rangoFin != null)
              Text(
                'Rango ${sub.rangoInicio} - ${sub.rangoFin}',
                style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
              ),
          ],
        ),
      ),
    );
  }

  bool _canCreateDocument() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.role != UserRole.gerente;
  }
}
