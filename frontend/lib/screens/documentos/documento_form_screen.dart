import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/carpeta.dart';
import '../../models/documento.dart';
import '../../models/usuario.dart';
import '../../services/anexo_service.dart';
import '../../services/carpeta_service.dart';
import '../../services/catalogo_service.dart';
import '../../services/documento_service.dart';
import '../../services/usuario_service.dart';

class DocumentoFormScreen extends StatefulWidget {
  final Documento? documento;
  final int? initialCarpetaId;

  const DocumentoFormScreen({super.key, this.documento, this.initialCarpetaId});

  @override
  State<DocumentoFormScreen> createState() => _DocumentoFormScreenState();
}

class _DocumentoFormScreenState extends State<DocumentoFormScreen> {
  static const String _nombreCarpetaPermitida = 'Comprobante de Egreso';
  final _formKey = GlobalKey<FormState>();
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  bool _isLoading = true;

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
  PlatformFile? _pickedFile;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  // Listas para dropdowns (simuladas por ahora, idealmente cargar de servicios)
  // En una app real, cargaríamos TiposDocumento y Areas de sus servicios
  List<Map<String, dynamic>> _tiposDocumento = [];
  List<Map<String, dynamic>> _areas = [];
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
      _carpetaId = widget.initialCarpetaId;
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
    // Cargar usuarios, carpetas, áreas y tipos
    try {
      final usuarioService = Provider.of<UsuarioService>(
        context,
        listen: false,
      );
      final carpetaService = Provider.of<CarpetaService>(
        context,
        listen: false,
      );
      final catalogoService = Provider.of<CatalogoService>(
        context,
        listen: false,
      );

      final usuariosFuture = usuarioService.getAll();
      final carpetasFuture = carpetaService.getAll(
        gestion:
            _gestionController.text.isNotEmpty
                ? _gestionController.text
                : DateTime.now().year.toString(),
      );
      final areasFuture = catalogoService.getAreas();
      final tiposFuture = catalogoService.getTiposDocumento();

      final results = await Future.wait([
        usuariosFuture,
        carpetasFuture,
        areasFuture,
        tiposFuture,
      ]);

      if (mounted) {
        setState(() {
          _usuarios =
              (results[0] as List<Usuario>).where((u) => u.activo).toList();
          _carpetas = results[1] as List<Carpeta>;
          _areas = (results[2] as List<Map<String, dynamic>>);
          _tiposDocumento = (results[3] as List<Map<String, dynamic>>);

          // Filtrar solo Contabilidad
          final contabilidad =
              _areas
                  .where(
                    (a) => a['nombre'].toString().toLowerCase().contains(
                      'contabilidad',
                    ),
                  )
                  .toList();

          if (contabilidad.isNotEmpty) {
            _areas = contabilidad;
            _areaOrigenId = contabilidad.first['id'];
          }

          if (_areaOrigenId != null &&
              !_areas.any((a) => a['id'] == _areaOrigenId)) {
            _areaOrigenId = null;
          }

          // Asignar tipo de documento por defecto si no hay uno seleccionado
          if (_tiposDocumento.isNotEmpty && _tipoDocumentoId == null) {
            _tipoDocumentoId = _tiposDocumento.first['id'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        print('Error cargando datos auxiliares: $e');
        setState(() => _isLoading = false);
      }
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
      _showSnack('Seleccione un tipo de documento', background: Colors.orange);
      return;
    }
    if (_areaOrigenId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione un área de origen')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final documentoService = Provider.of<DocumentoService>(
        context,
        listen: false,
      );

      if (widget.documento == null) {
        // Validación: Responsable es obligatorio
        if (_responsableId == null) {
          _showSnack(
            'Debe seleccionar un responsable',
            background: Colors.orange,
          );
          setState(() => _isLoading = false);
          return;
        }

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
        final newDoc = await documentoService.create(dto);

        if (_pickedFile != null) {
          final anexoService = Provider.of<AnexoService>(
            context,
            listen: false,
          );
          await anexoService.subirArchivo(newDoc.id, _pickedFile!);
        }

        if (mounted) {
          _showSnack('Documento creado con exito', background: Colors.green);
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

        if (_pickedFile != null) {
          final anexoService = Provider.of<AnexoService>(
            context,
            listen: false,
          );
          await anexoService.subirArchivo(widget.documento!.id, _pickedFile!);
        }

        if (mounted) {
          _showSnack(
            'Documento actualizado con exito',
            background: Colors.green,
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error al guardar: $e', background: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _crearNuevaCarpeta() async {
    if (_carpetas.any((c) => c.nombre == _nombreCarpetaPermitida)) {
      _showSnack(
        'La carpeta Comprobante de Egreso ya existe',
        background: Colors.orange,
      );
      return;
    }
    final nombreController = TextEditingController(
      text: _nombreCarpetaPermitida,
    );
    final codigoController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Nueva Carpeta'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: codigoController,
                  decoration: const InputDecoration(
                    labelText: 'Código (Opcional)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nombreController.text.isEmpty) return;
                  try {
                    final carpetaService = Provider.of<CarpetaService>(
                      context,
                      listen: false,
                    );
                    await carpetaService.create(
                      CreateCarpetaDTO(
                        nombre: nombreController.text,
                        codigo:
                            codigoController.text.isEmpty
                                ? null
                                : codigoController.text,
                        gestion: _gestionController.text,
                        descripcion: '',
                      ),
                    );
                    if (context.mounted) {
                      Navigator.pop(context, true);
                      _showSnack('Carpeta creada', background: Colors.green);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: const Text('Crear'),
              ),
            ],
          ),
    );

    if (result == true) {
      await _loadData(); // Recargar carpetas
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.documento != null;
    final ocultarSelectorCarpeta =
        !isEditing && widget.initialCarpetaId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar Documento' : 'Nuevo Documento',
          style: GoogleFonts.poppins(),
        ),
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _autoValidateMode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Información General'),
                      if (_tiposDocumento.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 16.0,
                            top: 8.0,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange.shade800,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Advertencia: No hay tipos de documento disponibles. No podrá guardar.',
                                    style: TextStyle(
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _numeroCorrelativoController,
                        decoration: _inputDecoration('N° Correlativo'),
                        keyboardType: TextInputType.number,
                        validator:
                            (v) => v == null || v.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<int>(
                              value: _areaOrigenId,
                              isExpanded: true,
                              decoration: _inputDecoration('Área Origen'),
                              items:
                                  _areas
                                      .map(
                                        (t) => DropdownMenuItem<int>(
                                          value: t['id'],
                                          child: Text(
                                            t['nombre'],
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  _areas.length == 1
                                      ? null
                                      : (v) =>
                                          setState(() => _areaOrigenId = v),
                              validator: (v) => v == null ? 'Requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _gestionController,
                              decoration: _inputDecoration('Gestión'),
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              validator:
                                  (v) => v!.length != 4 ? 'Inválido' : null,
                              onChanged: (v) {
                                if (v.length == 4)
                                  _loadData(); // Recargar carpetas al cambiar año
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
                              Text(
                                DateFormat(
                                  'dd/MM/yyyy',
                                ).format(_fechaDocumento),
                              ),
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
                        validator:
                            (v) => v == null || v.isEmpty ? 'Requerido' : null,
                      ),
                      if (!ocultarSelectorCarpeta) ...[
                        if (_carpetas.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _crearNuevaCarpeta,
                                icon: const Icon(Icons.create_new_folder),
                                label: const Text('Crear carpeta'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade800,
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: _carpetaId,
                                  decoration: _inputDecoration(
                                    'Carpeta de Archivo',
                                  ),
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem<int>(
                                      value: null,
                                      child: Text('Sin carpeta asignada'),
                                    ),
                                    ..._carpetas.map(
                                      (c) => DropdownMenuItem<int>(
                                        value: c.id,
                                        child: Text(
                                          '${c.nombre} (${c.codigo ?? "-"})',
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged:
                                      (v) => setState(() => _carpetaId = v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _crearNuevaCarpeta,
                                icon: const Icon(
                                  Icons.create_new_folder,
                                  color: Colors.blue,
                                ),
                                tooltip: 'Nueva Carpeta',
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                      ],

                      DropdownButtonFormField<int>(
                        value: _responsableId,
                        decoration: _inputDecoration('Responsable *'),
                        items:
                            _usuarios
                                .map(
                                  (u) => DropdownMenuItem<int>(
                                    value: u.id,
                                    child: Text(u.nombreCompleto),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => _responsableId = v),
                        validator:
                            (v) => v == null ? 'Responsable requerido' : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _ubicacionFisicaController,
                        decoration: _inputDecoration(
                          'Ubicación Física (Estante, Caja)',
                        ),
                      ),

                      const SizedBox(height: 16),

                      // SECCION: ADJUNTAR ARCHIVO (Simulada visualmente, funcional con click)
                      _buildSectionTitle('Archivo Digital'),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _pickFile,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 24,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _pickedFile != null
                                    ? Colors.green.withOpacity(0.05)
                                    : Colors.blue.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  _pickedFile != null
                                      ? Colors.green.shade300
                                      : Colors.blue.shade300,
                              width: 1.5,
                              style: BorderStyle.solid,
                            ),
                            // Dashed border effect simulation can be complex, solid is fine for now
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _pickedFile != null
                                    ? Icons.check_circle_outline
                                    : Icons.cloud_upload_outlined,
                                size: 40,
                                color:
                                    _pickedFile != null
                                        ? Colors.green
                                        : Colors.blue,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _pickedFile != null
                                    ? 'Archivo seleccionado: ${_pickedFile!.name}'
                                    : ' Haz clic para adjuntar PDF',
                                style: GoogleFonts.poppins(
                                  color:
                                      _pickedFile != null
                                          ? Colors.green.shade700
                                          : Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_pickedFile == null)
                                Text(
                                  '(Opcional) El archivo se subirá al guardar el documento',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveDocumento,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            isEditing
                                ? 'Actualizar Documento'
                                : 'Registrar Documento',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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

  void _showSnack(String message, {Color background = Colors.blue}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(
              background == Colors.green
                  ? Icons.check_circle
                  : background == Colors.red
                  ? Icons.error
                  : background == Colors.orange
                  ? Icons.warning
                  : Icons.info,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
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
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade800,
          ),
        ),
        const Divider(),
      ],
    );
  }
}
