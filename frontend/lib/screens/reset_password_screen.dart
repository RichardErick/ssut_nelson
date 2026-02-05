import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../utils/error_helper.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_container.dart';
import 'login_screen.dart';

/// Modo de restablecer: por enlace (token en URL) o por código (email + código 6 dígitos).
enum ResetPasswordMode { link, code }

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.resetMode = ResetPasswordMode.link,
    this.email,
  });

  final ResetPasswordMode resetMode;
  final String? email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _codeController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _success = false;

  bool get _isCodeMode => widget.resetMode == ResetPasswordMode.code && widget.email != null;

  String? _getToken() {
    if (_isCodeMode) return null;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) return args;
    if (args is Map && args['token'] != null) return args['token'] as String?;
    final q = Uri.base.queryParameters['token'];
    if (q != null && q.isNotEmpty) return q;
    final fragment = Uri.base.fragment;
    if (fragment.isNotEmpty && fragment.contains('reset-password')) {
      final idx = fragment.indexOf('?');
      if (idx != -1 && idx + 1 < fragment.length) {
        final params = Uri.splitQueryString(fragment.substring(idx + 1));
        return params['token'];
      }
    }
    return null;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isLoading || _success) return;
    final token = _getToken();
    final code = _codeController.text.trim();
    final email = widget.email?.trim();

    if (_isCodeMode) {
      if (email == null || email.isEmpty || code.length != 6) {
        if (!_formKey.currentState!.validate()) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ingresa el código de 6 dígitos que recibiste por correo.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enlace inválido o sin token. Solicita uno nuevo desde "¿Olvidaste tu contraseña?".'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final newPassword = _passwordController.text;

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = <String, dynamic>{'newPassword': newPassword};
      if (_isCodeMode) {
        data['code'] = code;
        data['email'] = email;
      } else {
        data['token'] = token;
      }
      await api.post('auth/reset-password', data: data);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _success = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Contraseña actualizada. Ya puedes iniciar sesión.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
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
    final token = _getToken();
    final hasToken = token != null && token.isNotEmpty;
    final canSubmit = _isCodeMode || hasToken;

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
                        'Nueva contraseña',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      if (!canSubmit && !_isCodeMode)
                        Text(
                          'Este enlace no tiene token o ha expirado. Solicita uno nuevo desde la pantalla de inicio de sesión.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        )
                      else if (_success)
                        Text(
                          'Tu contraseña se actualizó correctamente. Inicia sesión con tu nueva contraseña.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        )
                      else if (_isCodeMode)
                        Text(
                          'Ingresa el código de 6 dígitos que recibiste por correo y tu nueva contraseña.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        )
                      else
                        Text(
                          'Elige una contraseña nueva (mínimo 6 caracteres).',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      if (canSubmit && !_success) ...[
                        if (_isCodeMode) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.email_outlined, size: 20, color: Colors.white70),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    widget.email!,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              labelText: 'Código de 6 dígitos',
                              hintText: '000000',
                              prefixIcon: const Icon(Icons.pin_rounded),
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.08),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              labelStyle: TextStyle(color: Colors.white70),
                              hintStyle: TextStyle(color: Colors.white54),
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              letterSpacing: 8,
                            ),
                            validator: (v) {
                              final t = (v ?? '').trim();
                              if (t.length != 6) return 'El código debe tener 6 dígitos';
                              if (!RegExp(r'^\d{6}$').hasMatch(t)) return 'Solo números';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'Nueva contraseña',
                            hintText: 'Mínimo 6 caracteres',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white70,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
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
                            if (v == null || v.isEmpty) return 'Ingresa la nueva contraseña';
                            if (v.length < 6) return 'Mínimo 6 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmController,
                          obscureText: _obscureConfirm,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'Confirmar contraseña',
                            hintText: 'Repite la contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white70,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
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
                            if (v != _passwordController.text) {
                              return 'Las contraseñas no coinciden';
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
                              : const Text('Restablecer contraseña'),
                        ),
                      ],
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        },
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
