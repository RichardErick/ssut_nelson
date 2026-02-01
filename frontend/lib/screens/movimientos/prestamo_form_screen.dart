import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/documento.dart';
import '../../models/movimiento.dart';
import '../../models/usuario.dart';
import '../../services/catalogo_service.dart';
import '../../services/documento_service.dart';
import '../../services/movimiento_service.dart';
import '../../services/usuario_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helper.dart';
import '../../utils/form_validators.dart';
import '../../widgets/app_alert.dart';

/// Pantalla para registrar un préstamo (movimiento tipo Salida).
class PrestamoFormScreen extends StatefulWidget {
  const PrestamoFormScreen({super.key});

  @override
  State<PrestamoFormScreen> createState() => _PrestamoFormScreenState();
}

class _PrestamoFormScreenState extends State<PrestamoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _observacionesController = TextEditingController();

  List<Documento> _documentos = [];
  List<Usuario> _usuarios = [];
  List<Map<String, dynamic>> _areas = [];
  Documento? _documentoSeleccionado;
  Usuario? _usuarioResponsable;
  int? _areaDestinoId;
  bool _isLoadingCatalogos = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCatalogos();
  }

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogos() async {
    setState(() => _isLoadingCatalogos = true);
    try {
      final docService = Provider.of<DocumentoService>(context, listen: false);
      final userService = Provider.of<UsuarioService>(context, listen: false);
      final catService = Provider.of<CatalogoService>(context, listen: false);

      final busqueda = BusquedaDocumentoDTO(estado: 'Activo', pageSize: 200);
      final resDoc = await docService.buscar(busqueda);
      final users = await userService.getAll(incluirInactivos: false);
      final areas = await catService.getAreas();

      if (mounted) {
        setState(() {
          _documentos = resDoc.items;
          _usuarios = users;
          _areas = areas;
          _isLoadingCatalogos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCatalogos = false);
        AppAlert.error(
          context,
          'Error al cargar datos',
          ErrorHelper.getErrorMessage(e),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_documentoSeleccionado == null) {
      AppAlert.warning(context, 'Falta información', 'Seleccione un documento a prestar.');
      return;
    }
    if (_usuarioResponsable == null) {
      AppAlert.warning(context, 'Falta información', 'Seleccione el usuario responsable del préstamo.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final movimientoService = Provider.of<MovimientoService>(context, listen: false);
      await movimientoService.create(CreateMovimientoDTO(
        documentoId: _documentoSeleccionado!.id,
        tipoMovimiento: 'Salida',
        areaOrigenId: _documentoSeleccionado!.areaOrigenId,
        areaDestinoId: _areaDestinoId,
        usuarioId: _usuarioResponsable!.id,
        observaciones: _observacionesController.text.trim().isEmpty ? null : _observacionesController.text.trim(),
      ));

      if (mounted) {
        await AppAlert.success(
          context,
          'Préstamo registrado',
          'El documento "${_documentoSeleccionado!.codigo}" ha sido registrado como prestado. El estado del documento se actualizó a Prestado.',
          buttonText: 'Entendido',
        );
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppAlert.error(
          context,
          'Error al registrar préstamo',
          ErrorHelper.getErrorMessage(e),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Registrar préstamo', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: _isLoadingCatalogos
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Cargando documentos y usuarios...', style: GoogleFonts.inter(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Documento a prestar (solo disponibles)',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Documento>(
                      value: _documentoSeleccionado,
                      decoration: InputDecoration(
                        labelText: 'Documento',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red.shade600, width: 2),
                        ),
                        errorStyle: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                      items: _documentos
                          .map((d) => DropdownMenuItem(
                                value: d,
                                child: Text('${d.codigo} - ${d.tipoDocumentoNombre ?? "Sin tipo"}', overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (d) => setState(() => _documentoSeleccionado = d),
                      validator: (v) => v == null ? FormValidators.seleccioneOpcion : null,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Responsable del préstamo',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Usuario>(
                      value: _usuarioResponsable,
                      decoration: InputDecoration(
                        labelText: 'Usuario responsable',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.red.shade600, width: 2),
                        ),
                        errorStyle: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                      items: _usuarios
                          .map((u) => DropdownMenuItem(
                                value: u,
                                child: Text('${u.nombreCompleto} (${u.nombreUsuario})', overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (u) => setState(() => _usuarioResponsable = u),
                      validator: (v) => v == null ? FormValidators.seleccioneOpcion : null,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Área destino (opcional)',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _areaDestinoId,
                      decoration: InputDecoration(
                        labelText: 'Área destino',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                      items: [
                        const DropdownMenuItem<int>(value: null, child: Text('— Sin especificar —')),
                        ..._areas.map((a) {
                          final id = a['id'] as int?;
                          final nombre = a['nombre'] as String? ?? 'Área';
                          return DropdownMenuItem<int>(value: id, child: Text(nombre));
                        }),
                      ],
                      onChanged: (v) => setState(() => _areaDestinoId = v),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _observacionesController,
                      decoration: InputDecoration(
                        labelText: 'Observaciones',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
                      label: Text(_isSubmitting ? 'Registrando...' : 'Registrar préstamo'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.colorExito,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
