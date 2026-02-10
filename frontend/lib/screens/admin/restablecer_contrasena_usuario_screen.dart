import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/usuario.dart';
import '../../services/usuario_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helper.dart';
import '../../widgets/app_alert.dart';

/// Pantalla para que el admin del sistema restablezca la contraseña del usuario
/// que solicitó recuperación. Solo muestra a ese usuario (datos y formulario de nueva contraseña).
class RestablecerContrasenaUsuarioScreen extends StatefulWidget {
  final int userId;

  const RestablecerContrasenaUsuarioScreen({super.key, required this.userId});

  @override
  State<RestablecerContrasenaUsuarioScreen> createState() =>
      _RestablecerContrasenaUsuarioScreenState();
}

class _RestablecerContrasenaUsuarioScreenState
    extends State<RestablecerContrasenaUsuarioScreen> {
  Usuario? _usuario;
  bool _isLoading = true;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();
  final _nuevaContrasenaController = TextEditingController();
  final _repetirContrasenaController = TextEditingController();
  bool _mostrarNuevaContrasena = false;
  bool _mostrarRepetirContrasena = false;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
  }

  @override
  void dispose() {
    _nuevaContrasenaController.dispose();
    _repetirContrasenaController.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuario() async {
    setState(() => _isLoading = true);
    try {
      final service = Provider.of<UsuarioService>(context, listen: false);
      final usuario = await service.getById(widget.userId);
      if (mounted) {
        setState(() {
          _usuario = usuario;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppAlert.error(
          context,
          'Error al cargar',
          ErrorHelper.getErrorMessage(e),
          buttonText: 'Entendido',
        );
      }
    }
  }

  Future<void> _restablecerContrasena() async {
    if (!_formKey.currentState!.validate()) return;
    final nueva = _nuevaContrasenaController.text;
    if (nueva.length < 6) {
      AppAlert.warning(
        context,
        'Contraseña corta',
        'La contraseña debe tener al menos 6 caracteres.',
        buttonText: 'Entendido',
      );
      return;
    }
    if (nueva != _repetirContrasenaController.text) {
      AppAlert.warning(
        context,
        'No coinciden',
        'La nueva contraseña y la repetición no coinciden.',
        buttonText: 'Entendido',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final service = Provider.of<UsuarioService>(context, listen: false);
      await service.updateUsuario(
        widget.userId,
        UpdateUsuarioDTO(password: nueva),
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      _nuevaContrasenaController.clear();
      _repetirContrasenaController.clear();
      await AppAlert.success(
        context,
        'Contraseña actualizada correctamente',
        'La contraseña de ${_usuario?.nombreCompleto ?? ''} (${_usuario?.nombreUsuario ?? ''}) ha sido restablecida. El usuario ya puede iniciar sesión con la nueva contraseña.',
        buttonText: 'Entendido',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppAlert.error(
          context,
          'Error al guardar',
          ErrorHelper.getErrorMessage(e),
          buttonText: 'Entendido',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Restablecer contraseña',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_usuario == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Restablecer contraseña',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_rounded, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Usuario no encontrado',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver'),
              ),
            ],
          ),
        ),
      );
    }

    final u = _usuario!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Restablecer contraseña',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card con datos del usuario (solo este usuario)
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.person_rounded,
                              color: Colors.orange.shade700,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Usuario que solicita recuperación',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  u.nombreCompleto,
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  '${u.nombreUsuario} · ${u.email}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      // Contraseña actual: no se puede mostrar (cifrada)
                      Row(
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Contraseña actual',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        readOnly: true,
                        enabled: false,
                        initialValue: '••••••••••••',
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          suffixIcon: Icon(
                            Icons.lock_rounded,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        ),
                        style: GoogleFonts.inter(letterSpacing: 4),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Por seguridad la contraseña está cifrada y no puede mostrarse. Use el formulario inferior para asignar una nueva.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Nueva contraseña
              Text(
                'Nueva contraseña',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nuevaContrasenaController,
                obscureText: !_mostrarNuevaContrasena,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Mínimo 6 caracteres',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _mostrarNuevaContrasena
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _mostrarNuevaContrasena = !_mostrarNuevaContrasena),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingrese la nueva contraseña';
                  if (v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Text(
                'Repetir nueva contraseña',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _repetirContrasenaController,
                obscureText: !_mostrarRepetirContrasena,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'Repita la nueva contraseña',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _mostrarRepetirContrasena
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _mostrarRepetirContrasena = !_mostrarRepetirContrasena),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Repita la contraseña';
                  if (v != _nuevaContrasenaController.text) return 'No coinciden';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              FilledButton.icon(
                onPressed: _isSaving ? null : _restablecerContrasena,
                icon: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_reset_rounded),
                label: Text(_isSaving ? 'Guardando...' : 'Restablecer contraseña'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.colorExito,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
