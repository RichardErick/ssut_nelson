import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/documento.dart';
import '../../../providers/auth_provider.dart';
import '../../../config/theme.dart';

class DocumentoCard extends StatelessWidget {
  final Documento doc;
  final ThemeData theme;
  final int index;
  final Function(Documento) onDetail;
  final Function(Documento) onEdit;
  final Function(Documento) onDelete;

  const DocumentoCard({
    super.key,
    required this.doc,
    required this.theme,
    required this.index,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
            onTap: () => onDetail(doc),
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
                            colors: [
                              Colors.blue.shade400,
                              Colors.blue.shade600,
                            ],
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
                          _obtenerIconoTipoDocumento(
                            doc.tipoDocumentoNombre ?? '',
                          ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
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
                      _buildActionButton(context, doc),
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
    final texto = _estadoParaMostrar(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        texto.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, Documento doc) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final canEdit = authProvider.hasPermission('editar_metadatos');
    final canDelete = authProvider.hasPermission('borrar_documento');

    if (!canEdit && !canDelete) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canEdit)
          Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: () => onEdit(doc),
              icon: Icon(
                Icons.edit_outlined,
                color: Colors.blue.shade600,
                size: 18,
              ),
              iconSize: 18,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              tooltip: 'Editar documento',
            ),
          ),
        if (canEdit && canDelete) const SizedBox(width: 6),
        if (canDelete)
          Container(
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: () => onDelete(doc),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red.shade600,
                size: 18,
              ),
              iconSize: 18,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              tooltip: 'Eliminar documento',
            ),
          ),
      ],
    );
  }

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
}
