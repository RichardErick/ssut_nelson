import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/carpeta.dart';
import '../../services/carpeta_service.dart';
import 'carpeta_form_screen.dart';
import 'documentos_list_screen.dart';

class CarpetasScreen extends StatefulWidget {
  const CarpetasScreen({super.key});

  @override
  State<CarpetasScreen> createState() => _CarpetasScreenState();
}

class _CarpetasScreenState extends State<CarpetasScreen> {
  Map<String, List<Carpeta>> _carpetasPorGestion = {};
  final List<String> _gestionesVisibles = ['2025', '2026'];
  String _gestionSeleccionada = '2025'; // Filtro de gestión
  bool _isLoading = false;

  // Módulos (tipos de carpetas principales)
  static const String _moduloEgresos = 'Comprobante de Egreso';
  static const String _moduloIngresos = 'Comprobante de Ingreso';

  bool get hasMainFolder {
    for (final gestion in _gestionesVisibles) {
      final carpetas = _carpetasPorGestion[gestion];
      if (carpetas != null && carpetas.any((c) => c.nombre == _moduloEgresos || c.nombre == _moduloIngresos)) {
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
          tempMap[gestion] = carpetas;
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

  Future<void> _crearCarpeta({int? padreId}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarpetaFormScreen(padreId: padreId),
      ),
    );

    if (result == true) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _loadCarpetas();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCarpetas = _carpetasPorGestion.values.any((l) => l.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión Documental', style: GoogleFonts.poppins()),
        actions: [
          // Filtro de gestión
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: _gestionSeleccionada,
              dropdownColor: Colors.white,
              style: GoogleFonts.poppins(color: Colors.blue.shade900, fontWeight: FontWeight.bold),
              underline: Container(),
              items: _gestionesVisibles.map((gestion) {
                return DropdownMenuItem(
                  value: gestion,
                  child: Text('Gestión $gestion'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _gestionSeleccionada = value);
                }
              },
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCarpetas),
        ],
      ),
      floatingActionButton:
          !hasCarpetas || !hasMainFolder
              ? FloatingActionButton.extended(
                onPressed: () => _crearCarpeta(),
                icon: const Icon(Icons.create_new_folder),
                label: const Text('Crear Módulo'),
                backgroundColor: Colors.amber.shade800,
              )
              : null,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadCarpetas,
                  child: _buildModularView(),
                ),
    );
  }

  Widget _buildModularView() {
    final carpetas = _carpetasPorGestion[_gestionSeleccionada] ?? [];
    
    // Separar por módulos
    final carpetaEgresos = carpetas.where((c) => c.nombre == _moduloEgresos).firstOrNull;
    final carpetaIngresos = carpetas.where((c) => c.nombre == _moduloIngresos).firstOrNull;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Título principal
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              Text(
                'GESTIÓN $_gestionSeleccionada',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Organizado por Módulos',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        
        // Módulo de Egresos
        if (carpetaEgresos != null)
          _buildModuloCard(_moduloEgresos, carpetaEgresos, Colors.red, Icons.arrow_upward),
        
        const SizedBox(height: 16),
        
        // Módulo de Ingresos
        if (carpetaIngresos != null)
          _buildModuloCard(_moduloIngresos, carpetaIngresos, Colors.green, Icons.arrow_downward),
        
        // Si no hay carpetas
        if (carpetaEgresos == null && carpetaIngresos == null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No hay módulos para esta gestión',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade500,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildModuloCard(String nombre, Carpeta carpeta, Color color, IconData icon) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Cabecera del módulo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color.shade700,
                        ),
                      ),
                      Text(
                        '${carpeta.subcarpetas.length} subcarpetas',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // BOTÓN DE ELIMINAR MÓDULO - MUY VISIBLE
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200, width: 2),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.red, size: 28),
                    tooltip: 'Eliminar Módulo Completo',
                    onPressed: () => _confirmarEliminarCarpeta(carpeta),
                  ),
                ),
              ],
            ),
          ),
          // Subcarpetas
          if (carpeta.subcarpetas.isNotEmpty)
            ...carpeta.subcarpetas.map((sub) => _buildSubcarpetaItem(sub, color))
          else
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No hay subcarpetas en este módulo',
                style: GoogleFonts.poppins(color: Colors.grey.shade500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubcarpetaItem(Carpeta subcarpeta, Color moduleColor) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: moduleColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.folder_open, color: moduleColor, size: 24),
        ),
        title: Text(
          subcarpeta.nombre,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Documentos: ${subcarpeta.numeroDocumentos}',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (subcarpeta.rangoInicio != null && subcarpeta.rangoFin != null)
              Text(
                'Rango: ${subcarpeta.rangoInicio} - ${subcarpeta.rangoFin}',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade500),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // BOTÓN DE ELIMINAR SUBCARPETA - MUY VISIBLE
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200, width: 1.5),
              ),
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                tooltip: 'Eliminar Subcarpeta',
                onPressed: () => _confirmarEliminarCarpeta(subcarpeta),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DocumentosListScreen(initialCarpetaId: subcarpeta.id),
            ),
          ).then((_) => _loadCarpetas());
        },
      ),
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
}
