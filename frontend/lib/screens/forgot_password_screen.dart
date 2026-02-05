import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../utils/error_helper.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_container.dart';
import 'reset_password_screen.dart';

/// Método de recuperación: enlace por correo, código por correo, o contactar administrador.
enum _RecoveryMethod { link, code, admin }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;
  _RecoveryMethod _method = _RecoveryMethod.link;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_method == _RecoveryMethod.admin) return;
    if (_isLoading || _sent) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final method = _method == _RecoveryMethod.code ? 'code' : 'link';

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.post('auth/forgot-password', data: {
        'email': email,
        'method': method,
      });
      final body = res.data is Map ? res.data as Map<String, dynamic> : null;
      final message = body?['message'] as String? ??
          (method == 'code'
              ? 'Revisa tu correo para obtener el código.'
              : 'Revisa tu correo para restablecer la contraseña.');

      if (mounted) {
        setState(() {
          _isLoading = false;
          _sent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green.shade700,
          ),
        );
        if (method == 'code') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(
                resetMode: ResetPasswordMode.code,
                email: email,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final msg = ErrorHelper.getErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showForm = _method != _RecoveryMethod.admin && !_sent;
    final submitLabel = _method == _RecoveryMethod.code
        ? 'Enviar código a mi correo'
        : 'Enviar enlace a mi correo';

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
                child: Form(
                  key: _formKey,
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
                        'Elige cómo quieres recuperar el acceso a tu cuenta.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      // Opciones de método
                      _MethodTile(
                        icon: Icons.link_rounded,
                        title: 'Enlace por correo',
                        subtitle: 'Recibir un enlace en tu correo para restablecer la contraseña.',
                        selected: _method == _RecoveryMethod.link,
                        onTap: () => setState(() => _method = _RecoveryMethod.link),
                      ),
                      const SizedBox(height: 10),
                      _MethodTile(
                        icon: Icons.pin_rounded,
                        title: 'Código por correo',
                        subtitle: 'Recibir un código de 6 dígitos en tu correo e ingresarlo aquí.',
                        selected: _method == _RecoveryMethod.code,
                        onTap: () => setState(() => _method = _RecoveryMethod.code),
                      ),
                      const SizedBox(height: 10),
                      _MethodTile(
                        icon: Icons.admin_panel_settings_rounded,
                        title: 'Contactar administrador',
                        subtitle: 'Si no tienes acceso al correo, pide a un administrador que restablezca tu contraseña.',
                        selected: _method == _RecoveryMethod.admin,
                        onTap: () => setState(() => _method = _RecoveryMethod.admin),
                      ),
                      if (_method == _RecoveryMethod.admin) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white24,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Un administrador del sistema puede restablecer tu contraseña desde la sección de usuarios. Comunícate con tu área de sistemas o con el responsable del sistema SSUT.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      if (showForm) ...[
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'Correo electrónico',
                            hintText: 'ej. usuario@ssut.gob.bo',
                            prefixIcon: const Icon(Icons.email_outlined),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelStyle: TextStyle(color: Colors.white70),
                            hintStyle: TextStyle(color: Colors.white54),
                          ),
                          style: const TextStyle(color: Colors.white),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Ingresa tu correo';
                            if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(t)) {
                              return 'Correo no válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(submitLabel),
                        ),
                      ] else if (_sent && _method == _RecoveryMethod.link) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Si el correo está registrado, recibirás un enlace en unos minutos. Revisa también la carpeta de spam.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Volver al inicio de sesión',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
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
