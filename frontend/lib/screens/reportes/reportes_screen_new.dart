import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/reporte_service.dart';
import '../../utils/utilidades_errores.dart';
import '../../widgets/charts/grafico_barras_widget.dart';
import '../../widgets/charts/grafico_lineas_widget.dart';
import '../../widgets/charts/pie_chart_widget.dart';
import '../../widgets/tarjeta_animada.dart';

class ReportesScreenNew extends StatefulWidget {
  final int? selectedIndex;
  final int? reportesIndex;

  const ReportesScreenNew({super.key, this.selectedIndex, this.reportesIndex});

  @override
  State<ReportesScreenNew> createState() => _ReportesScreenNewState();
}

class _ReportesScreenNewState extends State<ReportesScreenNew> {
  Map<String, dynamic>? _estadisticas;
  List<Map<String, dynamic>> _movimientosPorDia = [];
  bool _isLoading = true;
  String _periodoSeleccionado = 'mes'; // hoy, semana, mes, año

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant ReportesScreenNew oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reportesIndex != null &&
        widget.selectedIndex == widget.reportesIndex &&
        oldWidget.selectedIndex != widget.reportesIndex) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final service = Provider.of<ReporteService>(context, listen: false);
      
      // Cargar estadísticas generales
      final stats = await service.obtenerEstadisticas();
      
      // Cargar movimientos por día según el período seleccionado
      final movimientos = await _loadMovimientosPorDia();

      if (mounted) {
        setState(() {
          _estadisticas = stats;
          _movimientosPorDia = movimientos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: ${ErrorHelper.getErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadMovimientosPorDia() async {
    final service = Provider.of<ReporteService>(context, listen: false);
    final now = DateTime.now();
    DateTime desde;

    switch (_periodoSeleccionado) {
      case 'hoy':
        desde = DateTime(now.year, now.month, now.day);
        break;
      case 'semana':
        desde = now.subtract(const Duration(days: 7));
        break;
      case 'mes':
        desde = DateTime(now.year, now.month, 1);
        break;
      case 'año':
        desde = DateTime(now.year, 1, 1);
        break;
      default:
        desde = DateTime(now.year, now.month, 1);
    }

    final movimientos = await service.reporteMovimientos(
      fechaDesde: desde,
      fechaHasta: now,
    );

    // Agrupar por día
    final Map<String, int> movimientosPorDia = {};
    for (final mov in movimientos) {
      final fecha = DateFormat('yyyy-MM-dd').format(mov.fechaMovimiento);
      movimientosPorDia[fecha] = (movimientosPorDia[fecha] ?? 0) + 1;
    }

    // Convertir a lista ordenada
    final result = <Map<String, dynamic>>[];
    var currentDate = desde;
    while (currentDate.isBefore(now) || currentDate.isAtSameMomentAs(now)) {
      final fechaStr = DateFormat('yyyy-MM-dd').format(currentDate);
      result.add({
        'fecha': fechaStr,
        'cantidad': movimientosPorDia[fechaStr] ?? 0,
      });
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1200;
    final isTablet = size.width > 800 && size.width <= 1200;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? _buildLoadingState(theme)
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(isDesktop ? 32 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(theme),
                    const SizedBox(height: 32),
                    _buildPeriodSelector(theme),
                    const SizedBox(height: 24),
                    _buildKPICards(isDesktop, isTablet),
                    const SizedBox(height: 32),
                    _buildChartsSection(theme, isDesktop, isTablet),
                    const SizedBox(height: 32),
                    _buildDistributionSection(theme, isDesktop),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'Cargando dashboard...',
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.analytics_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard de Reportes',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Análisis y estadísticas del sistema documental',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodSelector(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPeriodChip('Hoy', 'hoy', theme),
          const SizedBox(width: 8),
          _buildPeriodChip('Semana', 'semana', theme),
          const SizedBox(width: 8),
          _buildPeriodChip('Mes', 'mes', theme),
          const SizedBox(width: 8),
          _buildPeriodChip('Año', 'año', theme),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value, ThemeData theme) {
    final isSelected = _periodoSeleccionado == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _periodoSeleccionado = value);
          _loadData();
        }
      },
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.primary,
      labelStyle: GoogleFonts.inter(
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildKPICards(bool isDesktop, bool isTablet) {
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 1);
    
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isDesktop ? 1.5 : 2,
      children: [
        _buildKPICard(
          'Total Documentos',
          '${_estadisticas!['totalDocumentos']}',
          Icons.description_rounded,
          Colors.blue,
          '+12%',
        ),
        _buildKPICard(
          'Documentos Activos',
          '${_estadisticas!['documentosActivos']}',
          Icons.verified_rounded,
          Colors.green,
          '+5%',
        ),
        _buildKPICard(
          'En Préstamo',
          '${_estadisticas!['documentosPrestados']}',
          Icons.pending_actions_rounded,
          Colors.orange,
          '-3%',
        ),
        _buildKPICard(
          'Movimientos',
          '${_movimientosPorDia.fold<int>(0, (sum, item) => sum + (item['cantidad'] as int))}',
          Icons.swap_horiz_rounded,
          Colors.purple,
          '+8%',
        ),
      ],
    );
  }

  Widget _buildKPICard(
    String title,
    String value,
    IconData icon,
    Color color,
    String trend,
  ) {
    return AnimatedCard(
      delay: const Duration(milliseconds: 100),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: trend.startsWith('+') ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trend,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: trend.startsWith('+') ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: int.tryParse(value) ?? 0),
                  duration: const Duration(milliseconds: 1200),
                  builder: (context, val, _) => Text(
                    val.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection(ThemeData theme, bool isDesktop, bool isTablet) {
    return Column(
      children: [
        // Gráfico de líneas - Movimientos por día
        AnimatedCard(
          delay: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart_rounded, color: theme.colorScheme.primary, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Movimientos por Día',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 250,
                  child: MovimientosLineChart(
                    data: _movimientosPorDia,
                    lineColor: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Gráficos de barras y pastel
        if (isDesktop || isTablet)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildBarChartCard(theme),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildPieChartCard(theme),
              ),
            ],
          )
        else ...[
          _buildBarChartCard(theme),
          const SizedBox(height: 24),
          _buildPieChartCard(theme),
        ],
      ],
    );
  }

  Widget _buildBarChartCard(ThemeData theme) {
    return AnimatedCard(
      delay: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Documentos por Tipo',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: DocumentosBarChart(
                data: (_estadisticas!['documentosPorTipo'] as Map?)?.cast<String, dynamic>() ?? {},
                barColor: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartCard(ThemeData theme) {
    // Crear datos de distribución de estados
    final distribucionEstados = {
      'Activo': _estadisticas!['documentosActivos'] ?? 0,
      'Prestado': _estadisticas!['documentosPrestados'] ?? 0,
      'Archivado': (_estadisticas!['totalDocumentos'] ?? 0) - 
                   (_estadisticas!['documentosActivos'] ?? 0) - 
                   (_estadisticas!['documentosPrestados'] ?? 0),
    };

    return AnimatedCard(
      delay: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_rounded, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Distribución por Estado',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: EstadosPieChart(data: distribucionEstados),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionSection(ThemeData theme, bool isDesktop) {
    return AnimatedCard(
      delay: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business_center_rounded, color: Colors.purple, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Documentos por Área',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            DocumentosBarChart(
              data: (_estadisticas!['documentosPorArea'] as Map?)?.cast<String, dynamic>() ?? {},
              barColor: Colors.purple,
              horizontal: true,
            ),
          ],
        ),
      ),
    );
  }
}
