import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/documento.dart';
import '../../models/movimiento.dart';
import '../../services/movimiento_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helper.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/loading_shimmer.dart';

class DocumentoDetailScreen extends StatefulWidget {
  final Documento documento;

  const DocumentoDetailScreen({super.key, required this.documento});

  @override
  State<DocumentoDetailScreen> createState() => _DocumentoDetailScreenState();
}

class _DocumentoDetailScreenState extends State<DocumentoDetailScreen> {
  List<Movimiento> _movimientos = [];
  bool _isLoadingMovimientos = true;

  @override
  void initState() {
    super.initState();
    _loadMovimientos();
  }

  Future<void> _loadMovimientos() async {
    if (!mounted) return;
    setState(() => _isLoadingMovimientos = true);
    try {
      final service = Provider.of<MovimientoService>(context, listen: false);
      final movimientos = await service.getByDocumentoId(widget.documento.id);
      if (mounted) {
        setState(() {
          _movimientos = movimientos;
          _isLoadingMovimientos = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMovimientos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.documento;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: theme.colorScheme.surface.withOpacity(0.95),
      appBar: _buildAppBar(doc, theme),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child:
            isDesktop
                ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildLeftColumn(doc, dateFormat, theme),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 2,
                      child: _buildRightColumn(dateFormat, theme),
                    ),
                  ],
                )
                : Column(
                  children: [
                    _buildLeftColumn(doc, dateFormat, theme),
                    const SizedBox(height: 32),
                    _buildRightColumn(dateFormat, theme),
                  ],
                ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Documento doc, ThemeData theme) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      title: Text(
        'DETALLE DE DOCUMENTO',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_rounded),
          onPressed: () {},
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.share_rounded),
          onPressed: () {},
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildLeftColumn(
    Documento doc,
    DateFormat dateFormat,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMainInfoCard(doc, theme),
        const SizedBox(height: 32),
        _buildGeneralStats(doc, dateFormat, theme),
      ],
    );
  }

  Widget _buildMainInfoCard(Documento doc, ThemeData theme) {
    return AnimatedCard(
      delay: const Duration(milliseconds: 0),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.colorPrimario,
                        AppTheme.colorSecundario,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.codigo,
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        doc.tipoDocumentoNombre ?? 'TIPO NO DEFINIDO',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(doc.estado),
              ],
            ),
            const SizedBox(height: 40),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 3,
              children: [
                _buildMiniInfo(
                  'Correlativo',
                  doc.numeroCorrelativo,
                  Icons.tag_rounded,
                ),
                _buildMiniInfo(
                  'Área Origen',
                  doc.areaOrigenNombre ?? 'N/A',
                  Icons.location_on_rounded,
                ),
                _buildMiniInfo(
                  'Gestión',
                  doc.gestion,
                  Icons.calendar_today_rounded,
                ),
                _buildMiniInfo(
                  'Responsable',
                  doc.responsableNombre ?? 'No asignado',
                  Icons.person_rounded,
                ),
                _buildMiniInfo(
                  'Carpeta',
                  doc.carpetaNombre ?? 'Sin carpeta',
                  Icons.folder_shared_rounded,
                ),
                _buildMiniInfo(
                  'Ubicación Fís.',
                  doc.ubicacionFisica ?? 'No registrada',
                  Icons.shelves,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String estado) {
    final color = _getStatusColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        estado.toUpperCase(),
        style: GoogleFonts.inter(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGeneralStats(
    Documento doc,
    DateFormat dateFormat,
    ThemeData theme,
  ) {
    return AnimatedCard(
      delay: const Duration(milliseconds: 200),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DESCRIPCIÓN',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    doc.descripcion ?? 'Sin descripción adicional.',
                    style: GoogleFonts.inter(fontSize: 15, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          if (doc.codigoQR != null) _buildQRCode(doc.codigoQR!, theme),
        ],
      ),
    );
  }

  Widget _buildQRCode(String data, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          QrImageView(
            data: data,
            version: QrVersions.auto,
            size: 100.0,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppTheme.colorPrimario,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ESCANEAME',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightColumn(DateFormat dateFormat, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HISTORIAL DE MOVIMIENTOS',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _isLoadingMovimientos
            ? _buildMovShimmer()
            : _movimientos.isEmpty
            ? _buildEmptyMovs()
            : Column(
              children:
                  _movimientos
                      .map((m) => _buildMovItem(m, dateFormat, theme))
                      .toList(),
            ),
      ],
    );
  }

  Widget _buildMovShimmer() {
    return Column(
      children: List.generate(
        3,
        (i) => LoadingShimmer(
          width: double.infinity,
          height: 100,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildEmptyMovs() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('Sin movimientos'),
        ],
      ),
    );
  }

  Widget _buildMovItem(Movimiento mov, DateFormat dateFormat, ThemeData theme) {
    final isOut = mov.tipoMovimiento == 'Salida';
    final color = isOut ? Colors.red : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOut ? Icons.north_east_rounded : Icons.south_west_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mov.tipoMovimiento.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                Text(
                  mov.areaDestinoNombre ?? mov.areaOrigenNombre ?? 'Sin área',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                Text(
                  dateFormat.format(mov.fechaMovimiento),
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (mov.estado == 'Activo' && isOut)
            TextButton(
              onPressed: () => _handleReturn(mov.id),
              child: Text(
                'DEVOLVER',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleReturn(int movId) async {
    try {
      await Provider.of<MovimientoService>(
        context,
        listen: false,
      ).devolverDocumento(movId);
      _loadMovimientos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Documento devuelto exitosamente'),
            backgroundColor: AppTheme.colorExito,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ErrorHelper.getErrorMessage(e),
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.colorError,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Color _getStatusColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'activo':
        return AppTheme.colorExito;
      case 'prestado':
        return AppTheme.colorAdvertencia;
      case 'archivado':
        return AppTheme.colorInfo;
      default:
        return Colors.grey;
    }
  }
}
