import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/movimiento.dart';
import '../../providers/auth_provider.dart';
import '../../services/movimiento_service.dart';
import '../../utils/error_helper.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/app_alert.dart';

/// Pantalla donde el usuario ve SOLO sus préstamos activos
/// y puede registrar la devolución de cada uno.
class MisPrestamosScreen extends StatefulWidget {
  const MisPrestamosScreen({super.key});

  @override
  State<MisPrestamosScreen> createState() => _MisPrestamosScreenState();
}

class _MisPrestamosScreenState extends State<MisPrestamosScreen> {
  List<Movimiento> _misPrestamos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMisPrestamos();
  }

  Future<void> _loadMisPrestamos() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.userId;
      if (userId == null) {
        setState(() {
          _misPrestamos = [];
          _isLoading = false;
        });
        return;
      }
      final service = Provider.of<MovimientoService>(context, listen: false);
      final todos = await service.getAll();
      // Solo préstamos (Salida) activos del usuario logueado
      final propios = todos
          .where(
            (m) =>
                m.tipoMovimiento == 'Salida' &&
                m.estado == 'Activo' &&
                m.usuarioId == userId,
          )
          .toList();
      setState(() {
        _misPrestamos = propios;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppAlert.error(
          context,
          'Error al cargar préstamos',
          ErrorHelper.getErrorMessage(e),
        );
      }
    }
  }

  Future<void> _devolver(Movimiento mov) async {
    final confirmar = await AppAlert.confirm(
      context,
      'Registrar devolución',
      '¿Confirmas que estás devolviendo el documento "${mov.documentoCodigo ?? 'Sin código'}"?',
      okText: 'Sí, devolver',
    );
    if (confirmar != true || !mounted) return;

    try {
      final service = Provider.of<MovimientoService>(context, listen: false);
      await service.devolverDocumento(mov.id);
      if (!mounted) return;
      await _loadMisPrestamos();
      AppAlert.success(
        context,
        'Devolución registrada',
        'El documento ha sido marcado como devuelto.',
      );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SSUT / Mis préstamos',
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
                      'Mis préstamos activos',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton.filled(
                      onPressed: _isLoading ? null : _loadMisPrestamos,
                      icon: const Icon(Icons.refresh_rounded, size: 22),
                      tooltip: 'Actualizar',
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Aquí ves únicamente los documentos que tienes prestados a tu nombre y puedes registrar su devolución.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _misPrestamos.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_turned_in_outlined,
                                size: 56,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No tienes préstamos activos',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Cuando te presten un documento aparecerá aquí hasta que se registre su devolución.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadMisPrestamos,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          itemCount: _misPrestamos.length,
                          itemBuilder: (context, index) {
                            final mov = _misPrestamos[index];
                            final vence = mov.fechaLimiteDevolucion;
                            final hoy = DateTime.now();
                            int? diasRestantes;
                            if (vence != null) {
                              final fVence = DateTime(
                                vence.year,
                                vence.month,
                                vence.day,
                              );
                              final fHoy = DateTime(
                                hoy.year,
                                hoy.month,
                                hoy.day,
                              );
                              diasRestantes =
                                  fVence.difference(fHoy).inDays;
                            }

                            Color badgeColor = theme.colorScheme.primary;
                            String badgeText = 'Activo';
                            if (diasRestantes != null) {
                              if (diasRestantes < 0) {
                                badgeColor = Colors.red.shade700;
                                badgeText =
                                    'Vencido hace ${diasRestantes.abs()} día(s)';
                              } else if (diasRestantes == 0) {
                                badgeColor = Colors.orange.shade700;
                                badgeText = 'Vence HOY';
                              } else {
                                badgeColor = theme.colorScheme.primary;
                                badgeText =
                                    'Quedan $diasRestantes día(s)';
                              }
                            }

                            return AnimatedCard(
                              delay:
                                  Duration(milliseconds: index * 40),
                              margin:
                                  const EdgeInsets.only(bottom: 14),
                              elevation: 0,
                              borderRadius:
                                  BorderRadius.circular(16),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.1),
                                  ),
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            mov.documentoCodigo ??
                                                'Sin código',
                                            style:
                                                GoogleFonts.poppins(
                                              fontSize: 16,
                                              fontWeight:
                                                  FontWeight.w700,
                                              color: theme
                                                  .colorScheme
                                                  .onSurface,
                                            ),
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: badgeColor
                                                .withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            badgeText,
                                            style:
                                                GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color: badgeColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (mov.areaOrigenNombre != null ||
                                        mov.areaDestinoNombre !=
                                            null) ...[
                                      Text(
                                        '${mov.areaOrigenNombre ?? '-'} → ${mov.areaDestinoNombre ?? '-'}',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.event_outlined,
                                          size: 14,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Préstamo: ${dateFormat.format(mov.fechaMovimiento)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (vence != null) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons
                                                .event_available_outlined,
                                            size: 14,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Límite: ${dateFormat.format(vence)}',
                                            style:
                                                GoogleFonts.inter(
                                              fontSize: 12,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment:
                                          Alignment.centerRight,
                                      child: FilledButton.icon(
                                        onPressed: () => _devolver(mov),
                                        icon: const Icon(
                                          Icons.undo_rounded,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Registrar devolución',
                                        ),
                                        style:
                                            FilledButton.styleFrom(
                                          backgroundColor: Colors
                                              .green.shade600,
                                          foregroundColor:
                                              Colors.white,
                                          padding:
                                              const EdgeInsets
                                                  .symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

