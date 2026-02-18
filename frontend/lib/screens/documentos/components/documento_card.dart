import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/documento.dart';
import '../../../providers/auth_provider.dart';
import '../../../theme/app_theme.dart';

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
      duration: Duration(milliseconds: 350 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onDetail(doc),
            borderRadius: BorderRadius.circular(24),
            hoverColor: theme.colorScheme.primary.withOpacity(0.02),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo Tipo y Badge Estado
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _obtenerColorTipo(doc.tipoDocumentoNombre ?? '').withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _obtenerIconoTipoDocumento(doc.tipoDocumentoNombre ?? ''),
                          color: _obtenerColorTipo(doc.tipoDocumentoNombre ?? ''),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doc.codigo,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              doc.tipoDocumentoNombre ?? 'Documento',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildEstadoBadge(doc.estado),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Descripción con estilo limpio
                  Text(
                    doc.descripcion ?? 'Sin descripción proporcionada',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),

                  const Spacer(),

                  // Info de Registro y Folder ID
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.tag_rounded, size: 14, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          doc.numeroCorrelativo,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.event_note_rounded, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          _formatearFecha(doc.fechaRegistro),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Responsable y Acciones
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          (doc.responsableNombre ?? 'U').substring(0, 1).toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          doc.responsableNombre ?? 'Sin responsable',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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

  Color _obtenerColorTipo(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'factura':
        return Colors.green.shade600;
      case 'contrato':
        return Colors.indigo.shade600;
      case 'informe':
        return Colors.orange.shade700;
      default:
        return Colors.blue.shade600;
    }
  }

  Widget _buildEstadoBadge(String estado) {
    final color = _obtenerColorEstado(estado);
    final texto = _estadoParaMostrar(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Text(
        texto.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 9,
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
          _buildTinyAction(
            onTap: () => onEdit(doc),
            icon: Icons.edit_rounded,
            color: Colors.blue.shade700,
          ),
        if (canEdit && canDelete) const SizedBox(width: 4),
        if (canDelete)
          _buildTinyAction(
            onTap: () => onDelete(doc),
            icon: Icons.delete_rounded,
            color: Colors.red.shade700,
          ),
      ],
    );
  }

  Widget _buildTinyAction({required VoidCallback onTap, required IconData icon, required Color color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
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
