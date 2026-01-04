import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/movimiento.dart';
import '../../services/movimiento_service.dart';
import '../../utils/error_helper.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/loading_shimmer.dart';

class MovimientosScreen extends StatefulWidget {
  const MovimientosScreen({super.key});

  @override
  State<MovimientosScreen> createState() => _MovimientosScreenState();
}

class _MovimientosScreenState extends State<MovimientosScreen> {
  List<Movimiento> _movimientos = [];
  bool _isLoading = true;

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
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Color _getColorForTipo(String tipo) {
    switch (tipo) {
      case 'Entrada':
        return Colors.green;
      case 'Salida':
        return Colors.red;
      case 'Derivacion':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Text(
                  'Movimientos de Documentos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadMovimientos,
                  tooltip: 'Actualizar',
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: 6,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: LoadingShimmer(
                            width: double.infinity,
                            height: 120,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        );
                      },
                    )
                    : _movimientos.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.swap_horiz,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay movimientos registrados',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadMovimientos,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _movimientos.length,
                        itemBuilder: (context, index) {
                          final mov = _movimientos[index];
                          return AnimatedCard(
                            delay: Duration(milliseconds: index * 50),
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              leading: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.0, end: 1.0),
                                duration: Duration(
                                  milliseconds: 300 + (index * 50),
                                ),
                                curve: Curves.elasticOut,
                                builder: (context, value, child) {
                                  return Transform.scale(
                                    scale: value,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            _getColorForTipo(
                                              mov.tipoMovimiento,
                                            ).withOpacity(0.3),
                                            _getColorForTipo(
                                              mov.tipoMovimiento,
                                            ).withOpacity(0.1),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _getColorForTipo(
                                              mov.tipoMovimiento,
                                            ).withOpacity(0.3),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        mov.tipoMovimiento == 'Entrada'
                                            ? Icons.arrow_downward_rounded
                                            : mov.tipoMovimiento == 'Salida'
                                            ? Icons.arrow_upward_rounded
                                            : Icons.swap_horiz_rounded,
                                        color: _getColorForTipo(
                                          mov.tipoMovimiento,
                                        ),
                                        size: 24,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              title: Text(
                                mov.documentoCodigo ?? 'Sin código',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  if (mov.areaOrigenNombre != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_rounded,
                                            size: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'Origen: ${mov.areaOrigenNombre}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (mov.areaDestinoNombre != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.flag_rounded,
                                            size: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'Destino: ${mov.areaDestinoNombre}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        dateFormat.format(mov.fechaMovimiento),
                                      ),
                                    ],
                                  ),
                                  if (mov.observaciones != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        mov.observaciones!,
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                              trailing:
                                  mov.estado == 'Activo' &&
                                          mov.tipoMovimiento == 'Salida'
                                      ? ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            await Provider.of<
                                              MovimientoService
                                            >(
                                              context,
                                              listen: false,
                                            ).devolverDocumento(mov.id);
                                            _loadMovimientos();
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: const Row(
                                                    children: [
                                                      Icon(
                                                        Icons.check_circle,
                                                        color: Colors.white,
                                                      ),
                                                      SizedBox(width: 12),
                                                      Text(
                                                        'Documento devuelto',
                                                      ),
                                                    ],
                                                  ),
                                                  backgroundColor: Colors.green,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.error_outline,
                                                        color: Colors.white,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Text(
                                                          ErrorHelper.getErrorMessage(
                                                            e,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                              ),
                                                          maxLines: 3,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  backgroundColor: Colors.red,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  duration: const Duration(
                                                    seconds: 5,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.undo_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Devolver'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.green.shade600,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      )
                                      : null,
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
