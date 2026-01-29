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
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Text(
              'GESTIÓN $gestion',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (carpetas.isEmpty)
             Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No hay carpetas para esta gestión',
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ...carpetas.map((c) => _buildCarpetaItem(c)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off_rounded,
              size: 80,
              color: Colors.amber.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay carpetas para $_gestion',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Crea la primera carpeta para empezar a organizar documentos.',
              style: GoogleFonts.poppins(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 260,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _crearCarpeta(),
                icon: const Icon(Icons.add_box_rounded, size: 22),
                label: const Text('Crear carpeta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade800,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
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
        IconButton(
          icon: Icon(
            Icons.create_new_folder_outlined,
            color: Colors.blue.shade700,
          ),
          tooltip: 'Nueva Subcarpeta',
          onPressed: () => _crearCarpeta(padreId: carpeta.id),
        ),
        IconButton(
          icon: const Icon(Icons.delete_forever, color: Colors.red), // Icono más visible
          tooltip: 'Eliminar Carpeta',
          onPressed: () => _confirmarEliminarCarpeta(carpeta),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
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
