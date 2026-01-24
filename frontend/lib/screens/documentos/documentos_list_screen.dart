import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/documento.dart';
import '../../services/documento_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helper.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_shimmer.dart';

import 'documento_detail_screen.dart';
import 'documento_form_screen.dart';
import 'carpetas_screen.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_role.dart';

class DocumentosListScreen extends StatefulWidget {
  const DocumentosListScreen({super.key});

  @override
  State<DocumentosListScreen> createState() => _DocumentosListScreenState();
}

class _DocumentosListScreenState extends State<DocumentosListScreen>
    with AutomaticKeepAliveClientMixin {
  List<Documento> _documentos = [];
  bool _estaCargando = true;
  String _consultaBusqueda = '';
  String _filtroSeleccionado = 'todos';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargarDocumentos();
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

  Future<void> _cargarDocumentos() async {
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
      floatingActionButton: Opacity(
        opacity: canCreate ? 1.0 : 0.5,
        child: FloatingActionButton.extended(
          onPressed: canCreate ? () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DocumentoFormScreen()),
            );
            if (result == true) _cargarDocumentos();
          } : null,
          label: const Text('Nuevo Documento'),
          icon: const Icon(Icons.add),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: canCreate ? 6 : 0,
        ),
      ),
      body: Column(
        children: [
          _construirFiltrosSuperior(theme),
          Expanded(
            child:
                _estaCargando
                    ? _construirShimmerCarga(crossAxisCount)
                    : _documentosFiltrados.isEmpty
                    ? EmptyState(
                      icon: Icons.folder_open_outlined,
                      title: 'No hay documentos',
                      subtitle:
                          _consultaBusqueda.isNotEmpty
                              ? 'No se encontraron resultados'
                              : 'Comience agregando su primer documento',
                    )
                    : _construirGridDocumentos(theme, crossAxisCount),
          ),
        ],
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
              // Botón Carpetas
               Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  icon: Icon(Icons.folder_shared_rounded, color: Colors.amber.shade800),
                  tooltip: 'Gestionar Carpetas',
                  onPressed: () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CarpetasScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterButton(theme),
            ],
          ),
          const SizedBox(height: 20),
          _construirChipsSelector(theme),
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
      onRefresh: _cargarDocumentos,
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
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navegarAlDetalle(doc),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardHeader(doc, theme),
                  const Spacer(),
                  Text(
                    doc.codigo,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doc.descripcion ?? 'Sin descripción',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const Spacer(),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            doc.estado.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
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
        Text(
          _formatearFecha(doc.fechaRegistro),
          style: GoogleFonts.inter(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
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

  void _navegarAlDetalle(Documento doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentoDetailScreen(documento: doc),
      ),
    );
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
}
