import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/carpeta.dart';
import '../../models/documento.dart';
import '../../services/carpeta_service.dart';
import '../../services/documento_service.dart';
import '../../services/usuario_service.dart';
import '../../models/usuario.dart';

class DocumentoFormScreen extends StatefulWidget {
  final Documento? documento;

  const DocumentoFormScreen({super.key, this.documento});

  @override
  State<DocumentoFormScreen> createState() => _DocumentoFormScreenState();
}

class _DocumentoFormScreenState extends State<DocumentoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Controladores
  final _numeroCorrelativoController = TextEditingController();
  final _gestionController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _ubicacionFisicaController = TextEditingController();
  
  // Estado del formulario
  DateTime _fechaDocumento = DateTime.now();
  int? _tipoDocumentoId;
  int? _areaOrigenId;
  int? _responsableId;
  int? _carpetaId;
  int _nivelConfidencialidad = 1;

  // Listas para dropdowns (simuladas por ahora, idealmente cargar de servicios)
  // En una app real, cargaríamos TiposDocumento y Areas de sus servicios
  final List<Map<String, dynamic>> _tiposDocumento = [
    {'id': 1, 'nombre': 'Informe'},
    {'id': 2, 'nombre': 'Memorándum'},
    {'id': 3, 'nombre': 'Nota Interna'},
    {'id': 4, 'nombre': 'Carta'},
    {'id': 5, 'nombre': 'Resolución'},
  ];

  final List<Map<String, dynamic>> _areas = [
     {'id': 1, 'nombre': 'Administración'},
     {'id': 2, 'nombre': 'Contabilidad'},
     {'id': 3, 'nombre': 'Recursos Humanos'},
     {'id': 4, 'nombre': 'Legal'},
     {'id': 5, 'nombre': 'Sistemas'},
  ];

  List<Usuario> _usuarios = [];
  List<Carpeta> _carpetas = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.documento != null) {
      _initFormData(widget.documento!);
    } else {
      _gestionController.text = DateTime.now().year.toString();
    }
  }

  void _initFormData(Documento doc) {
    _numeroCorrelativoController.text = doc.numeroCorrelativo;
    _gestionController.text = doc.gestion;
    _descripcionController.text = doc.descripcion ?? '';
    _ubicacionFisicaController.text = doc.ubicacionFisica ?? '';
    _fechaDocumento = doc.fechaDocumento;
    _tipoDocumentoId = doc.tipoDocumentoId;
    _areaOrigenId = doc.areaOrigenId;
    _responsableId = doc.responsableId;
    _carpetaId = doc.carpetaId;
    _nivelConfidencialidad = doc.nivelConfidencialidad;
  }

  Future<void> _loadData() async {
    // Cargar usuarios y carpetas
    try {
      final usuarioService = Provider.of<UsuarioService>(context, listen: false);
      final carpetaService = Provider.of<CarpetaService>(context, listen: false);
      
      final usuariosFuture = usuarioService.getAll();
      final carpetasFuture = carpetaService.getAll(gestion: _gestionController.text.isNotEmpty ? _gestionController.text : DateTime.now().year.toString());

      final results = await Future.wait([usuariosFuture, carpetasFuture]);
      
      if (mounted) {
        setState(() {
          _usuarios = results[0] as List<Usuario>;
          _carpetas = results[1] as List<Carpeta>;
        });
      }
    } catch (e) {
      print('Error cargando datos auxiliares: $e');
      // No bloqueamos, cargaremos listas vacías
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaDocumento,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('es', 'BO'),
    );
    if (picked != null && picked != _fechaDocumento) {
      setState(() {
        _fechaDocumento = picked;
      });
    }
  }

  Future<void> _saveDocumento() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validaciones extra dropdowns
    if (_tipoDocumentoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione un tipo de documento')));
      return;
    }
    if (_areaOrigenId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleccione un área de origen')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final documentoService = Provider.of<DocumentoService>(context, listen: false);
      
      if (widget.documento == null) {
        // Crear
        final dto = CreateDocumentoDTO(
          numeroCorrelativo: _numeroCorrelativoController.text,
          tipoDocumentoId: _tipoDocumentoId!,
          areaOrigenId: _areaOrigenId!,
          gestion: _gestionController.text,
          fechaDocumento: _fechaDocumento,
          descripcion: _descripcionController.text,
          responsableId: _responsableId,
          ubicacionFisica: _ubicacionFisicaController.text,
          carpetaId: _carpetaId,
          nivelConfidencialidad: _nivelConfidencialidad,
        );
        await documentoService.create(dto);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento registrado exitosamente'), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        }
      } else {
        // Actualizar
        final dto = UpdateDocumentoDTO(
          numeroCorrelativo: _numeroCorrelativoController.text,
          tipoDocumentoId: _tipoDocumentoId,
          areaOrigenId: _areaOrigenId,
          gestion: _gestionController.text,
          fechaDocumento: _fechaDocumento,
          descripcion: _descripcionController.text,
          responsableId: _responsableId,
          ubicacionFisica: _ubicacionFisicaController.text,
          carpetaId: _carpetaId,
          nivelConfidencialidad: _nivelConfidencialidad,
        );
        await documentoService.update(widget.documento!.id, dto);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Documento actualizado exitosamente'), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.documento != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Documento' : 'Nuevo Documento', style: GoogleFonts.poppins()),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Información General'),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _tipoDocumentoId,
                          decoration: _inputDecoration('Tipo de Documento'),
                          items: _tiposDocumento.map((t) => DropdownMenuItem<int>(
                            value: t['id'],
                            child: Text(t['nombre']),
                          )).toList(),
                          onChanged: (v) => setState(() => _tipoDocumentoId = v),
                          validator: (v) => v == null ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _numeroCorrelativoController,
                          decoration: _inputDecoration('N° Correlativo'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _areaOrigenId,
                          decoration: _inputDecoration('Área de Origen'),
                          items: _areas.map((t) => DropdownMenuItem<int>(
                            value: t['id'],
                            child: Text(t['nombre']),
                          )).toList(),
                          onChanged: (v) => setState(() => _areaOrigenId = v),
                          validator: (v) => v == null ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _gestionController,
                          decoration: _inputDecoration('Gestión (Año)'),
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          validator: (v) => v!.length != 4 ? 'Inválido' : null,
                          onChanged: (v) {
                            if (v.length == 4) _loadData(); // Recargar carpetas al cambiar año
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: _inputDecoration('Fecha de Documento'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('dd/MM/yyyy').format(_fechaDocumento)),
                          const Icon(Icons.calendar_today, size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('Clasificación y Contenido'),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descripcionController,
                    decoration: _inputDecoration('Descripción / Asunto'),
                    maxLines: 3,
                    validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<int>(
                    value: _carpetaId,
                    decoration: _inputDecoration('Carpeta de Archivo'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('Sin carpeta asignada')),
                      ..._carpetas.map((c) => DropdownMenuItem<int>(
                        value: c.id,
                        child: Text('${c.nombre} (${c.codigo ?? "-"})'),
                      )),
                    ],
                    onChanged: (v) => setState(() => _carpetaId = v),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _responsableId,
                          decoration: _inputDecoration('Responsable'),
                          items: [
                            const DropdownMenuItem<int>(value: null, child: Text('Sin responsable')),
                            ..._usuarios.map((u) => DropdownMenuItem<int>(
                              value: u.id,
                              child: Text(u.nombreCompleto),
                            )),
                          ],
                          onChanged: (v) => setState(() => _responsableId = v),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _nivelConfidencialidad,
                          decoration: _inputDecoration('Confidencialidad'),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1 - Público')),
                            DropdownMenuItem(value: 2, child: Text('2 - Interno')),
                            DropdownMenuItem(value: 3, child: Text('3 - Restringido')),
                            DropdownMenuItem(value: 4, child: Text('4 - Confidencial')),
                            DropdownMenuItem(value: 5, child: Text('5 - Secreto')),
                          ],
                          onChanged: (v) => setState(() => _nivelConfidencialidad = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _ubicacionFisicaController,
                    decoration: _inputDecoration('Ubicación Física (Estante, Caja)'),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveDocumento,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        isEditing ? 'Actualizar Documento' : 'Registrar Documento',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blue.shade800)),
        const Divider(),
      ],
    );
  }
}
