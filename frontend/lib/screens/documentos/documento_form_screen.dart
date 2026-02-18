import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/anexo.dart';
import '../../models/carpeta.dart';
import '../../models/documento.dart';
import '../../models/usuario.dart';
import '../../services/anexo_service.dart';
import '../../services/carpeta_service.dart';
import '../../services/catalogo_service.dart';
import '../../services/documento_service.dart';
import '../../services/usuario_service.dart';
import '../../utils/form_validators.dart';
import '../../widgets/app_alert.dart';

class DocumentoFormScreen extends StatefulWidget {
  final Documento? documento;
  final int? initialCarpetaId;

  const DocumentoFormScreen({super.key, this.documento, this.initialCarpetaId});

  @override
  State<DocumentoFormScreen> createState() => _DocumentoFormScreenState();
}

class _DocumentoFormScreenState extends State<DocumentoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  bool _isLoading = true;

  // Controladores
  final _numeroCorrelativoController = TextEditingController();
  final _gestionController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _ubicacionFisicaController = TextEditingController();
  final _numeroEstanteController = TextEditingController(); // SSUT: número de estante

  // Estado del formulario
  DateTime _fechaDocumento = DateTime.now();
  int? _tipoDocumentoId;
  int? _areaOrigenId;
  int? _responsableId;
  int? _carpetaId;
  int _nivelConfidencialidad = 1;
  String _estadoDocumento = 'Activo'; // SSUT: visible en formulario (año, estado y nivel)
  bool _bloquearTipoDocumento = false;
  PlatformFile? _pickedFile;

  static const List<String> _estadosDocumento = ['Activo', 'Prestado', 'Archivado', 'Inactivo'];

  /// Anexos existentes del documento (solo en modo edición). Se cargan al abrir el formulario.
  List<Anexo> _anexosExistentes = [];
  bool _anexosExistentesLoaded = false;

  /// Error del servidor para el campo N° Correlativo (código). Se muestra en rojo debajo del campo.
  String? _numeroCorrelativoError;

  /// Sugerencia de número sucesivo
  int? _siguienteCorrelativoSugerido;
  bool _obteniendoCorrelativo = false;

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
      _loadAnexosExistentes();
    } else {
      _gestionController.text = DateTime.now().year.toString();
      _carpetaId = widget.initialCarpetaId;
    }
  }

  Future<void> _loadAnexosExistentes() async {
    if (widget.documento == null) return;
    try {
      final service = Provider.of<AnexoService>(context, listen: false);
      final list = await service.listarPorDocumento(widget.documento!.id);
      if (mounted) {
        setState(() {
          _anexosExistentes = list;
          _anexosExistentesLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _anexosExistentes = [];
          _anexosExistentesLoaded = true;
        });
      }
    }
  }

  /// Parsea ubicación física: formato "Estante: X, Caja/resto" para extraer número de estante.
  void _parseUbicacionEstante(String? ubicacionFisica) {
    if (ubicacionFisica == null || ubicacionFisica.isEmpty) {
      _ubicacionFisicaController.text = '';
      _numeroEstanteController.text = '';
      return;
    }
    if (ubicacionFisica.toLowerCase().startsWith('estante:')) {
      final parts = ubicacionFisica.split(',');
      _numeroEstanteController.text =
          parts[0].replaceFirst(RegExp(r'^estante:\s*', caseSensitive: false), '').trim();
      _ubicacionFisicaController.text =
          parts.length > 1 ? parts.sublist(1).join(',').trim() : '';
    } else {
      _numeroEstanteController.text = '';
      _ubicacionFisicaController.text = ubicacionFisica;
    }
  }

  /// Construye ubicación física para enviar: Estante + Caja/resto.
  String _buildUbicacionFisica() {
    final estante = _numeroEstanteController.text.trim();
    final resto = _ubicacionFisicaController.text.trim();
    if (estante.isEmpty && resto.isEmpty) return '';
    if (estante.isEmpty) return resto;
    if (resto.isEmpty) return 'Estante: $estante';
    return 'Estante: $estante, $resto';
  }

  void _initFormData(Documento doc) {
    _numeroCorrelativoController.text = doc.numeroCorrelativo;
    _gestionController.text = doc.gestion;
    _descripcionController.text = doc.descripcion ?? '';
    _parseUbicacionEstante(doc.ubicacionFisica);
    _fechaDocumento = doc.fechaDocumento;
    _tipoDocumentoId = doc.tipoDocumentoId;
    _areaOrigenId = doc.areaOrigenId;
    _responsableId = doc.responsableId;
    _carpetaId = doc.carpetaId;
    _nivelConfidencialidad = doc.nivelConfidencialidad;
    _estadoDocumento = doc.estado;
  }

  String? _buildHelperText() {
    if (_numeroCorrelativoError != null) return null;
    
    String base = 'Máximo 10 dígitos, solo números';
    if (_carpetaId != null) {
      final carpeta = _carpetas.where((c) => c.id == _carpetaId).firstOrNull;
      if (carpeta != null && carpeta.rangoInicio != null && carpeta.rangoFin != null) {
        String texto = '$base\nRango permitido: ${carpeta.rangoInicio} al ${carpeta.rangoFin}';
        if (_siguienteCorrelativoSugerido != null && widget.documento == null) {
          texto += '\nSugerido (Sucesivo): $_siguienteCorrelativoSugerido';
        }
        return texto;
      }
    }
    return base;
  }

  Future<void> _obtenerSiguienteCorrelativo() async {
    if (_carpetaId == null || widget.documento != null) return;

    setState(() => _obteniendoCorrelativo = true);

    try {
      final service = Provider.of<DocumentoService>(context, listen: false);
      final carpeta = _carpetas.where((c) => c.id == _carpetaId).firstOrNull;
      
      if (carpeta == null) return;

      // Buscar documentos en esta carpeta para ver el último número
      final busqueda = BusquedaDocumentoDTO(
        carpetaId: _carpetaId,
        page: 1,
        pageSize: 1,
        orderBy: 'numeroCorrelativo',
        orderDirection: 'DESC',
      );

      final resp = await service.buscar(busqueda);
      
      int siguiente = carpeta.rangoInicio ?? 1;

      if (resp.items.isNotEmpty) {
        final ultimoNum = int.tryParse(resp.items.first.numeroCorrelativo);
        if (ultimoNum != null) {
          siguiente = ultimoNum + 1;
        }
      }

      if (mounted) {
        setState(() {
          _siguienteCorrelativoSugerido = siguiente;
          // Si el campo está vacío, lo sugerimos automáticamente
          if (_numeroCorrelativoController.text.isEmpty) {
            _numeroCorrelativoController.text = siguiente.toString();
          }
          _obteniendoCorrelativo = false;
        });
      }
    } catch (e) {
      print('Error al sugerir correlativo: $e');
      if (mounted) {
        setState(() => _obteniendoCorrelativo = false);
      }
    }
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

      final incluirInactivos = widget.documento != null;
      final usuariosFuture = usuarioService.getAll(incluirInactivos: incluirInactivos);
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
          final todosUsuarios = results[0] as List<Usuario>;
          _usuarios = incluirInactivos
              ? todosUsuarios
              : todosUsuarios.where((u) => u.activo).toList();
          _carpetas = results[1] as List<Carpeta>;
          _areas = (results[2] as List<Map<String, dynamic>>);
          
          final todosTipos = (results[3] as List<Map<String, dynamic>>);
          // Filtrar tipos no deseados por SSUT
          _tiposDocumento = todosTipos.where((t) {
            final nombre = t['nombre'].toString().toLowerCase();
            return !nombre.contains('memorandum') && 
                   !nombre.contains('oficio') && 
                   !nombre.contains('resolucion');
          }).toList();

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
          
          _verificarTipoPorCarpeta();
          _isLoading = false;
        });

        // Una vez cargadas las carpetas, si tenemos una seleccionada, sugerimos el correlativo
        if (_carpetaId != null) {
          _obtenerSiguienteCorrelativo();
        }
      }
    } catch (e) {
      if (mounted) {
        print('Error cargando datos auxiliares: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _verificarTipoPorCarpeta() {
    if (_carpetaId == null) {
      if (mounted) setState(() => _bloquearTipoDocumento = false);
      return;
    }

    final carpeta = _carpetas.where((c) => c.id == _carpetaId).firstOrNull;

    if (carpeta != null) {
      // Priorizar el campo 'tipo', si no usar el 'nombre' (que en SSUT es el tipo)
      final searchType = (carpeta.tipo != null && carpeta.tipo!.isNotEmpty) 
          ? carpeta.tipo! 
          : carpeta.nombre;

      final tipoDoc = _tiposDocumento.where((t) {
        final nombreTipo = t['nombre'].toString().toLowerCase().trim();
        final matchType = searchType.toLowerCase().trim();
        return nombreTipo == matchType || 
               nombreTipo.contains(matchType) || 
               matchType.contains(nombreTipo);
      }).firstOrNull;

      if (tipoDoc != null) {
        if (mounted) {
          setState(() {
            _tipoDocumentoId = tipoDoc['id'];
            _bloquearTipoDocumento = true;
          });
        }
      } else {
        if (mounted) setState(() => _bloquearTipoDocumento = false);
      }
    } else {
      if (mounted) setState(() => _bloquearTipoDocumento = false);
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
    if (!_formKey.currentState!.validate()) {
      setState(() => _autoValidateMode = AutovalidateMode.always);
      return;
    }

    if (_tipoDocumentoId == null) {
      AppAlert.warning(
        context,
        'Falta información',
        'Debe seleccionar un tipo de documento.',
        buttonText: 'Entendido',
      );
      return;
    }
    if (_areaOrigenId == null) {
      AppAlert.warning(
        context,
        'Falta información',
        'Debe seleccionar un área de origen.',
        buttonText: 'Entendido',
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
          ubicacionFisica: _buildUbicacionFisica(),
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
        // Actualizar: si un dropdown quedó null porque el valor no estaba en la lista, conservar el del documento
        final doc = widget.documento!;
        final dto = UpdateDocumentoDTO(
          numeroCorrelativo: _numeroCorrelativoController.text,
          tipoDocumentoId: _tipoDocumentoId ?? doc.tipoDocumentoId,
          areaOrigenId: _areaOrigenId ?? doc.areaOrigenId,
          gestion: _gestionController.text,
          fechaDocumento: _fechaDocumento,
          descripcion: _descripcionController.text,
          responsableId: _responsableId ?? doc.responsableId,
          ubicacionFisica: _buildUbicacionFisica(),
          carpetaId: _carpetaId ?? doc.carpetaId,
          nivelConfidencialidad: _nivelConfidencialidad,
          estado: _estadoDocumento,
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
        String? serverMessage;
        if (e is DioException &&
            e.response?.statusCode == 400 &&
            e.response?.data != null) {
          final data = e.response!.data;
          serverMessage =
              (data is Map && data['message'] != null)
                  ? data['message'].toString()
                  : null;
          if (serverMessage != null &&
              (serverMessage.toLowerCase().contains('código') ||
                  serverMessage.toLowerCase().contains('codigo') ||
                  serverMessage.toLowerCase().contains('correlativo') ||
                  serverMessage.contains('Formato de código'))) {
            setState(() => _numeroCorrelativoError = serverMessage);
            _showSnack(
              'Revise el campo N° Correlativo',
              background: Colors.orange,
            );
            return;
          }
        }
        setState(() => _numeroCorrelativoError = null);
        AppAlert.error(
          context,
          'No se pudo guardar',
          e.toString().replaceFirst('Exception: ', ''),
          buttonText: 'Entendido',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                      _buildSectionTitle('Información del Documento'),
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

                      // Tipo de Documento (Egreso/Ingreso, etc)
                      if (_bloquearTipoDocumento)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 20, color: Colors.blue.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tipo de Documento',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _tiposDocumento.firstWhere(
                                        (t) => t['id'] == _tipoDocumentoId,
                                        orElse: () => {'nombre': 'Cargando...'},
                                      )['nombre'],
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<int>(
                          value: _tipoDocumentoId,
                          decoration: _inputDecoration('Tipo de Documento'),
                          items: _tiposDocumento.map((t) {
                            return DropdownMenuItem<int>(
                              value: t['id'],
                              child: Text(t['nombre']),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _tipoDocumentoId = v),
                          validator: (v) => v == null ? 'Seleccione el tipo' : null,
                        ),
                      const SizedBox(height: 16),

                      // 1. Número comprobante(s) — máximo 10 dígitos, solo números
                      TextFormField(
                        controller: _numeroCorrelativoController,
                        decoration: _inputDecoration('Número comprobante(s)').copyWith(
                          errorText: _numeroCorrelativoError,
                          errorStyle: const TextStyle(color: Colors.red),
                          helperText: _buildHelperText(),
                          helperMaxLines: 2,
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        onChanged: (_) {
                          if (_numeroCorrelativoError != null) {
                            setState(() => _numeroCorrelativoError = null);
                          }
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return FormValidators.requerido;
                          }
                          final digits = v.replaceAll(RegExp(r'\D'), '');
                          if (digits.isEmpty) {
                            return 'Solo números';
                          }

                          // Validar rango según carpeta
                          final numVal = int.tryParse(digits);
                          if (numVal != null && _carpetaId != null) {
                            final carpeta = _carpetas.where((c) => c.id == _carpetaId).firstOrNull;
                            if (carpeta != null && carpeta.rangoInicio != null && carpeta.rangoFin != null) {
                              if (numVal < carpeta.rangoInicio! || numVal > carpeta.rangoFin!) {
                                return 'Fuera de rango (${carpeta.rangoInicio}-${carpeta.rangoFin})';
                              }
                            }
                            
                            // Validar que sea sucesivo para SSUT
                            if (_siguienteCorrelativoSugerido != null && widget.documento == null) {
                              if (numVal != _siguienteCorrelativoSugerido) {
                                return 'Debe ser sucesivo. Siguiente esperado: $_siguienteCorrelativoSugerido';
                              }
                            }
                          }

                          if (digits.length > 10) {
                            return 'Máximo 10 dígitos';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2. Responsable
                      DropdownButtonFormField<int>(
                        value:
                            _usuarios.any((u) => u.id == _responsableId)
                                ? _responsableId
                                : null,
                        decoration: _inputDecoration('Responsable'),
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
                            (v) =>
                                v == null ? 'Seleccione un responsable' : null,
                      ),
                      const SizedBox(height: 16),

                      // 3. Área
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<int>(
                              value:
                                  _areas.any((a) => a['id'] == _areaOrigenId)
                                      ? _areaOrigenId
                                      : null,
                              isExpanded: true,
                              decoration: _inputDecoration('Área'),
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
                              validator:
                                  (v) =>
                                      v == null
                                          ? 'Seleccione un área'
                                          : null,
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
                                  (v) =>
                                      v == null ||
                                              v.trim().isEmpty ||
                                              v.trim().length != 4
                                          ? 'Año 4 dígitos (ej: 2025)'
                                          : null,
                              onChanged: (v) {
                                if (v.length == 4) _loadData();
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 4. Fecha
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: _inputDecoration('Fecha'),
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

                      const SizedBox(height: 16),

                      // 5. Nivel
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _nivelConfidencialidad.clamp(1, 5),
                              decoration: _inputDecoration('Nivel'),
                              items: [1, 2, 3, 4, 5]
                                  .map((n) => DropdownMenuItem<int>(
                                        value: n,
                                        child: Text('Nivel $n'),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _nivelConfidencialidad = v ?? 1),
                            ),
                          ),
                          if (widget.documento != null) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _estadosDocumento.contains(_estadoDocumento)
                                    ? _estadoDocumento
                                    : _estadosDocumento.first,
                                decoration: _inputDecoration('Estado'),
                                items: _estadosDocumento
                                    .map((e) => DropdownMenuItem<String>(
                                          value: e,
                                          child: Text(e),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _estadoDocumento = v ?? 'Activo'),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 6. Estante (y ubicación)
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _numeroEstanteController,
                              decoration: _inputDecoration('Estante'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _ubicacionFisicaController,
                              decoration: _inputDecoration('Ubicación (Caja, etc.)'),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 7. Descripción
                      TextFormField(
                        controller: _descripcionController,
                        decoration: _inputDecoration('Descripción'),
                        maxLines: 3,
                        validator:
                            (v) =>
                                v == null || v.trim().isEmpty
                                    ? FormValidators.requerido
                                    : null,
                      ),

                      if (!ocultarSelectorCarpeta) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value:
                              _carpetaId == null ||
                                      _carpetas.any(
                                        (c) => c.id == _carpetaId,
                                      )
                                  ? _carpetaId
                                  : null,
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
                              (v) {
                                setState(() {
                                  _carpetaId = v;
                                  _numeroCorrelativoController.clear();
                                });
                                _verificarTipoPorCarpeta();
                                _obtenerSiguienteCorrelativo();
                              },
                        ),
                      ],

                      const SizedBox(height: 24),

                      // 8. Agregar PDF
                      _buildSectionTitle('Agregar PDF'),
                      const SizedBox(height: 16),
                      _buildArchivoDigitalSection(),

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

  Widget _buildArchivoDigitalSection() {
    final isEditing = widget.documento != null;
    final tienePdfActual = isEditing && _anexosExistentes.isNotEmpty;
    final primerAnexo = tienePdfActual ? _anexosExistentes.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tienePdfActual && !_anexosExistentesLoaded) ...[
          const SizedBox(height: 12),
          const Center(child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )),
        ]
        else if (tienePdfActual && primerAnexo != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.picture_as_pdf, color: Colors.red.shade700, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PDF actual',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        primerAnexo.nombreArchivo,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file, size: 20),
                  label: const Text('Reemplazar PDF'),
                ),
              ],
            ),
          ),
          if (_pickedFile != null) const SizedBox(height: 12),
        ],
        if (_pickedFile != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Nuevo archivo seleccionado',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _pickedFile!.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Cambiar'),
                ),
              ],
            ),
          ),
        ]
        else if (!tienePdfActual) ...[
          InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade300, width: 1.5),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.blue.shade700),
                  const SizedBox(height: 12),
                  Text(
                    'Haz clic para adjuntar PDF',
                    style: GoogleFonts.poppins(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(Opcional) El archivo se subirá al guardar el documento',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.red.shade600, width: 2),
      ),
      errorStyle: TextStyle(color: Colors.red.shade700, fontSize: 13),
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
