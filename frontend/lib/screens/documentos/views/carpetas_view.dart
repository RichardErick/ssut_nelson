import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../models/carpeta.dart';
import '../../../models/user_role.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/carpeta_service.dart';
import '../../../controllers/carpetas/carpetas_controller.dart';
import '../carpeta_form_screen.dart';
import '../documentos_list_screen.dart';

/// View for displaying Carpetas (Folders) organized by modules
class CarpetasView extends StatefulWidget {
  const CarpetasView({super.key});

  @override
  State<CarpetasView> createState() => _CarpetasViewState();
}

class _CarpetasViewState extends State<CarpetasView> {
  late CarpetasController _controller;
  String _gestionSeleccionada = '2025';
  
  // Constantes para módulos
  static const String _moduloEgresos = 'Comprobante de Egreso';
  static const String _moduloIngresos = 'Comprobante de Ingreso';
  static const List<String> _gestionesVisibles = ['2024', '2025', '2026'];

  bool get _hasMainFolder {
    final carpetas = _getCarpetasForGestion(_gestionSeleccionada);
    return carpetas.any((c) => c.carpetaPadreId == null);
  }

  List<Carpeta> _getCarpetasForGestion(String gestion) {
    return _controller.carpetas.where((c) => c.gestion == gestion).toList();
  }

  @override
  void initState() {
    super.initState();
    final carpetaService = Provider.of<CarpetaService>(context, listen: false);
    _controller = CarpetasController(service: carpetaService);
    _controller.cargarCarpetas();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _crearCarpeta({int? padreId}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CarpetaFormScreen(padreId: padreId),
      ),
    );

    if (result == true) {
      // Reload data
      await _controller.cargarCarpetas();
      
      // Force UI refresh
      if (mounted) {
        setState(() {});
      }
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Carpeta creada exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Gestión Documental', style: GoogleFonts.poppins()),
            actions: [
              // Filter by gestion
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: DropdownButton<String>(
                  value: _gestionSeleccionada,
                  dropdownColor: Colors.white,
                  style: GoogleFonts.poppins(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                  ),
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
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _controller.cargarCarpetas,
              ),
            ],
          ),
          floatingActionButton: _controller.carpetas.isEmpty || !_hasMainFolder
              ? FloatingActionButton.extended(
                  onPressed: () => _crearCarpeta(),
                  icon: const Icon(Icons.create_new_folder),
                  label: const Text('Crear Módulo'),
                  backgroundColor: Colors.amber.shade800,
                )
              : null,
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _controller.cargarCarpetas,
                  child: _buildModularView(),
                ),
        );
      },
    );
  }

  Widget _buildModularView() {
    final carpetas = _getCarpetasForGestion(_gestionSeleccionada);

    // Separate by modules
    final carpetaEgresos = carpetas
        .where((c) => c.nombre == _moduloEgresos)
        .firstOrNull;
    final carpetaIngresos = carpetas
        .where((c) => c.nombre == _moduloIngresos)
        .firstOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con estadísticas
          _buildStatsHeader(carpetas),
          const SizedBox(height: 32),

          // Título de módulos
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.folder_special, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Módulos de Gestión',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    'Organización por tipo de comprobante',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),

          // Grid de módulos mejorado
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 800 ? 2 : 1,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: MediaQuery.of(context).size.width > 800 ? 1.8 : 1.2,
            children: [
              // Módulo Egresos
              if (carpetaEgresos != null)
                _buildModernModuloCard(
                  _moduloEgresos,
                  carpetaEgresos,
                  Colors.red,
                  Icons.trending_up,
                  'Comprobantes de salida de dinero',
                ),
              
              // Módulo Ingresos
              if (carpetaIngresos != null)
                _buildModernModuloCard(
                  _moduloIngresos,
                  carpetaIngresos,
                  Colors.green,
                  Icons.trending_down,
                  'Comprobantes de entrada de dinero',
                ),
            ],
          ),

          // Empty state mejorado
          if (carpetaEgresos == null && carpetaIngresos == null)
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(List<Carpeta> carpetas) {
    final totalSubcarpetas = carpetas.fold<int>(0, (sum, c) => sum + c.subcarpetas.length);
    final totalDocumentos = carpetas.fold<int>(0, (sum, c) => sum + c.numeroDocumentos);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.indigo.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: Colors.blue.shade700, size: 28),
              const SizedBox(width: 12),
              Text(
                'Resumen de Gestión $_gestionSeleccionada',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildStatCard('Módulos', '${carpetas.length}', Icons.folder, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Subcarpetas', '$totalSubcarpetas', Icons.folder_open, Colors.orange)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Documentos', '$totalDocumentos', Icons.description, Colors.green)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernModuloCard(
    String nombre, 
    Carpeta carpeta, 
    Color color, 
    IconData icon,
    String descripcion,
  ) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canDelete = authProvider.hasPermission('borrar_documento') || 
                      authProvider.role == UserRole.administradorSistema;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
          onTap: () => _abrirCarpeta(carpeta),
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // Header del módulo
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.1),
                      color.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 32),
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
                              color: color.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            descripcion,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canDelete)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () => _confirmarEliminarCarpeta(carpeta),
                          icon: Icon(Icons.delete_outline, color: Colors.red.shade600, size: 20),
                          tooltip: 'Eliminar módulo',
                        ),
                      ),
                  ],
                ),
              ),
              
              // Contenido del módulo
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Estadísticas del módulo
                      Row(
                        children: [
                          Expanded(
                            child: _buildModuleStatItem(
                              'Subcarpetas',
                              '${carpeta.subcarpetas.length}',
                              Icons.folder_open,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildModuleStatItem(
                              'Documentos',
                              '${carpeta.numeroDocumentos}',
                              Icons.description,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      // Botón de acción
                      Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.8), color],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _abrirCarpeta(carpeta),
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.folder_open, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Abrir Módulo',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.folder_off_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No hay módulos para esta gestión',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea tu primer módulo para comenzar a organizar documentos',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarEliminarCarpeta(Carpeta carpeta) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
      await _controller.eliminarCarpeta(carpeta);
      if (!mounted) return;
      
      // Force UI refresh
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Carpeta eliminada exitosamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
