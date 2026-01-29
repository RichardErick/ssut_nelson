import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/carpeta.dart';
import '../../services/carpeta_service.dart';
import 'carpeta_form_screen.dart';
import 'documento_form_screen.dart';
import 'documentos_list_screen.dart';

class CarpetasScreen extends StatefulWidget {
  const CarpetasScreen({super.key});

  @override
  State<CarpetasScreen> createState() => _CarpetasScreenState();
}

class _CarpetasScreenState extends State<CarpetasScreen> {
  static const String _nombreCarpetaPermitida = 'Comprobante de Egreso';
  Map<String, List<Carpeta>> _carpetasPorGestion = {};
  final List<String> _gestionesVisibles = ['2025', '2026'];
  bool _isLoading = false;

  bool get hasMainFolder {
      for (final gestion in _gestionesVisibles) {
          final carpetas = _carpetasPorGestion[gestion];
          if (carpetas != null && carpetas.any((c) => c.nombre == _nombreCarpetaPermitida)) {
              return true;
          }
      }
      return false;
  }

  @override
  void initState() {
    super.initState();
    _loadCarpetas();
  }

  Future<void> _loadCarpetas() async {
    if (mounted) setState(() => _isLoading = true);
    
    try {
      final carpetaService = Provider.of<CarpetaService>(
        context,
        listen: false,
      );

      final Map<String, List<Carpeta>> tempMap = {};
      
      await Future.wait(_gestionesVisibles.map((gestion) async {
        try {
          final carpetas = await carpetaService.getArbol(gestion);
          tempMap[gestion] = _ordenarCarpetas(carpetas);
        } catch (e) {
          print('Error loading gestion $gestion: $e');
          tempMap[gestion] = [];
        }
      }));

      if (mounted) {
        setState(() {
          _carpetasPorGestion = tempMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ [CARPETAS] Error global al cargar carpetas: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar carpetas: $e')));
      }
    }
  }

  List<Carpeta> _ordenarCarpetas(List<Carpeta> lista) {
    return [...lista]..sort((a, b) {
      final aIsMain = a.nombre == _nombreCarpetaPermitida;
      final bIsMain = b.nombre == _nombreCarpetaPermitida;
      if (aIsMain == bIsMain) return a.id.compareTo(b.id);
      return aIsMain ? -1 : 1;
    });
  }

  Future<void> _crearCarpeta({int? padreId}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarpetaFormScreen(padreId: padreId),
      ),
    );

    if (result == true) {
      // Pequeño delay para asegurar consistencia en backend antes de recargar
      await Future.delayed(const Duration(milliseconds: 300));
      await _loadCarpetas();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCarpetas = _carpetasPorGestion.values.any((l) => l.isNotEmpty);
    // Para simplificar, asumimos que se puede crear carpeta si existe al menos una carga exitosa
    // o permitimos crear siempre seleccionando gestión.

    return Scaffold(
      appBar: AppBar(
        title: Text('Carpetas', style: GoogleFonts.poppins()),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCarpetas),
        ],
      ),
      floatingActionButton:
          !hasCarpetas || !hasMainFolder
              ? FloatingActionButton.extended(
                onPressed: () => _crearCarpeta(),
                icon: const Icon(Icons.create_new_folder),
                label: const Text('Crear Comprobante Principal'),
                backgroundColor: Colors.amber.shade800,
              )
              : null,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadCarpetas,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'CARPETAS GENERALES',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      ..._gestionesVisibles.map((gestion) {
                        final carpetas = _carpetasPorGestion[gestion] ?? [];
                        return _buildGestionSection(gestion, carpetas);
                      }),
                    ],
                  ),
                ),
    );
  }

  Widget _buildGestionSection(String gestion, List<Carpeta> carpetas) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        initiallyExpanded: false,
        shape: const Border(), // Remove default borders
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Icon(
            Icons.folder_special_rounded,
            color: Colors.blue.shade800,
            size: 28,
          ),
        ),
        title: Text(
          'GESTIÓN $gestion',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900,
          ),
        ),
        subtitle: Text(
          '${carpetas.length} Carpetas principales',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.blue.shade700,
          ),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          if (carpetas.isEmpty)
             Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                   Icon(Icons.folder_off_outlined, size: 48, color: Colors.grey.shade300),
                   const SizedBox(height: 8),
                   Text(
                    'No hay carpetas para esta gestión',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            ...carpetas.map((c) => _buildCarpetaItem(c)),
        ],
      ),
    );
  }


  Widget _buildCarpetaSubtitle(Carpeta carpeta) {
    final gestionLine =
        carpeta.gestion.isNotEmpty ? 'Gestion ${carpeta.gestion}' : null;
    final nroLine =
        carpeta.numeroCarpeta != null ? 'Nro ${carpeta.numeroCarpeta}' : null;
    final romano =
        (carpeta.codigoRomano ?? '').isNotEmpty
            ? carpeta.codigoRomano
            : carpeta.codigo;
    final romanoLine = (romano ?? '').isNotEmpty ? 'Romano $romano' : null;
    final rango = _formatRango(carpeta);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (gestionLine != null) Text(gestionLine),
        if (nroLine != null) Text(nroLine),
        if (romanoLine != null) Text(romanoLine),
        const SizedBox(height: 4),
        Text('Documentos: ${carpeta.numeroDocumentos} - Rango: $rango'),
      ],
    );
  }

  Future<void> _confirmarEliminarCarpeta(Carpeta carpeta) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Eliminar carpeta'),
            content: Text(
              '¿Estás seguro de eliminar la carpeta "${carpeta.nombre}"?\n\n'
              'Se eliminarán también sus subcarpetas y documentos (borrado permanente).',
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
                child: const Text('Sí, Borrar'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _eliminarCarpeta(carpeta);
    }
  }

  Future<void> _eliminarCarpeta(Carpeta carpeta) async {
    try {
      final carpetaService = Provider.of<CarpetaService>(
        context,
        listen: false,
      );
      await carpetaService.delete(carpeta.id, hard: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carpeta eliminada')),
      );
      _loadCarpetas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  Widget _buildCarpetaItem(Carpeta carpeta) {
    return Card(
      key: ValueKey(carpeta.id),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        key: PageStorageKey('carpeta_${carpeta.id}'),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.folder_rounded,
            color: Colors.amber.shade800,
            size: 28,
          ),
        ),
        title: Text(
          carpeta.nombre,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        subtitle: _buildCarpetaSubtitle(carpeta),
        trailing: _buildCarpetaActions(carpeta),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: [
          if (carpeta.subcarpetas.isNotEmpty)
            ...carpeta.subcarpetas.map(
              (sub) => Container(
                key: ValueKey(sub.id),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.only(left: 24, right: 8),
                  leading: Icon(
                    Icons.folder_open_rounded,
                    color: Colors.amber.shade700,
                  ),
                  title: Text(
                    sub.nombre,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${sub.numeroDocumentos} documentos',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red, // Rojo puro para visibilidad
                          size: 24,
                        ),
                        tooltip: 'Eliminar Subcarpeta',
                        onPressed: () => _confirmarEliminarCarpeta(sub),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                onTap: () {
                   Navigator.push(
                     context,
                     MaterialPageRoute(
                       builder: (context) => DocumentosListScreen(initialCarpetaId: sub.id),
                     ),
                    ).then((value) {
                         _loadCarpetas();
                     });
                },
                ),
              ),
            ),
          if (carpeta.subcarpetas.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Esta carpeta está vacía',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCarpetaActions(Carpeta carpeta) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón de eliminar - SIEMPRE VISIBLE
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red, size: 22),
            tooltip: 'Eliminar Carpeta',
            onPressed: () => _confirmarEliminarCarpeta(carpeta),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: EdgeInsets.zero,
          ),
        ),
        // Menú de opciones adicionales
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
          tooltip: 'Más opciones',
          padding: EdgeInsets.zero,
          onSelected: (value) {
            if (value == 'view') {
                 Navigator.push(
                   context,
                   MaterialPageRoute(
                     builder: (context) => DocumentosListScreen(initialCarpetaId: carpeta.id),
                   ),
                  ).then((_) => _loadCarpetas());
            } else if (value == 'add') {
                _crearCarpeta(padreId: carpeta.id);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: ListTile(
                leading: Icon(Icons.snippet_folder_rounded, color: Colors.indigo, size: 20),
                title: Text('Ver Documentos', style: TextStyle(fontSize: 14)),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
             const PopupMenuItem(
              value: 'add',
               child: ListTile(
                leading: Icon(Icons.create_new_folder_outlined, color: Colors.blue, size: 20),
                title: Text('Nueva Subcarpeta', style: TextStyle(fontSize: 14)),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  int _nextNumeroSubcarpeta(int padreId) {
    // Buscar en todas las gestiones
    for (final lista in _carpetasPorGestion.values) {
       try {
         final padre = lista.firstWhere((c) => c.id == padreId);
         if (padre.subcarpetas.isEmpty) return 1;
         return padre.subcarpetas.length + 1;
       } catch (_) {
         continue; 
       }
    }
    return 1;
  }

  int _nextNumeroCarpeta() {
     // Logica simplificada o pendiente de cambiar si es necesario globalmente
    // Para simplificar, retornamos 1 o calculamos basado en todo lo cargado
    return 1; 
  }

  String _formatRango(Carpeta carpeta) {
    if (carpeta.rangoInicio == null || carpeta.rangoFin == null) {
      return 'sin documentos';
    }
    return '${carpeta.rangoInicio} - ${carpeta.rangoFin}';
  }

  void _agregarDocumentoACarpeta(Carpeta carpeta) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentoFormScreen(initialCarpetaId: carpeta.id),
      ),
    );
    if (result == true) {
      _loadCarpetas();
    }
  }
}
