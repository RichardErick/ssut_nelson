import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/carpeta.dart';

/// Widget de tarjeta para mostrar una carpeta
class CarpetaCard extends StatelessWidget {
  final Carpeta carpeta;
  final VoidCallback onTap;
  final ThemeData theme;
  final VoidCallback? onDelete;

  const CarpetaCard({
    super.key,
    required this.carpeta,
    required this.onTap,
    required this.theme,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final gestionLine =
        carpeta.gestion.isNotEmpty ? 'Gestión ${carpeta.gestion}' : null;
    final nroLine =
        carpeta.numeroCarpeta != null ? 'Nro ${carpeta.numeroCarpeta}' : null;
    final romano = (carpeta.codigoRomano ?? '').isNotEmpty
        ? carpeta.codigoRomano
        : carpeta.codigo;
    final romanoLine = (romano ?? '').isNotEmpty ? 'Romano $romano' : null;
    final rangoLine = (carpeta.rangoInicio != null && carpeta.rangoFin != null)
        ? 'Rango: ${carpeta.rangoInicio} - ${carpeta.rangoFin}'
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade300, Colors.orange.shade400],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.folder_rounded, color: Colors.white),
                ),
                const Spacer(),
                Text(
                  carpeta.nombre,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (gestionLine != null)
                  Text(
                    gestionLine,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                if (nroLine != null)
                  Text(
                    nroLine,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                if (romanoLine != null)
                  Text(
                    romanoLine,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                if (rangoLine != null)
                  Text(
                    rangoLine,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                Text(
                  'Doc: ${carpeta.numeroDocumentos}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: Colors.red.shade600,
                ),
                onPressed: onDelete,
                tooltip: 'Eliminar carpeta',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
    );
  }
}
