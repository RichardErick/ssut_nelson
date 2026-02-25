import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

import '../../models/documento.dart';
import '../../models/movimiento.dart';
import '../../services/reporte_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helper.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/app_alert.dart';

class ReportesScreen extends StatefulWidget {
  /// Índice de la pestaña actual en Home; si coincide con [reportesIndex] esta pantalla está visible.
  final int? selectedIndex;

  /// Índice de la pestaña Reportes en el menú; se usa para refrescar al volver a la pestaña.
  final int? reportesIndex;

  const ReportesScreen({super.key, this.selectedIndex, this.reportesIndex});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  Map<String, dynamic>? _estadisticas;
  bool _isLoading = true;

  /// Total de movimientos del mes actual (calculado por período, sin borrar datos).
  int _movimientosMesActual = 0;
  bool _isLoadingMovimientosMes = false;

  // Reporte de movimientos por período
  List<Movimiento> _reporteMovimientos = [];
  bool _isLoadingReporte = false;
  DateTime _fechaDesde = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _fechaHasta = DateTime.now();
  String? _tipoMovimientoFilter; // null = Todos

  // Reporte de documentos prestados
  List<Documento> _reportePrestados = [];
  bool _isLoadingReportePrestados = false;

  @override
  void initState() {
    super.initState();
    _loadEstadisticas();
    _loadMovimientosMesActual();
  }

  @override
  void didUpdateWidget(covariant ReportesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refrescar estadísticas al volver a esta pestaña (actualización en tiempo real)
    if (widget.reportesIndex != null &&
        widget.selectedIndex == widget.reportesIndex &&
        oldWidget.selectedIndex != widget.reportesIndex) {
      _loadEstadisticas();
      _loadMovimientosMesActual();
    }
  }

  Future<void> _loadEstadisticas({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final service = Provider.of<ReporteService>(context, listen: false);
      final stats = await service.obtenerEstadisticas();
      if (mounted) {
        setState(() {
          _estadisticas = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar estadísticas: $e'),
            backgroundColor: AppTheme.colorError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Calcula la cantidad de movimientos del mes actual usando el reporte por período,
  /// así el contador se "reinicia" automáticamente cada mes sin eliminar historial.
  Future<void> _loadMovimientosMesActual() async {
    setState(() => _isLoadingMovimientosMes = true);
    try {
      final now = DateTime.now();
      final desde = DateTime(now.year, now.month, 1);
      final hasta = now;

      final service = Provider.of<ReporteService>(context, listen: false);
      final list = await service.reporteMovimientos(
        fechaDesde: desde,
        fechaHasta: hasta,
      );

      if (mounted) {
        setState(() {
          _movimientosMesActual = list.length;
          _isLoadingMovimientosMes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMovimientosMes = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al calcular movimientos del mes: $e'),
            backgroundColor: AppTheme.colorError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body:
          _isLoading
              ? _buildLoadingState()
              : _estadisticas == null
              ? const Center(child: Text('No hay datos disponibles'))
              : RefreshIndicator(
                onRefresh: () => _loadEstadisticas(silent: true),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(theme),
                      const SizedBox(height: 40),
                      _buildStatGrid(isDesktop),
                      const SizedBox(height: 40),
                      _buildReporteMovimientosSection(theme),
                      const SizedBox(height: 40),
                      _buildReportePrestadosSection(theme),
                      const SizedBox(height: 40),
                      _buildDetailedReports(theme, isDesktop),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.colorPrimario),
          ),
          const SizedBox(height: 24),
          Text(
            'Analizando datos...',
            style: GoogleFonts.inter(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PANEL DE ESTADÍSTICAS',
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          'Resumen general del estado de la documentación',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildStatGrid(bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            _buildStatCard(
              'Total Documentos',
              '${_estadisticas!['totalDocumentos']}',
              Icons.description_rounded,
              AppTheme.colorPrimario,
              constraints.maxWidth,
              isDesktop,
            ),
            _buildStatCard(
              'Documentos Activos',
              '${_estadisticas!['documentosActivos']}',
              Icons.verified_rounded,
              AppTheme.colorExito,
              constraints.maxWidth,
              isDesktop,
            ),
            _buildStatCard(
              'En Préstamo',
              '${_estadisticas!['documentosPrestados']}',
              Icons.pending_actions_rounded,
              AppTheme.colorAdvertencia,
              constraints.maxWidth,
              isDesktop,
            ),
            _buildStatCard(
              'Movimientos Mes',
              // Se usa el valor calculado por período (mes actual),
              // no un contador acumulado.
              _isLoadingMovimientosMes ? '...' : '$_movimientosMesActual',
              Icons.auto_graph_rounded,
              Colors.purple,
              constraints.maxWidth,
              isDesktop,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    double maxWidth,
    bool isDesktop,
  ) {
    // Responsive width calculation
    double width;
    if (isDesktop) {
      // 4 items per row on desktop
      width = (maxWidth - (24 * 3)) / 4;
    } else if (maxWidth > 600) {
      // 2 items per row on tablet
      width = (maxWidth - 24) / 2;
    } else {
      // 1 item per row on mobile
      width = maxWidth;
    }

    return Container(
      width: width,
      child: AnimatedCard(
        delay: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 20),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: int.tryParse(value) ?? 0),
                duration: const Duration(milliseconds: 1500),
                builder:
                    (context, val, _) => Text(
                      val.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
              ),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedReports(ThemeData theme, bool isDesktop) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildDistributionList(
                'DISTRIBUCIÓN POR TIPO',
                _estadisticas!['documentosPorTipo'] as Map? ?? {},
                Icons.folder_open_rounded,
                theme,
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              child: _buildDistributionList(
                'DISTRIBUCIÓN POR ÁREA',
                _estadisticas!['documentosPorArea'] as Map? ?? {},
                Icons.business_center_rounded,
                theme,
              ),
            ),
          ],
        ),
        if (!isDesktop) ...[
          const SizedBox(height: 40),
          _buildExportSection(theme),
        ],
      ],
    );
  }

  Widget _buildDistributionList(
    String title,
    Map data,
    IconData icon,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.05),
            ),
          ),
          child:
              data.isEmpty
                  ? Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'Sin datos registrados',
                        style: GoogleFonts.inter(color: Colors.grey),
                      ),
                    ),
                  )
                  : Column(
                    children:
                        data.entries
                            .map(
                              (e) => _buildDistributionTile(
                                e.key.toString(),
                                e.value.toString(),
                                icon,
                                theme,
                              ),
                            )
                            .toList(),
                  ),
        ),
      ],
    );
  }

  Widget _buildDistributionTile(
    String name,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 20),
      ),
      title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      trailing: Text(
        value,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildReporteMovimientosSection(ThemeData theme) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REPORTE DE MOVIMIENTOS POR PERÍODO',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Filtre por fechas y tipo de movimiento; exporte a PDF.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 160,
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _fechaDesde,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _fechaDesde = picked);
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Desde',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                    ),
                  ),
                  child: Text(
                    dateFormat.format(_fechaDesde),
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 160,
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _fechaHasta,
                    firstDate: _fechaDesde,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _fechaHasta = picked);
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Hasta',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                    ),
                  ),
                  child: Text(
                    dateFormat.format(_fechaHasta),
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                value: _tipoMovimientoFilter,
                decoration: InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todos')),
                  DropdownMenuItem(value: 'Salida', child: Text('Salida')),
                  DropdownMenuItem(value: 'Entrada', child: Text('Entrada')),
                  DropdownMenuItem(
                    value: 'Derivacion',
                    child: Text('Derivación'),
                  ),
                ],
                onChanged: (v) => setState(() => _tipoMovimientoFilter = v),
              ),
            ),
            FilledButton.icon(
              onPressed: _isLoadingReporte ? null : _generarReporteMovimientos,
              icon:
                  _isLoadingReporte
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.search_rounded),
              label: Text(
                _isLoadingReporte ? 'Generando...' : 'Generar reporte',
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        if (_reporteMovimientos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${_reporteMovimientos.length} movimiento(s)',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _reporteMovimientos.length,
              itemBuilder: (context, index) {
                final m = _reporteMovimientos[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    m.tipoMovimiento == 'Entrada'
                        ? Icons.arrow_downward_rounded
                        : m.tipoMovimiento == 'Salida'
                        ? Icons.arrow_upward_rounded
                        : Icons.swap_horiz_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  title: Text(
                    '${m.documentoCodigo ?? "—"} · ${m.tipoMovimiento}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${m.usuarioNombre ?? "—"} · ${DateFormat('dd/MM/yyyy HH:mm').format(m.fechaMovimiento)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Text(
                    m.estado,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _exportarReportePdf(theme),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
            label: const Text('Exportar a PDF'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReportePrestadosSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REPORTE DE DOCUMENTOS PRESTADOS',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Listado de documentos en estado Prestado; exporte a PDF.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed:
              _isLoadingReportePrestados ? null : _generarReportePrestados,
          icon:
              _isLoadingReportePrestados
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.bookmark_outline_rounded),
          label: Text(
            _isLoadingReportePrestados
                ? 'Generando...'
                : 'Generar reporte prestados',
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (_reportePrestados.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${_reportePrestados.length} documento(s) prestado(s)',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _reportePrestados.length,
              itemBuilder: (context, index) {
                final d = _reportePrestados[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.description_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  title: Text(
                    d.codigo,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${d.tipoDocumentoNombre ?? "—"} · ${d.responsableNombre ?? "—"}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Text(
                    d.estado,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _exportarReportePrestadosPdf(theme),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
            label: const Text('Exportar a PDF'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _generarReportePrestados() async {
    setState(() => _isLoadingReportePrestados = true);
    try {
      final service = Provider.of<ReporteService>(context, listen: false);
      final list = await service.reporteDocumentos(estado: 'Prestado');
      if (mounted)
        setState(() {
          _reportePrestados = list;
          _isLoadingReportePrestados = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReportePrestados = false);
        AppAlert.error(
          context,
          'Error al generar reporte',
          ErrorHelper.getErrorMessage(e),
        );
      }
    }
  }

  Future<void> _generarReporteMovimientos() async {
    setState(() => _isLoadingReporte = true);
    try {
      final service = Provider.of<ReporteService>(context, listen: false);
      final list = await service.reporteMovimientos(
        fechaDesde: _fechaDesde,
        fechaHasta: _fechaHasta,
        tipoMovimiento: _tipoMovimientoFilter,
      );
      if (mounted)
        setState(() {
          _reporteMovimientos = list;
          _isLoadingReporte = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReporte = false);
        AppAlert.error(
          context,
          'Error al generar reporte',
          ErrorHelper.getErrorMessage(e),
        );
      }
    }
  }

  Future<void> _exportarReportePdf(ThemeData theme) async {
    try {
      final pdf = pw.Document();
      final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          header:
              (ctx) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'SISTEMA DE GESTIÓN DOCUMENTAL SSUT',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  pw.Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
          build:
              (ctx) => [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'REPORTE DE MOVIMIENTOS DOCUMENTALES',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                pw.Text(
                  'Período: ${DateFormat('dd/MM/yyyy').format(_fechaDesde)} al ${DateFormat('dd/MM/yyyy').format(_fechaHasta)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                if (_tipoMovimientoFilter != null)
                  pw.Text(
                    'Tipo: $_tipoMovimientoFilter',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 0.5,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(2.5),
                    3: const pw.FlexColumnWidth(2),
                    4: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey100,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Código Doc.',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Transacción',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Usuario/Responsable',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Fecha/Hora',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Estado',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ..._reporteMovimientos.map(
                      (m) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              m.documentoCodigo ?? '—',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              m.tipoMovimiento,
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              m.usuarioNombre ?? '—',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              dateFormat.format(m.fechaMovimiento),
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              m.estado,
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Total de transacciones: ${_reporteMovimientos.length}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
        ),
      );
      final bytes = await pdf.save();
      await _descargarPdf(Uint8List.fromList(bytes));
      if (mounted) {
        AppAlert.success(
          context,
          'PDF generado',
          'El reporte de movimientos se ha descargado correctamente.',
          buttonText: 'Entendido',
        );
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(
          context,
          'Error al exportar PDF',
          ErrorHelper.getErrorMessage(e),
        );
      }
    }
  }

  Future<void> _exportarReportePrestadosPdf(ThemeData theme) async {
    try {
      final pdf = pw.Document();
      final dateFormat = DateFormat('dd/MM/yyyy');
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          header:
              (ctx) => pw.Text(
                'Reporte de documentos prestados · ${dateFormat.format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
          build:
              (ctx) => [
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.5),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Código',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Tipo',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Área',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Responsable',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Estado',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ..._reportePrestados.map(
                      (d) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              d.codigo,
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              d.tipoDocumentoNombre ?? '—',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              d.areaOrigenNombre ?? '—',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              d.responsableNombre ?? '—',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              d.estado,
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
        ),
      );
      final bytes = await pdf.save();
      await _descargarPdf(
        Uint8List.fromList(bytes),
        'Reporte_Prestados_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
      if (mounted) {
        AppAlert.success(
          context,
          'PDF generado',
          'El reporte de documentos prestados se ha descargado correctamente.',
          buttonText: 'Entendido',
        );
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(
          context,
          'Error al exportar PDF',
          ErrorHelper.getErrorMessage(e),
        );
      }
    }
  }

  Future<void> _descargarPdf(Uint8List bytes, [String? filename]) async {
    if (kIsWeb) {
      final name =
          filename ??
          'Reporte_Movimientos_${DateFormat('yyyyMMdd').format(_fechaDesde)}_${DateFormat('yyyyMMdd').format(_fechaHasta)}.pdf';
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor =
          html.AnchorElement()
            ..href = url
            ..style.display = 'none'
            ..download = name;
      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    }
  }

  Widget _buildExportSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.colorPrimario, AppTheme.colorSecundario],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.colorPrimario.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.picture_as_pdf_outlined,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 24),
          Text(
            'Generar Reporte Mensual',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Use la sección "Reporte de movimientos" arriba para filtrar por período y exportar a PDF.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
