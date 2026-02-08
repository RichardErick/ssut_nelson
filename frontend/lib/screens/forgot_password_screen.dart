import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../utils/error_helper.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_container.dart';

/// Opciones de recuperación de contraseña sin correo ni servidores externos.
enum _RecoveryOption { administrador, codigo, preguntaSecreta }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  _RecoveryOption _option = _RecoveryOption.administrador;

  // Formulario código de recuperación
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitCodigo() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.post('auth/reset-password-by-code', data: {
        'username': _usernameController.text.trim(),
        'code': _codeController.text.trim(),
        'newPassword': _passwordController.text.trim(),
      });
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Contraseña actualizada. Ya puedes iniciar sesión.'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelper.getErrorMessage(e)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: GlassContainer(
                blur: 20,
                opacity: 0.12,
                borderRadius: 24,
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.lock_reset_rounded,
                      size: 56,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Recuperar contraseña',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Elige cómo quieres recuperar el acceso (sin correo ni servidores externos).',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Opción 1: Administrador
                    _OptionTile(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Que un administrador la restablezca',
                      subtitle: 'Un admin puede cambiar tu contraseña desde Gestión de Usuarios (Editar usuario → Nueva contraseña). Contacta a tu administrador.',
                      selected: _option == _RecoveryOption.administrador,
                      onTap: () => setState(() => _option = _RecoveryOption.administrador),
                    ),
                    const SizedBox(height: 10),

                    // Opción 2: Código de recuperación
                    _OptionTile(
                      icon: Icons.pin_rounded,
                      title: 'Código de recuperación',
                      subtitle: 'Si un administrador te dio un código de 6 dígitos, ingresa tu usuario, el código y tu nueva contraseña aquí.',
                      selected: _option == _RecoveryOption.codigo,
                      onTap: () => setState(() => _option = _RecoveryOption.codigo),
                    ),
                    const SizedBox(height: 10),

                    // Opción 3: Pregunta secreta (próximamente)
                    _OptionTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Pregunta secreta',
                      subtitle: 'Próximamente: podrás configurar una pregunta secreta en tu perfil para recuperar tu contraseña sin depender del administrador.',
                      selected: _option == _RecoveryOption.preguntaSecreta,
                      onTap: () => setState(() => _option = _RecoveryOption.preguntaSecreta),
                    ),

                    if (_option == _RecoveryOption.administrador) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Text(
                          'Pasos: Gestión de Usuarios y Roles → buscar tu usuario → Editar → Nueva contraseña → Guardar. Comunícate con tu administrador o responsable del sistema SSUT.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],

                    if (_option == _RecoveryOption.codigo) ...[
                      const SizedBox(height: 20),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTextField(
                              controller: _usernameController,
                              label: 'Usuario',
                              hint: 'Nombre de usuario',
                              icon: Icons.person_outline_rounded,
                              validator: (v) {
                                if ((v ?? '').trim().isEmpty) return 'Ingresa tu usuario';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _codeController,
                              label: 'Código de 6 dígitos',
                              hint: 'Código que te dio el administrador',
                              icon: Icons.pin_rounded,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              validator: (v) {
                                final t = (v ?? '').trim();
                                if (t.isEmpty) return 'Ingresa el código';
                                if (t.length != 6 || int.tryParse(t) == null) return 'Código de 6 dígitos';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Nueva contraseña',
                              hint: 'Mínimo 6 caracteres',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              validator: (v) {
                                if ((v ?? '').trim().length < 6) return 'Mínimo 6 caracteres';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            _buildTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirmar contraseña',
                              hint: 'Repite la nueva contraseña',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscureConfirm,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                              validator: (v) {
                                if ((v ?? '').trim() != _passwordController.text.trim()) return 'No coinciden';
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _isLoading ? null : _submitCodigo,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Restablecer contraseña'),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_option == _RecoveryOption.preguntaSecreta) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Text(
                          'Esta opción estará disponible cuando se habilite la configuración de pregunta secreta en tu perfil. Por ahora usa "Que un administrador la restablezca" o "Código de recuperación".',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                      label: const Text('Volver al inicio de sesión'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    int? maxLength,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLength: maxLength,
      enabled: !_isLoading,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.white70, size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: TextStyle(color: Colors.white54),
      ),
      style: const TextStyle(color: Colors.white),
      validator: validator,
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? Colors.blue.shade300 : Colors.white24,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 28,
                color: selected ? Colors.blue.shade200 : Colors.white70,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, size: 22, color: Colors.blue.shade300),
            ],
          ),
        ),
      ),
    );
  }
}
