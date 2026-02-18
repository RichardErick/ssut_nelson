import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../models/carpeta.dart';
import '../../../providers/auth_provider.dart';

class CarpetaCard extends StatelessWidget {
  final Carpeta carpeta;
  final ThemeData theme;
  final Function(Carpeta) onOpen;
  final Function(Carpeta) onEdit;
  final Function(Carpeta) onDelete;

  const CarpetaCard({
    super.key,
    required this.carpeta,
    required this.theme,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canDelete = authProvider.hasPermission('borrar_documento');
    final canEdit = authProvider.hasPermission('editar_metadatos');

    final gestionLine = carpeta.gestion.isNotEmpty ? carpeta.gestion : 'N/A';
    final nroLine = carpeta.numeroCarpeta?.toString() ?? 'N/A';
    final rangoLine = (carpeta.rangoInicio != null && carpeta.rangoFin != null)
        ? '${carpeta.rangoInicio} - ${carpeta.rangoFin}'
        : null;

    final colorPrimario = (carpeta.tipo?.contains('Ingreso') ?? false) ? Colors.teal : Colors.amber.shade700;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: colorPrimario.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onOpen(carpeta),
              borderRadius: BorderRadius.circular(28),
              hoverColor: colorPrimario.withOpacity(0.02),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                colors: (carpeta.tipo?.contains('Ingreso') ?? false)
                                    ? [Colors.teal.shade300, Colors.teal.shade500]
                                    : [Colors.amber.shade400, Colors.orange.shade500],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: colorPrimario.withOpacity(0.3),
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
                        if (canEdit)
                          _buildActionCircle(
                            onTap: () => onEdit(carpeta),
                            icon: Icons.edit_rounded,
                            color: Colors.blue,
                          ),
                        if (canEdit && canDelete) const SizedBox(width: 8),
                        if (canDelete)
                          _buildActionCircle(
                            onTap: () => onDelete(carpeta),
                            icon: Icons.delete_rounded,
                            color: Colors.red,
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      carpeta.nombre,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                        height: 1.1,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildInfoBadge('Gestión', gestionLine, colorPrimario),
                        _buildInfoBadge('Carpeta Nº', nroLine, colorPrimario),
                        if (rangoLine != null)
                          _buildInfoBadge('Rango', rangoLine, Colors.grey.shade700),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.description_rounded, color: colorPrimario, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${carpeta.numeroDocumentos} documentos',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  'Archivos registrados',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3), size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCircle({required VoidCallback onTap, required IconData icon, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color.withOpacity(0.6),
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
