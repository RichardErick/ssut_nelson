import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/carpeta.dart';
import '../../providers/data_provider.dart';
import '../../services/carpeta_service.dart';

class SubcarpetaFormScreen extends StatefulWidget {
  final int carpetaPadreId;
  final String carpetaPadreNombre;
  final Carpeta? subcarpetaExistente; // Para edición futura si se requiere

  const SubcarpetaFormScreen({
    super.key, 
    required this.carpetaPadreId,
    required this.carpetaPadreNombre,
    this.subcarpetaExistente
  });

  @override
  State<SubcarpetaFormScreen> createState() => _SubcarpetaFormScreenState();
}

class _SubcarpetaFormScreenState extends State<SubcarpetaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores para subcarpetas (formulario complejo)
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _codigoRomanoController = TextEditingController();
  
  // Rangos
  final _rangoInicioController = TextEditingController();
  final _rangoFinController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Para subcarpetas, sugerir un nombre por defecto
    _nombreController.text = 'Rango Documental';
  }

  @override
  void dispose() {
    _nombreController.dispose();
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

      // Obtener la gestión de la carpeta padre
      final carpetaPadre = await carpetaService.getById(widget.carpetaPadreId);

      final dto = CreateCarpetaDTO(
        nombre: _nombreController.text,
        codigo: _codigoRomanoController.text.isNotEmpty ? _codigoRomanoController.text : null,
        gestion: carpetaPadre.gestion, // Heredar gestión de la carpeta padre
        descripcion: _descripcionController.text.isNotEmpty ? _descripcionController.text : null,
        carpetaPadreId: widget.carpetaPadreId,
        rangoInicio: rInicio,
        rangoFin: rFin,
      );

      await carpetaService.create(dto);

      if (mounted) {
        // Notificar al DataProvider
        final dataProvider = Provider.of<DataProvider>(context, listen: false);
        dataProvider.refresh();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subcarpeta creada exitosamente'), backgroundColor: Colors.green),
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Nueva Subcarpeta',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.grey.shade800,
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
                  // Header con información de la carpeta padre
                  Container(
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade600, Colors.blue.shade800],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.folder_copy, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Subcarpeta de Archivo',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(
                                  'Carpeta padre: ${widget.carpetaPadreNombre}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Agrupación de documentos por rango numérico y organización específica.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // Formulario
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título del formulario
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.edit_note, color: Colors.orange.shade700, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Información de la Subcarpeta',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),

                        // Nombre de la subcarpeta
                        _buildFormField(
                          label: 'Nombre de la Subcarpeta',
                          controller: _nombreController,
                          icon: Icons.folder,
                          hint: 'Ej: Rango 1-50, Subcarpeta A, Documentos Enero',
                          validator: (v) => v == null || v.isEmpty ? 'El nombre es requerido' : null,
                        ),
                        
                        const SizedBox(height: 24),

                        // Sección de rango
                        _buildSectionHeader('Rango de Documentos', Icons.format_list_numbered, Colors.green),
                        const SizedBox(height: 16),
                        Text(
                          'Define el rango numérico de documentos que contendrá esta subcarpeta (opcional)',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildFormField(
                                label: 'Límite Inicio',
                                controller: _rangoInicioController,
                                icon: Icons.first_page,
                                hint: '1',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildFormField(
                                label: 'Límite Fin',
                                controller: _rangoFinController,
                                icon: Icons.last_page,
                                hint: '50',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),

                        // Código Romano
                        _buildFormField(
                          label: 'Código Romano',
                          controller: _codigoRomanoController,
                          icon: Icons.format_list_numbered_rtl,
                          hint: 'I, II, III, IV, V, etc.',
                          textCapitalization: TextCapitalization.characters,
                        ),

                        const SizedBox(height: 24),

                        // Descripción
                        _buildFormField(
                          label: 'Descripción / Observaciones',
                          controller: _descripcionController,
                          icon: Icons.notes,
                          hint: 'Información adicional sobre esta subcarpeta...',
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Botón de guardar
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade800],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _guardar,
                        borderRadius: BorderRadius.circular(16),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.save_rounded, color: Colors.white, size: 24),
                              const SizedBox(width: 12),
                              Text(
                                'Crear Subcarpeta',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
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
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization? textCapitalization,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization ?? TextCapitalization.none,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20, color: Colors.grey.shade600),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade400),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16, 
              vertical: maxLines > 1 ? 16 : 16,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            hintStyle: GoogleFonts.inter(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

}