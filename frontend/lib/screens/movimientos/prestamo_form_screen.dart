import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/documento.dart';
import '../../models/movimiento.dart';
import '../../models/usuario.dart';
import '../../providers/auth_provider.dart';
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
  DateTime _fechaInicio = DateTime.now();
  /// Fecha límite de devolución del préstamo (obligatoria).
  DateTime _fechaLimiteDevolucion = DateTime.now().add(const Duration(days: 7));
  bool _isLoadingCatalogos = true;
  bool _isSubmitting = false;

  /// Áreas mostradas en el combo (filtradas/renombradas).
  List<Map<String, dynamic>> get _areasVisibles {
    return _areas
        .where((a) {
          final nombre = (a['nombre'] as String? ?? '').toLowerCase();
          // Quitar áreas que no deberían aparecer en el formulario
          if (nombre.contains('recursos humanos')) return false;
          if (nombre.contains('archivo')) return false;
          return true;
        })
        .map((a) {
          final nombre = a['nombre'] as String? ?? '';
          String nuevoNombre = nombre;
          // Renombrar Administración -> Administración de Documentos
          if (nombre.toLowerCase() == 'administración') {
            nuevoNombre = 'Administración de Documentos';
          }
          return {
            ...a,
            'nombre': nuevoNombre,
          };
        })
        .toList();
  }

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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final busqueda = BusquedaDocumentoDTO(estado: 'Activo', pageSize: 200);
      final resDoc = await docService.buscar(busqueda);
      var users = await userService.getAll(incluirInactivos: false);
      final areas = await catService.getAreas();

      // Si es Administrador de Documentos, filtrar para que no se pueda seleccionar a sí mismo
      if (authProvider.user?['rol'] == 'AdministradorDocumentos') {
        final currentUserId = authProvider.userId;
        users = users.where((u) => u.id != currentUserId).toList();
      }

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
    if (_fechaLimiteDevolucion.isBefore(_fechaInicio)) {
      AppAlert.warning(context, 'Fecha inválida', 'La fecha límite de devolución debe ser igual o posterior a la fecha de inicio.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final obs = _observacionesController.text.trim().isEmpty ? null : _observacionesController.text.trim();
      final movimientoService = Provider.of<MovimientoService>(context, listen: false);
      await movimientoService.create(CreateMovimientoDTO(
        documentoId: _documentoSeleccionado!.id,
        tipoMovimiento: 'Salida',
        areaOrigenId: _documentoSeleccionado!.areaOrigenId,
        areaDestinoId: _areaDestinoId,
        usuarioId: _usuarioResponsable!.id,
        observaciones: obs,
        fechaLimiteDevolucion: _fechaLimiteDevolucion,
      ));

      if (mounted) {
        final vencStr = DateFormat('dd/MM/yyyy').format(_fechaLimiteDevolucion);
        await AppAlert.success(
          context,
          'Préstamo registrado',
          'El documento "${_documentoSeleccionado!.codigo}" ha sido registrado como prestado. Fecha límite de devolución: $vencStr.',
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
                    _buildDocumentoAutocomplete(theme),
                    const SizedBox(height: 24),
                    Text(
                      'Responsable del préstamo',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    // Mensaje informativo para Administrador de Documentos
                    if (Provider.of<AuthProvider>(context, listen: false).user?['rol'] == 'AdministradorDocumentos') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Como Administrador de Documentos, debes asignar el préstamo a un Contador o Gerente.',
                                style: GoogleFonts.inter(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                      'Fecha de inicio del préstamo',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                  // La fecha de inicio del préstamo siempre es la fecha actual
                  // y no debe poder modificarse manualmente.
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Fecha inicio (hoy)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: const Icon(Icons.lock_clock_outlined, size: 20),
                    ),
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(_fechaInicio),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ),
                    const SizedBox(height: 24),
                    Text(
                      'Fecha límite de préstamo',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _fechaLimiteDevolucion,
                          firstDate: _fechaInicio,
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (picked != null) setState(() => _fechaLimiteDevolucion = picked);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Fecha límite de devolución',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(_fechaLimiteDevolucion),
                          style: GoogleFonts.inter(fontSize: 14),
                        ),
                      ),
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
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('— Sin especificar —'),
                        ),
                        ..._areasVisibles.map((a) {
                          final id = a['id'] as int?;
                          final nombre = a['nombre'] as String? ?? 'Área';
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(nombre),
                          );
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

  /// Campo de búsqueda para seleccionar documento (con filtro por texto).
  Widget _buildDocumentoAutocomplete(ThemeData theme) {
    String display(Documento d) =>
        '${d.codigo} - ${d.tipoDocumentoNombre ?? "Sin tipo"}';

    return Autocomplete<Documento>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.toLowerCase().trim();
        if (query.isEmpty) return _documentos;
        return _documentos.where((d) {
          final codigo = d.codigo.toLowerCase();
          final tipo = (d.tipoDocumentoNombre ?? '').toLowerCase();
          final desc = (d.descripcion ?? '').toLowerCase();
          return codigo.contains(query) ||
              tipo.contains(query) ||
              desc.contains(query);
        });
      },
      displayStringForOption: display,
      initialValue: TextEditingValue(
        text: _documentoSeleccionado != null ? display(_documentoSeleccionado!) : '',
      ),
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        // Mantener sincronizado el texto si ya hay un documento seleccionado
        if (_documentoSeleccionado != null &&
            textEditingController.text.isEmpty) {
          textEditingController.text = display(_documentoSeleccionado!);
        }

        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Documento',
            hintText: 'Buscar por código o nombre…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
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
          style: GoogleFonts.inter(fontSize: 14),
          onFieldSubmitted: (_) => onFieldSubmitted(),
          validator: (_) =>
              _documentoSeleccionado == null ? FormValidators.seleccioneOpcion : null,
        );
      },
      onSelected: (Documento d) {
        setState(() {
          _documentoSeleccionado = d;
        });
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300, minWidth: 300),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final d = list[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      d.codigo,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      d.tipoDocumentoNombre ?? 'Sin tipo',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    onTap: () => onSelected(d),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
