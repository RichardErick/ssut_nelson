import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/movimiento.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/movimiento_service.dart';
import '../../utils/error_helper.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/loading_shimmer.dart';
import 'prestamo_form_screen.dart';

/// Filtro de tipo de movimiento para la lista.
enum _FiltroMovimiento { todos, prestamos, devoluciones }

class MovimientosScreen extends StatefulWidget {
  const MovimientosScreen({super.key});

  @override
  State<MovimientosScreen> createState() => _MovimientosScreenState();
}

class _MovimientosScreenState extends State<MovimientosScreen> {
  List<Movimiento> _movimientos = [];
  bool _isLoading = true;
  bool _sinPermisoAlertaMostrada = false;
  _FiltroMovimiento _filtro = _FiltroMovimiento.todos;

  List<Movimiento> get _movimientosFiltrados {
    switch (_filtro) {
      case _FiltroMovimiento.prestamos:
        return _movimientos.where((m) => m.tipoMovimiento == 'Salida').toList();
      case _FiltroMovimiento.devoluciones:
        return _movimientos.where((m) => m.tipoMovimiento == 'Entrada').toList();
      case _FiltroMovimiento.todos:
        return _movimientos;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMovimientos();
  }

  Future<void> _loadMovimientos() async {
    setState(() => _isLoading = true);
    try {
      final service = Provider.of<MovimientoService>(context, listen: false);
      final movimientos = await service.getAll();
      setState(() {
        _movimientos = movimientos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppAlert.error(
          context,
          'Error al cargar movimientos',
          ErrorHelper.getErrorMessage(e),
        );
      }
    }
  }

  Future<void> _confirmarDevolucion(Movimiento mov) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Registrar devolución',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          '¿Registrar la devolución del documento "${mov.documentoCodigo ?? 'Sin código'}"? El estado del documento pasará a Disponible.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
            child: const Text('Devolver'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await Provider.of<MovimientoService>(context, listen: false)
          .devolverDocumento(mov.id);
      await _loadMovimientos();
      if (mounted) {
        AppAlert.success(
          context,
          'Devolución registrada',
          'El documento ha sido marcado como devuelto y su estado es Disponible.',
          buttonText: 'Entendido',
        );
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(
          context,
          'Error al devolver',
          ErrorHelper.getErrorMessage(e),
        );
      }
    }
  }

  bool _esPrestamo(Movimiento m) => m.tipoMovimiento == 'Salida';
  bool _esDevolucion(Movimiento m) => m.tipoMovimiento == 'Entrada';

  Color _colorTipo(Movimiento m) {
    if (_esDevolucion(m)) return Colors.green.shade600;
    if (_esPrestamo(m)) return Colors.orange.shade700;
    return Colors.grey.shade600;
  }

  String _etiquetaTipo(Movimiento m) {
    if (_esDevolucion(m)) return 'Devolución';
    if (_esPrestamo(m)) return 'Préstamo';
    return m.tipoMovimiento;
  }

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
                child: Icon(
                  Icons.lock_rounded,
                  size: 80,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'No tienes permisos para acceder a esta pantalla',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'El permiso "Ver movimientos" está desactivado para tu usuario. Contacta al administrador si necesitas acceso.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    // Verificar permiso granular en lugar de rol estático
    if (!authProvider.hasPermission('ver_movimientos')) {
      return _buildSinPermisoAcceso(context);
    }
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              color: surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SSUT / Movimientos',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Movimientos de Documentos',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton.filled(
                      onPressed: _isLoading ? null : _loadMovimientos,
                      icon: const Icon(Icons.refresh_rounded, size: 22),
                      tooltip: 'Actualizar',
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filtros
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Todos',
                        selected: _filtro == _FiltroMovimiento.todos,
                        onSelected: () =>
                            setState(() => _filtro = _FiltroMovimiento.todos),
                        theme: theme,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Préstamos',
                        selected: _filtro == _FiltroMovimiento.prestamos,
                        onSelected: () =>
                            setState(() => _filtro = _FiltroMovimiento.prestamos),
                        theme: theme,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Devoluciones',
                        selected: _filtro == _FiltroMovimiento.devoluciones,
                        onSelected: () => setState(
                            () => _filtro = _FiltroMovimiento.devoluciones),
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Lista
          Expanded(
            child: _isLoading
                ? _buildLoading(theme)
                : _movimientosFiltrados.isEmpty
                    ? _buildEmpty(theme)
                    : _buildList(theme, dateFormat, onSurfaceVariant),
          ),
        ],
      ),
      floatingActionButton:
          _filtro == _FiltroMovimiento.prestamos
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => const PrestamoFormScreen()),
                    );
                    if (result == true) _loadMovimientos();
                  },
                  icon: const Icon(Icons.add_rounded, size: 24),
                  label: Text(
                    'Registrar préstamo',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  elevation: 4,
                )
              : null,
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: LoadingShimmer(
            width: double.infinity,
            height: 110,
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.swap_horiz_rounded,
                size: 56,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _filtro == _FiltroMovimiento.todos
                  ? 'No hay movimientos registrados'
                  : _filtro == _FiltroMovimiento.prestamos
                      ? 'No hay préstamos con este filtro'
                      : 'No hay devoluciones con este filtro',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _filtro == _FiltroMovimiento.todos
                  ? 'Registra el primer préstamo con el botón inferior.'
                  : 'Prueba cambiando el filtro o registra un nuevo préstamo.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    ThemeData theme,
    DateFormat dateFormat,
    Color onSurfaceVariant,
  ) {
    final list = _movimientosFiltrados;
    return RefreshIndicator(
      onRefresh: _loadMovimientos,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final mov = list[index];
          return AnimatedCard(
            delay: Duration(milliseconds: index * 40),
            margin: const EdgeInsets.only(bottom: 14),
            elevation: 0,
            borderRadius: BorderRadius.circular(16),
            child: _MovementCard(
              movimiento: mov,
              dateFormat: dateFormat,
              onSurfaceVariant: onSurfaceVariant,
              colorTipo: _colorTipo(mov),
              etiquetaTipo: _etiquetaTipo(mov),
              esPrestamo: _esPrestamo(mov),
              puedeDevolver: mov.estado == 'Activo' && _esPrestamo(mov),
              onDevolver: () => _confirmarDevolucion(mov),
              theme: theme,
            ),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.theme,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
      side: BorderSide(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.outline.withOpacity(0.3),
        width: selected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      showCheckmark: true,
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({
    required this.movimiento,
    required this.dateFormat,
    required this.onSurfaceVariant,
    required this.colorTipo,
    required this.etiquetaTipo,
    required this.esPrestamo,
    required this.puedeDevolver,
    required this.onDevolver,
    required this.theme,
  });

  final Movimiento movimiento;
  final DateFormat dateFormat;
  final Color onSurfaceVariant;
  final Color colorTipo;
  final String etiquetaTipo;
  final bool esPrestamo;
  final bool puedeDevolver;
  final VoidCallback onDevolver;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final sameArea = movimiento.areaOrigenNombre != null &&
        movimiento.areaDestinoNombre != null &&
        movimiento.areaOrigenNombre == movimiento.areaDestinoNombre;
    final originDestiny = sameArea
        ? (movimiento.areaOrigenNombre ?? '—')
        : '${movimiento.areaOrigenNombre ?? '—'} → ${movimiento.areaDestinoNombre ?? '—'}';

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banda de color por tipo
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: colorTipo,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila: código + chip tipo
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              movimiento.documentoCodigo ?? 'Sin código',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: onSurface,
                                letterSpacing: 0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorTipo.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colorTipo.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  esPrestamo
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  size: 14,
                                  color: colorTipo,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  etiquetaTipo,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorTipo,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Origen/Destino + Fecha
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              originDestiny,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateFormat.format(movimiento.fechaMovimiento),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (esPrestamo && movimiento.estado == 'Activo' && movimiento.fechaLimiteDevolucion != null) ...[
                        const SizedBox(height: 10),
                        _buildTiempoRestante(movimiento.fechaLimiteDevolucion!, theme),
                      ],
                      if (movimiento.observaciones != null &&
                          movimiento.observaciones!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          movimiento.observaciones!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (puedeDevolver) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonalIcon(
                            onPressed: onDevolver,
                            icon: const Icon(Icons.undo_rounded, size: 18),
                            label: const Text('Registrar devolución'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade50,
                              foregroundColor: Colors.green.shade800,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTiempoRestante(DateTime fechaLimite, ThemeData theme) {
    final ahora = DateTime.now();
    final fechaL = DateTime(fechaLimite.year, fechaLimite.month, fechaLimite.day);
    final fechaA = DateTime(ahora.year, ahora.month, ahora.day);
    final diferencia = fechaL.difference(fechaA).inDays;

    Color color;
    String texto;
    IconData icon;

    if (diferencia == 0) {
      color = Colors.orange.shade700;
      texto = 'Vence HOY';
      icon = Icons.warning_amber_rounded;
    } else if (diferencia == 1) {
      color = Colors.orange.shade600;
      texto = 'Vence mañana';
      icon = Icons.info_outline_rounded;
    } else if (diferencia < 0) {
      color = Colors.red.shade700;
      texto = 'Vencido hace ${diferencia.abs()} días';
      icon = Icons.error_outline_rounded;
    } else {
      color = theme.colorScheme.primary;
      texto = 'Tiempo restante: $diferencia días';
      icon = Icons.timer_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            texto,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
