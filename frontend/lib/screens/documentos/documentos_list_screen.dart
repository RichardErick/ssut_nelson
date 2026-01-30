import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/carpeta.dart';
import '../../models/documento.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/carpeta_service.dart';
import '../../services/documento_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helper.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_shimmer.dart';
import 'subcarpeta_form_screen.dart';
import 'carpeta_form_screen.dart';
import 'carpetas_screen.dart';
import 'documento_detail_screen.dart';
import 'documento_form_screen.dart';

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
  // Removed _vistaSeleccionada as it seems unused/confusing in this refactor
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.initialCarpetaId != null) {
      // Si venimos con un ID, cargamos directamente esa carpeta y sus cosas
      _cargarCarpetaInicial(widget.initialCarpetaId!);
    } else {
      cargarDocumentos();
      _cargarCarpetas();
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
         
         if(mounted) {
             // Set state directly
             _carpetaSeleccionada = carpeta;
             _estaCargandoCarpetas = false;
             // Load content
             await _abrirCarpeta(carpeta);
         }
      } catch(e) {
          print('Error cargando carpeta inicial $id: $e');
          if(mounted) _mostrarSnackBarError('No se pudo cargar la carpeta solicitada');
      } finally {
        if(mounted) {
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
      final todasLasCarpetas = await carpetaService.getAll();
      setState(() {
        // SOLO mostrar las carpetas raíz (las que no tienen padre)
        _carpetas = todasLasCarpetas.where((c) => c.carpetaPadreId == null).toList();
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
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentoFormScreen(initialCarpetaId: carpeta.id),
        ),
      );
      if (result == true) {
        await _cargarDocumentosCarpeta(carpeta.id);
        
        // Notificar al DataProvider
        if (mounted) {
          final dataProvider = Provider.of<DataProvider>(context, listen: false);
          dataProvider.refresh();
        }
      }
  }

  Future<void> _crearSubcarpeta(int padreId) async {
    // Obtener información de la carpeta padre
    final carpetaService = Provider.of<CarpetaService>(context, listen: false);
    final carpetaPadre = await carpetaService.getById(padreId);
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubcarpetaFormScreen(
          carpetaPadreId: padreId,
          carpetaPadreNombre: carpetaPadre.nombre,
        ),
      ),
    );
    
    if (result == true && mounted) {
      // Reload subcarpetas
      await _cargarSubcarpetas(padreId);
      
      // Notificar al DataProvider
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.refresh();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subcarpeta creada exitosamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canDelete = authProvider.hasPermission('borrar_documento');

    final gestionLine = carpeta.gestion.isNotEmpty ? carpeta.gestion : 'N/A';
    final nroLine = carpeta.numeroCarpeta?.toString() ?? 'N/A';
    final romanoLine = (carpeta.codigoRomano?.isNotEmpty == true) 
        ? carpeta.codigoRomano! 
        : ((carpeta.codigo?.isNotEmpty == true) ? carpeta.codigo! : 'N/A');
    final rangoLine = (carpeta.rangoInicio != null && carpeta.rangoFin != null)
        ? '${carpeta.rangoInicio} - ${carpeta.rangoFin}'
        : 'Sin rango';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header con icono y botón de borrar
                  Row(
                    children: [
                      Hero(
                        tag: 'folder_${carpeta.id}',
                        child: Container(
                          padding: const EdgeInsets.all(14),
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
                            size: 28,
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
                  
                  const SizedBox(height: 16),
                  
                  // Nombre de la carpeta
                  Text(
                    carpeta.nombre,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Información en chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildInfoChip('Gestión', gestionLine, Colors.blue),
                      _buildInfoChip('Nº', nroLine, Colors.green),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildInfoChip('Romano', romanoLine, Colors.purple),
                      _buildInfoChip('Rango', rangoLine, Colors.orange),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Footer con estadísticas
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          color: Colors.blue.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${carpeta.numeroDocumentos} documentos',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const Spacer(),
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
    final docs = _documentosCarpeta;
    final rango = _estaCargandoDocumentosCarpeta
        ? 'Cargando...'
        : _calcularRangoCorrelativos(docs);

    return Column(
      children: [
        // Header mejorado de la carpeta
        _buildCarpetaHeader(carpeta, rango, theme),
        
        // Vista de Subcarpetas mejorada
        if (_estaCargandoSubcarpetas)
          Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: LinearProgressIndicator(
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
          )
        else if (_subcarpetas.isNotEmpty)
          _buildSubcarpetasSection(theme),

        // Controles de vista
        _buildViewControls(theme),

        // Lista/Grid de documentos
        Expanded(
          child: _estaCargandoDocumentosCarpeta
              ? _buildDocumentosLoading()
              : docs.isEmpty
                  ? _buildDocumentosEmpty()
                  : _vistaGrid
                      ? _construirGridDocumentosCarpeta(docs, theme)
                      : _construirListaDocumentos(docs, theme),
        ),
      ],
    );
  }

  Widget _buildCarpetaHeader(Carpeta carpeta, String rango, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.indigo.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Botón de regreso
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
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
                      setState(() => _carpetaSeleccionada = null);
                    }
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Colors.blue.shade700,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Icono de la carpeta
              Hero(
                tag: 'folder_icon_${carpeta.id}',
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade800],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.folder_open_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Información de la carpeta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      carpeta.nombre,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rango,
                        style: GoogleFonts.inter(
                          fontSize: 12,
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
          
          // Estadísticas de la carpeta
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildCarpetaStat(
                  'Subcarpetas',
                  '${_subcarpetas.length}',
                  Icons.folder_copy,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCarpetaStat(
                  'Documentos',
                  '${_documentosCarpeta.length}',
                  Icons.description,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCarpetaStat(
                  'Gestión',
                  carpeta.gestion,
                  Icons.calendar_today,
                  Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarpetaStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcarpetasSection(ThemeData theme) {
    return Container(
      height: 160,
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(Icons.folder_copy, color: Colors.orange.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Subcarpetas',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_subcarpetas.length} carpetas',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
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

    return Container(
      width: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.orange.shade50,
          ],
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con icono y botón de borrar
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade400, Colors.orange.shade600],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.folder_shared_rounded,
                        color: Colors.white,
                        size: 22,
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
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.delete_outline,
                                color: Colors.red.shade600,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Nombre de la subcarpeta
                Text(
                  sub.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                    height: 1.2,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Información del rango
                if (sub.rangoInicio != null && sub.rangoFin != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      'Rango ${sub.rangoInicio}-${sub.rangoFin}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                
                const Spacer(),
                
                // Footer con estadísticas
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description, size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 6),
                      Text(
                        '${sub.numeroDocumentos} docs',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
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
    );
  }

  Widget _buildViewControls(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
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
                            gradient: _vistaGrid
                                ? LinearGradient(
                                    colors: [Colors.blue.shade600, Colors.blue.shade700],
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
                                color: _vistaGrid ? Colors.white : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Cuadrícula',
                                style: GoogleFonts.poppins(
                                  color: _vistaGrid ? Colors.white : Colors.grey.shade600,
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
                            gradient: !_vistaGrid
                                ? LinearGradient(
                                    colors: [Colors.blue.shade600, Colors.blue.shade700],
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
                                color: !_vistaGrid ? Colors.white : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Lista',
                                style: GoogleFonts.poppins(
                                  color: !_vistaGrid ? Colors.white : Colors.grey.shade600,
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
                Icons.description_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Sin documentos',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agregue el primer documento a esta carpeta',
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
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final d = docs[index];
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
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
                            colors: [Colors.blue.shade400, Colors.blue.shade600],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _obtenerIconoTipoDocumento(d.tipoDocumentoNombre ?? ''),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                            colors: [Colors.blue.shade400, Colors.blue.shade600],
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
                          _obtenerIconoTipoDocumento(doc.tipoDocumentoNombre ?? ''),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
        icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 18),
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
      MaterialPageRoute(builder: (context) => const CarpetaFormScreen()),
    );
    
    // Si se creó una carpeta exitosamente, actualizar la vista
    if (result == true && mounted) {
      await _cargarCarpetas();
      
      // Notificar al DataProvider para actualizaciones en tiempo real
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.refresh();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Carpeta creada exitosamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
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
      // Siempre usamos hard delete para carpetas por ahora según requerimiento de UX
      await carpetaService.delete(carpeta.id, hard: true);
      
      if (!mounted) return;
      
      // Notificar al DataProvider
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.notifyCarpetaDeleted(carpeta.id);
      
      // Actualizar listas
      if (carpeta.carpetaPadreId != null) {
          await _cargarSubcarpetas(carpeta.carpetaPadreId!);
      } else {
          setState(() {
              _carpetaSeleccionada = null; // Regresar si estábamos viendo esta carpeta
          });
      }
      await _cargarCarpetas();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carpeta eliminada correctamente'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      _mostrarSnackBarError('No se pudo eliminar: ${ErrorHelper.getErrorMessage(e)}');
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

    // Nivel 1: Vista principal de carpetas padre - Solo crear carpeta
    if (_carpetaSeleccionada == null) {
      // Para crear carpetas principales, verificar si tiene permisos de subir documentos
      if (!authProvider.hasPermission('subir_documento')) return null;
      
      return FloatingActionButton.extended(
        onPressed: () => _abrirNuevaCarpeta(),
        icon: const Icon(Icons.create_new_folder_rounded),
        label: const Text('Nueva Carpeta'),
        backgroundColor: Colors.amber.shade800,
        heroTag: 'fab_carpeta',
      );
    }

    // Nivel 2: Dentro de carpeta padre (viendo subcarpetas) - Solo crear subcarpeta
    if (_carpetaSeleccionada!.carpetaPadreId == null) {
      // Para crear subcarpetas, verificar si tiene permisos de subir documentos
      if (!authProvider.hasPermission('subir_documento')) return null;
      
      return FloatingActionButton.extended(
        onPressed: () => _crearSubcarpeta(_carpetaSeleccionada!.id),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Nueva Subcarpeta'),
        backgroundColor: Colors.orange.shade700,
        heroTag: 'fab_subcarpeta',
      );
    }

    // Nivel 3: Dentro de subcarpeta - Solo crear documento
    if (!authProvider.hasPermission('subir_documento')) return null;
    
    return FloatingActionButton.extended(
      onPressed: () => _agregarDocumento(_carpetaSeleccionada!),
      icon: const Icon(Icons.add_circle_outline_rounded),
      label: const Text('Nuevo Documento'),
      backgroundColor: Colors.blue.shade700,
      heroTag: 'fab_documento',
    );
  }
}
