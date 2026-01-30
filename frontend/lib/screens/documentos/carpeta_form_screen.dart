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
  
  // Controladores - Solo los 4 campos necesarios
  final _nombreController = TextEditingController();
  final _gestionController = TextEditingController();
  final _anoController = TextEditingController();
  final _descripcionController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final currentYear = DateTime.now().year;
    _gestionController.text = currentYear.toString();
    _anoController.text = currentYear.toString();
    
    // Sincronizar gestión y año
    _gestionController.addListener(_syncGestionToAno);
    _anoController.addListener(_syncAnoToGestion);
  }

  void _syncGestionToAno() {
    if (_gestionController.text != _anoController.text) {
      _anoController.removeListener(_syncAnoToGestion);
      _anoController.text = _gestionController.text;
      _anoController.addListener(_syncAnoToGestion);
    }
  }

  void _syncAnoToGestion() {
    if (_anoController.text != _gestionController.text) {
      _gestionController.removeListener(_syncGestionToAno);
      _gestionController.text = _anoController.text;
      _gestionController.addListener(_syncGestionToAno);
    }
  }

  @override
  void dispose() {
    _gestionController.removeListener(_syncGestionToAno);
    _anoController.removeListener(_syncAnoToGestion);
    
    _nombreController.dispose();
    _gestionController.dispose();
    _anoController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final carpetaService = Provider.of<CarpetaService>(context, listen: false);
      
      // Validaciones especificas
      if (widget.padreId == null) {
        // Verificar si ya existe carpeta principal del año/gestión
        final carpetas = await carpetaService.getAll(gestion: _gestionController.text);
        if (carpetas.any((c) => c.nombre == _nombreController.text && c.carpetaPadreId == null)) {
           throw Exception('Ya existe una carpeta "${_nombreController.text}" para la gestión ${_gestionController.text}.');
        }
      }

      final dto = CreateCarpetaDTO(
        nombre: _nombreController.text,
        codigo: null, // Sin código romano
        gestion: _gestionController.text, // Usar gestión como campo principal
        descripcion: _descripcionController.text.isNotEmpty ? _descripcionController.text : null,
        carpetaPadreId: widget.padreId,
        rangoInicio: null, // Sin rangos
        rangoFin: null, // Sin rangos
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Nueva Carpeta',
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
                  // Título del formulario
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.create_new_folder, size: 32, color: Colors.blue.shade700),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Crear Nueva Carpeta',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                'Complete los siguientes campos para crear una nueva carpeta',
                                style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // 1. Nombre de la carpeta
                  Text(
                    'Nombre de la Carpeta',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nombreController,
                    decoration: _inputDecoration('Ingrese el nombre de la carpeta', icon: Icons.folder),
                    validator: (v) => v == null || v.isEmpty ? 'El nombre es requerido' : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ej: Comprobante de Egreso, Facturas 2025, Documentos Administrativos, etc.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                  
                  const SizedBox(height: 24),

                  // 2. Gestión
                  Text(
                    'Gestión',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _gestionController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Período administrativo', icon: Icons.business_center),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'La gestión es requerida';
                      final year = int.tryParse(v);
                      if (year == null) return 'Ingrese un año válido';
                      if (year < 2020 || year > 2030) return 'El año debe estar entre 2020 y 2030';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Período administrativo o fiscal (2020-2030)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                  
                  const SizedBox(height: 24),

                  // 3. Año
                  Text(
                    'Año',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _anoController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration('Año calendario', icon: Icons.calendar_today),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'El año es requerido';
                      final year = int.tryParse(v);
                      if (year == null) return 'Ingrese un año válido';
                      if (year < 2020 || year > 2030) return 'El año debe estar entre 2020 y 2030';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Año fiscal o calendario (2020-2030)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),

                  const SizedBox(height: 24),

                  // 4. Descripción
                  Text(
                    'Descripción',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descripcionController,
                    maxLines: 3,
                    decoration: _inputDecoration('Descripción opcional de la carpeta', icon: Icons.notes),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Información adicional sobre el contenido o propósito de la carpeta (opcional)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),

                  const SizedBox(height: 40),

                  // Botón de guardar
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _guardar,
                      icon: const Icon(Icons.save_rounded, size: 24),
                      label: Text(
                        'Crear Carpeta',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 22, color: Colors.grey.shade600) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
