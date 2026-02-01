import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/carpeta.dart';

/// Widget de tarjeta para mostrar una subcarpeta
class SubcarpetaCard extends StatelessWidget {
  final Carpeta subcarpeta;
  final VoidCallback onTap;
  final ThemeData theme;
  final VoidCallback? onDelete;

  const SubcarpetaCard({
    super.key,
    required this.subcarpeta,
    required this.onTap,
    required this.theme,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            width: 140,
            height: 130,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.folder_shared_rounded, color: Colors.blue, size: 28),
                const Spacer(),
                Text(
                  subcarpeta.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade900,
                  ),
                ),
                if (subcarpeta.rangoInicio != null && subcarpeta.rangoFin != null)
                  Text(
                    '${subcarpeta.rangoInicio} - ${subcarpeta.rangoFin}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                    ),
                  ),
                Text(
                  '${subcarpeta.numeroDocumentos} docs',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (onDelete != null)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.red.shade600,
                ),
                onPressed: onDelete,
                tooltip: 'Eliminar subcarpeta',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
    );
  }
}
