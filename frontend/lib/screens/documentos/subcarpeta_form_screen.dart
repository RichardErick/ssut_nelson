import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/carpeta.dart';
import '../../utils/form_validators.dart';
import 'package:frontend/providers/data_provider.dart';
import 'package:intl/intl.dart';
import '../../services/carpeta_service.dart';

class SubcarpetaFormScreen extends StatefulWidget {
  /// null = carpeta principal (raíz); no null = carpeta hija
  final int? carpetaPadreId;
  final String carpetaPadreNombre;
  final Carpeta? subcarpetaExistente; // Para edición futura si se requiere

  const SubcarpetaFormScreen({
    super.key, 
    this.carpetaPadreId,
    this.carpetaPadreNombre = 'Carpeta principal',
    this.subcarpetaExistente
  });

  @override
  State<SubcarpetaFormScreen> createState() => _SubcarpetaFormScreenState();
}

class _SubcarpetaFormScreenState extends State<SubcarpetaFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _gestionController = TextEditingController(); // Gestión (año): 2024, 2025, etc.
  final _rangoInicioController = TextEditingController();
  final _rangoFinController = TextEditingController();

  DateTime? _fecha; // Fecha de la carpeta (opcional)

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarGestionPadre());
  }

  Future<void> _cargarGestionPadre() async {
    if (widget.carpetaPadreId == null) return;
    try {
      final service = Provider.of<CarpetaService>(context, listen: false);
      final carpetaPadre = await service.getById(widget.carpetaPadreId!);
      if (mounted && _gestionController.text.isEmpty) {
        _gestionController.text = carpetaPadre.gestion;
        setState(() {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _gestionController.dispose();
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

      if ((rInicio != null && rFin == null) || (rInicio == null && rFin != null)) {
        _mostrarDialogoError(
          'Rango incompleto',
          'Debe completar ambos campos (Límite Inicio y Límite Fin) o dejar ambos vacíos.',
          Icons.format_list_numbered,
          Colors.orange,
        );
        setState(() => _isLoading = false);
        return;
      }

      if (rInicio != null && rFin != null && rInicio > rFin) {
        _mostrarDialogoError(
          'Rango inválido',
          'El límite de inicio no puede ser mayor que el límite fin. Corrija los valores.',
          Icons.warning_amber_rounded,
          Colors.orange,
        );
        setState(() => _isLoading = false);
        return;
      }

      // Gestión (fecha): la del formulario o heredar de carpeta padre
      String gestion;
      if (_gestionController.text.trim().length == 4) {
        gestion = _gestionController.text.trim();
      } else if (widget.carpetaPadreId != null) {
        final carpetaPadre = await carpetaService.getById(widget.carpetaPadreId!);
        gestion = carpetaPadre.gestion;
      } else {
        _mostrarDialogoError('Gestión requerida', 'Ingrese el año de gestión (4 dígitos).', Icons.calendar_today, Colors.orange);
        setState(() => _isLoading = false);
        return;
      }

      final nombre = _nombreController.text.trim();
      if (nombre.isEmpty) {
        _mostrarDialogoError('Nombre requerido', 'Ingrese el nombre de la carpeta.', Icons.folder, Colors.orange);
        setState(() => _isLoading = false);
        return;
      }

      // No puede existir otra carpeta con el mismo rango (misma ubicación y gestión)
      if (rInicio != null && rFin != null) {
        final rangoDuplicado = await _verificarRangoDuplicado(rInicio, rFin);
        if (rangoDuplicado.duplicado) {
          _mostrarDialogoError(
            'Rango en uso',
            rangoDuplicado.ultimoValor != null
                ? 'Ya existe una carpeta con el rango $rInicio-$rFin en esta ubicación.\nÚltimo valor de rango en uso: hasta ${rangoDuplicado.ultimoValor}. Use un rango distinto.'
                : 'Ya existe una carpeta con el rango $rInicio-$rFin en esta ubicación. Use un rango distinto.',
            Icons.format_list_numbered,
            Colors.orange,
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      String? descripcion;
      if (_fecha != null) {
        descripcion = 'Fecha: ${DateFormat('dd/MM/yyyy').format(_fecha!)}';
      }

      final dto = CreateCarpetaDTO(
        nombre: nombre,
        codigo: null,
        gestion: gestion,
        descripcion: descripcion,
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
          const SnackBar(content: Text('Carpeta creada exitosamente'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Retornar true para recargar
      }

    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        
        // Detectar errores específicos y mostrar mensajes amigables
        if (errorMessage.contains('duplicate') || 
            errorMessage.contains('duplicado') || 
            errorMessage.contains('already exists') ||
            errorMessage.contains('ya existe') ||
            errorMessage.contains('unique constraint') ||
            errorMessage.contains('UNIQUE constraint failed')) {
          _mostrarDialogoError(
            'Carpeta Duplicada',
            'Ya existe una carpeta con ese rango y gestión en esta carpeta.\n\nPor favor, elija otro rango o año.',
            Icons.folder_copy_outlined,
            Colors.orange,
          );
        } else if (errorMessage.contains('validation') || errorMessage.contains('invalid')) {
          _mostrarDialogoError(
            'Datos Inválidos',
            'Los datos ingresados no son válidos. Verifique la información e intente nuevamente.',
            Icons.warning_amber_rounded,
            Colors.red,
          );
        } else if (errorMessage.contains('network') || errorMessage.contains('connection')) {
          _mostrarDialogoError(
            'Error de Conexión',
            'No se pudo conectar con el servidor. Verifique su conexión a internet e intente nuevamente.',
            Icons.wifi_off_rounded,
            Colors.grey,
          );
        } else {
          _mostrarDialogoError(
            'No se pudo crear la carpeta',
            'Revise los datos e intente de nuevo. Si el problema continúa, contacte al administrador.',
            Icons.error_outline_rounded,
            Colors.red,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarDialogoError(String titulo, String mensaje, IconData icono, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icono, color: color, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titulo,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          mensaje,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.4,
            color: Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Entendido',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Verifica si ya existe una carpeta con el mismo rango (misma ubicación). Devuelve duplicado y último valor de rango en uso.
  Future<({bool duplicado, int? ultimoValor})> _verificarRangoDuplicado(int rangoInicio, int rangoFin) async {
    try {
      final carpetaService = Provider.of<CarpetaService>(context, listen: false);
      final todas = await carpetaService.getAll();
      final hermanas = todas
          .where((c) => c.carpetaPadreId == widget.carpetaPadreId)
          .where((c) => c.rangoInicio != null && c.rangoFin != null)
          .toList();
      final duplicado = hermanas.any((c) =>
          c.rangoInicio == rangoInicio && c.rangoFin == rangoFin);
      int? ultimoValor;
      if (hermanas.isNotEmpty) {
        final maxFin = hermanas
            .where((c) => c.rangoFin != null)
            .map((c) => c.rangoFin!)
            .fold<int>(0, (a, b) => a > b ? a : b);
        ultimoValor = maxFin;
      }
      return (duplicado: duplicado, ultimoValor: ultimoValor);
    } catch (e) {
      return (duplicado: false, ultimoValor: null);
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
                                'Carpeta de Archivo',
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
                                'Referencia: Comprobantes de Egreso / Comprobantes de Ingreso. Rango y Gestión (año).',
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
                              'Información de la Carpeta',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),

                        // Nombre
                        _buildFormField(
                          label: 'Nombre',
                          controller: _nombreController,
                          icon: Icons.folder,
                          hint: 'Ej: Comprobantes 2025, Rango 1-50',
                          validator: (v) => v == null || v.trim().isEmpty ? FormValidators.requerido : null,
                        ),
                        const SizedBox(height: 24),
                        // Gestión (año)
                        _buildFormField(
                          label: 'Gestión (año)',
                          controller: _gestionController,
                          icon: Icons.calendar_today,
                          hint: 'Ej: 2024, 2025',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            if (v.trim().length != 4) return '4 dígitos (ej: 2024)';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        // Rango
                        _buildSectionHeader('Rango de Documentos', Icons.format_list_numbered, Colors.green),
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
                        // Fecha
                        _buildSectionHeader('Fecha', Icons.event, Colors.teal),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _fecha ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null && mounted) setState(() => _fecha = picked);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              hintText: 'Seleccionar fecha (opcional)',
                              prefixIcon: Icon(Icons.calendar_month, size: 20, color: Colors.grey.shade600),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            child: Text(
                              _fecha == null
                                  ? ''
                                  : DateFormat('dd/MM/yyyy').format(_fecha!),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: _fecha == null ? Colors.grey : Colors.grey.shade800,
                              ),
                            ),
                          ),
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
                                'Crear Carpeta',
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
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade600, width: 2),
            ),
            errorStyle: TextStyle(color: Colors.red.shade700, fontSize: 13),
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