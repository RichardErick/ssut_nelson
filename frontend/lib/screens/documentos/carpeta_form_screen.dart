import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/carpeta.dart';
import '../../services/carpeta_service.dart';

class CarpetaFormScreen extends StatefulWidget {
  final int? padreId;
  final Carpeta? carpetaExistente; // Para edición futura si se requiere

  const CarpetaFormScreen({super.key, this.padreId, this.carpetaExistente});

  @override
  State<CarpetaFormScreen> createState() => _CarpetaFormScreenState();
}

class _CarpetaFormScreenState extends State<CarpetaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  static const String _nombreCarpetaPermitida = 'Comprobante de Egreso';
  
  // Controladores
  final _nombreController = TextEditingController();
  final _gestionController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _codigoRomanoController = TextEditingController();
  
  // Rangos
  final _rangoInicioController = TextEditingController();
  final _rangoFinController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _gestionController.text = DateTime.now().year.toString();
    
    if (widget.padreId == null) {
      // Es carpeta principal
      _nombreController.text = _nombreCarpetaPermitida;
    } else {
      // Es subcarpeta
      _nombreController.text = 'Rango Documental';
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _gestionController.dispose();
    _descripcionController.dispose();
    _codigoRomanoController.dispose();
    _rangoInicioController.dispose();
    _rangoFinController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final carpetaService = Provider.of<CarpetaService>(context, listen: false);
      
      // Validaciones especificas
      if (widget.padreId == null) {
        // Verificar si ya existe carpeta principal del año
        final carpetas = await carpetaService.getAll(gestion: _gestionController.text);
        if (carpetas.any((c) => c.nombre == _nombreController.text && c.carpetaPadreId == null)) {
           throw Exception('Ya existe una carpeta "${_nombreController.text}" para la gestión ${_gestionController.text}.');
        }
      }

      int? rInicio = _rangoInicioController.text.isNotEmpty 
          ? int.tryParse(_rangoInicioController.text) 
          : null;
      int? rFin = _rangoFinController.text.isNotEmpty 
          ? int.tryParse(_rangoFinController.text) 
          : null;

      // Validar que si se ingresa rango, ambos campos estén completos
      if ((rInicio != null && rFin == null) || (rInicio == null && rFin != null)) {
        throw Exception('Debe especificar tanto Rango Inicio como Rango Fin, o dejar ambos vacíos.');
      }

      if (rInicio != null && rFin != null && rInicio > rFin) {
        throw Exception('El Rango Inicio no puede ser mayor que el Rango Fin.');
      }

      final dto = CreateCarpetaDTO(
        nombre: _nombreController.text,
        codigo: _codigoRomanoController.text.isNotEmpty ? _codigoRomanoController.text : null,
        gestion: _gestionController.text,
        descripcion: _descripcionController.text.isNotEmpty ? _descripcionController.text : null,
        carpetaPadreId: widget.padreId,
        rangoInicio: rInicio,
        rangoFin: rFin,
      );

      await carpetaService.create(dto);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Carpeta creada exitosamente'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Retornar true para recargar
      }

    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceAll("Exception:", "")}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esPrincipal = widget.padreId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          esPrincipal ? 'Nueva Carpeta Principal' : 'Nueva Subcarpeta',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(theme, esPrincipal),
                  const SizedBox(height: 24),

                  // Nombre de la carpeta (siempre editable)
                  TextFormField(
                    controller: _nombreController,
                    decoration: _inputDecoration('Nombre de Carpeta', icon: Icons.folder),
                    validator: (v) => v == null || v.isEmpty ? 'El nombre es requerido' : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    esPrincipal 
                      ? 'Ej: Comprobante de Egreso, Comprobante de Ingreso, etc.'
                      : 'Ej: Rango 1-50, Subcarpeta A, etc.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                  
                  const SizedBox(height: 20),

                  // Gestión (Año)
                  TextFormField(
                    controller: _gestionController,
                    readOnly: true,
                    decoration: _inputDecoration('Gestión (Año)', icon: Icons.calendar_today),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'La gestión se asigna automáticamente al año actual',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                  
                  const SizedBox(height: 16),

                  // Rango de subcarpetas
                  Text(
                    'Rango de Documentos',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Define el rango numérico de documentos que contendrá esta carpeta (opcional)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _rangoInicioController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('Límite Inicio', icon: Icons.first_page),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _rangoFinController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('Límite Fin', icon: Icons.last_page),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),

                  // Código Romano
                  TextFormField(
                    controller: _codigoRomanoController,
                    decoration: _inputDecoration('Código Romano', icon: Icons.format_list_numbered_rtl),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ej: I, II, III, IV, V, etc. (opcional)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),

                  const SizedBox(height: 20),

                  // Descripción
                  TextFormField(
                    controller: _descripcionController,
                    maxLines: 3,
                    decoration: _inputDecoration('Descripción / Observaciones', icon: Icons.notes),
                  ),

                  const SizedBox(height: 32),

                  // Botón de guardar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _guardar,
                      icon: const Icon(Icons.save_rounded, size: 22),
                      label: Text(
                        'Crear Carpeta',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: esPrincipal ? Colors.amber.shade800 : Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, bool esPrincipal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esPrincipal ? Colors.amber.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esPrincipal ? Colors.amber.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            esPrincipal ? Icons.folder_special : Icons.folder_copy,
            size: 32,
            color: esPrincipal ? Colors.amber.shade800 : Colors.blue.shade700,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esPrincipal ? 'Carpeta Maestra' : 'Subcarpeta de Archivo',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: esPrincipal ? Colors.amber.shade900 : Colors.blue.shade900,
                  ),
                ),
                Text(
                  esPrincipal 
                    ? 'Contenedor principal para los comprobantes de una gestión.'
                    : 'Agrupación de documentos por rango numérico.',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 20, color: Colors.grey.shade600) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
