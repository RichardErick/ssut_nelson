import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../controllers/documentos/documentos_controller.dart';
import '../../models/documento.dart';
import '../../models/carpeta.dart';
import '../../services/documento_service.dart';
import '../../services/carpeta_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_role.dart';

import 'widgets/documento_card.dart';
import 'widgets/carpeta_card.dart';
import 'widgets/subcarpeta_card.dart';
import 'widgets/documento_filters.dart';
import 'documento_detail_view.dart';
import 'documento_form_view.dart';
import '../carpetas/carpeta_form_view.dart';

/// Vista principal de la lista de documentos
/// Solo contiene UI, toda la lógica está en DocumentosController
class DocumentosListView extends StatelessWidget {
  const DocumentosListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DocumentosController(
        documentoService: context.read<DocumentoService>(),
        carpetaService: context.read<CarpetaService>(),
      )
        ..cargarDocumentos()
        ..cargarCarpetas(),
      child: const _DocumentosListBody(),
    );
  }
}

class _DocumentosListBody extends StatelessWidget {
  const _DocumentosListBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final canCreate = authProvider.role != UserRole.gerente;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          DocumentoFilters(canCreate: canCreate),
          Expanded(
            child: Consumer<DocumentosController>(
              builder: (context, controller, _) {
                if (controller.carpetaSeleccionada != null) {
                  return _VistaDocumentosCarpeta(
                    carpeta: controller.carpetaSeleccionada!,
                    theme: theme,
                  );
                }
                return _VistaCarpetas(theme: theme);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Vista de carpetas (cuando no hay carpeta seleccionada)
class _VistaCarpetas extends StatelessWidget {
  final ThemeData theme;

  const _VistaCarpetas({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentosController>(
      builder: (context, controller, _) {
        if (controller.estaCargandoCarpetas) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.carpetas.isEmpty) {
          return const EmptyState(
            icon: Icons.folder_open_outlined,
            title: 'No hay carpetas',
            subtitle: 'Cree su primera carpeta para comenzar',
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 360,
            childAspectRatio: 1.2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: controller.carpetas.length,
          itemBuilder: (context, index) {
            final carpeta = controller.carpetas[index];

            // Animación suave para que las carpetas "aparezcan" en la lista
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                final dx = 0.0;
                final dy = 16 * (1 - value);
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(dx, dy),
                    child: child,
                  ),
                );
              },
              child: CarpetaCard(
                carpeta: carpeta,
                onTap: () => controller.abrirCarpeta(carpeta),
                theme: theme,
                onDelete: () =>
                    _confirmarEliminarCarpeta(context, controller, carpeta),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmarEliminarCarpeta(
    BuildContext context,
    DocumentosController controller,
    Carpeta carpeta,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar carpeta'),
        content: Text(
          '¿Estás seguro de eliminar la carpeta "${carpeta.nombre}"?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await controller.eliminarCarpeta(carpeta);
    }
  }
}

/// Vista de documentos dentro de una carpeta
class _VistaDocumentosCarpeta extends StatelessWidget {
  final Carpeta carpeta;
  final ThemeData theme;

  const _VistaDocumentosCarpeta({
    required this.carpeta,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentosController>(
      builder: (context, controller, _) {
        final docs = controller.documentosCarpeta;
        final totalDocs = docs.length;
        final rango = controller.estaCargandoDocumentosCarpeta
            ? 'Cargando...'
            : controller.calcularRangoCorrelativos(docs);

        return Column(
          children: [
            _buildCarpetaHeader(context, controller, rango, totalDocs),
            if (controller.estaCargandoSubcarpetas)
              const LinearProgressIndicator(minHeight: 2)
            else if (controller.subcarpetas.isNotEmpty)
              _buildSubcarpetasList(controller),
            _buildViewToggle(context, controller),
            Expanded(
              child: _buildDocumentosList(context, controller, docs),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCarpetaHeader(
    BuildContext context,
    DocumentosController controller,
    String rango,
    int totalDocs,
  ) {
    // Cálculo de capacidad y restantes según el rango configurado en la carpeta
    int? capacidad;
    int? restantes;
    if (carpeta.rangoInicio != null && carpeta.rangoFin != null) {
      capacidad = (carpeta.rangoFin! - carpeta.rangoInicio! + 1);
      if (capacidad < 0) capacidad = 0;
      restantes = capacidad - totalDocs;
      if (restantes < 0) restantes = 0;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: controller.cerrarCarpeta,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade700],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  carpeta.nombre,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (carpeta.gestion.isNotEmpty)
                  Text(
                    'Gestión ${carpeta.gestion}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 14,
                      color: theme.colorScheme.primary.withOpacity(0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$totalDocs documento${totalDocs == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    if (rango.isNotEmpty && rango != 'Cargando...') ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.filter_list_rounded,
                        size: 14,
                        color: theme.colorScheme.secondary.withOpacity(0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Rango: $rango',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ],
                ),
                if (capacidad != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Rango ${carpeta.rangoInicio}-${carpeta.rangoFin} · Límite: $capacidad · Restantes: $restantes',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (carpeta.carpetaPadreId == null)
            ElevatedButton.icon(
              onPressed: () => _crearSubcarpeta(context, carpeta.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                elevation: 0,
              ),
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              label: const Text('Crear Subcarpeta'),
            )
          else
            ElevatedButton.icon(
              onPressed: () => _nuevoDocumento(context, carpeta),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                elevation: 0,
              ),
              icon: const Icon(Icons.note_add_outlined, size: 18),
              label: const Text('Nuevo Documento'),
            ),
        ],
      ),
    );
  }

  Widget _buildSubcarpetasList(DocumentosController controller) {
    return Container(
      height: 140,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: controller.subcarpetas.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final sub = controller.subcarpetas[index];

          // Animación horizontal para subcarpetas, da sensación de "movimiento"
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              final dx = 24 * (1 - value);
              final dy = 0.0;
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(dx, dy),
                  child: child,
                ),
              );
            },
            child: SubcarpetaCard(
              subcarpeta: sub,
              onTap: () => controller.abrirCarpeta(sub),
              theme: theme,
              onDelete: () =>
                  _confirmarEliminarSubcarpeta(context, controller, sub),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmarEliminarCarpeta(
    BuildContext context,
    DocumentosController controller,
    Carpeta carpeta,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar carpeta'),
        content: Text(
          '¿Estás seguro de eliminar la carpeta "${carpeta.nombre}"?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await controller.eliminarCarpeta(carpeta);
    }
  }

  Future<void> _confirmarEliminarSubcarpeta(
    BuildContext context,
    DocumentosController controller,
    Carpeta subcarpeta,
  ) async {
    await _confirmarEliminarCarpeta(context, controller, subcarpeta);
  }

  Widget _buildViewToggle(
    BuildContext context,
    DocumentosController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => controller.cambiarVista(true),
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label: const Text('Cuadrícula'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: controller.vistaGrid
                      ? Colors.blue.shade600
                      : Colors.blue.shade50,
                  foregroundColor: controller.vistaGrid
                      ? Colors.white
                      : Colors.blue.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => controller.cambiarVista(false),
                icon: const Icon(Icons.list_rounded, size: 18),
                label: const Text('Lista'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: !controller.vistaGrid
                      ? Colors.blue.shade600
                      : Colors.blue.shade50,
                  foregroundColor: !controller.vistaGrid
                      ? Colors.white
                      : Colors.blue.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentosList(
    BuildContext context,
    DocumentosController controller,
    List<Documento> docs,
  ) {
    if (controller.estaCargandoDocumentosCarpeta) {
      return const Center(child: CircularProgressIndicator());
    }

    if (docs.isEmpty) {
      return const EmptyState(
        icon: Icons.description_outlined,
        title: 'Sin documentos',
        subtitle: 'Agregue el primer documento a esta carpeta',
      );
    }

    if (controller.vistaGrid) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 420,
          childAspectRatio: 1.6,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          return DocumentoCard(
            documento: docs[index],
            onTap: () => _verDetalle(context, controller, docs[index]),
            onDelete: () => _confirmarEliminar(context, controller, docs[index]),
            theme: theme,
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return DocumentoCard(
          documento: docs[index],
          onTap: () => _verDetalle(context, controller, docs[index]),
          onDelete: () => _confirmarEliminar(context, controller, docs[index]),
          theme: theme,
          isListView: true,
        );
      },
    );
  }

  Future<void> _verDetalle(
    BuildContext context,
    DocumentosController controller,
    Documento doc,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentoDetailView(documento: doc),
      ),
    );

    if (result == true) {
      controller.cargarDocumentos();
      if (controller.carpetaSeleccionada != null) {
        controller.cargarDocumentosCarpeta(controller.carpetaSeleccionada!.id);
      }
    }
  }

  Future<void> _confirmarEliminar(
    BuildContext context,
    DocumentosController controller,
    Documento doc,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar documento'),
        content: Text(
          '¿Estás seguro de eliminar el documento "${doc.codigo}"?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await controller.eliminarDocumento(doc);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Documento "${doc.codigo}" eliminado'),
                ],
              ),
              backgroundColor: AppTheme.colorExito,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppTheme.colorError,
            ),
          );
        }
      }
    }
  }

  Future<void> _crearSubcarpeta(BuildContext context, int padreId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarpetaFormView(padreId: padreId),
      ),
    );

    if (result == true && context.mounted) {
      final controller = context.read<DocumentosController>();
      controller.cargarSubcarpetas(padreId);
      controller.cargarCarpetas();
    }
  }

  Future<void> _nuevoDocumento(BuildContext context, Carpeta carpeta) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentoFormView(initialCarpetaId: carpeta.id),
      ),
    );

    if (result == true && context.mounted) {
      final controller = context.read<DocumentosController>();
      controller.cargarDocumentos();
      controller.cargarCarpetas();
      controller.cargarDocumentosCarpeta(carpeta.id);
    }
  }
}
