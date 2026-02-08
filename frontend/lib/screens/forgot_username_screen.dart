import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../utils/error_helper.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_container.dart';

/// Pantalla dedicada: "No recuerdo mi usuario". Envía solicitud a administradores; ellos reciben notificación y pueden generar código o indicar el usuario.
class ForgotUsernameScreen extends StatefulWidget {
  const ForgotUsernameScreen({super.key});

  @override
  State<ForgotUsernameScreen> createState() => _ForgotUsernameScreenState();
}

class _ForgotUsernameScreenState extends State<ForgotUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.post('auth/solicitud-recuperacion', data: {
        'tipo': 'username',
        'email': _emailController.text.trim(),
      });
      if (mounted) {
        setState(() {
          _isLoading = false;
          _sent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Si tu correo está registrado, un administrador recibirá la solicitud y te contactará o generará un código de recuperación.',
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
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
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GlassContainer(
                    blur: 20,
                    opacity: 0.12,
                    borderRadius: 24,
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.person_search_rounded, size: 48, color: Colors.white.withOpacity(0.9)),
                        const SizedBox(height: 12),
                        Text(
                          'No recuerdo mi usuario',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ingresa el correo con el que te registraste. Los administradores recibirán una notificación y podrán indicarte tu usuario o generarte un código de recuperación.',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (_sent)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.green.shade300, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Solicitud enviada. Revisa tu bandeja de notificaciones del administrador o espera a que te contacten.',
                                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  enabled: !_isLoading,
                                  decoration: InputDecoration(
                                    labelText: 'Correo institucional',
                                    hintText: 'ejemplo@institucion.edu',
                                    prefixIcon: Icon(Icons.email_outlined, color: Colors.white70, size: 22),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    labelStyle: const TextStyle(color: Colors.white70),
                                    hintStyle: TextStyle(color: Colors.white54),
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                  validator: (v) {
                                    final t = (v ?? '').trim();
                                    if (t.isEmpty) return 'Ingresa tu correo';
                                    if (!t.contains('@')) return 'Correo no válido';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                FilledButton(
                                  onPressed: _isLoading ? null : _submit,
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
                                      : const Text('Enviar solicitud al administrador'),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                          label: const Text('Volver a opciones'),
                          style: TextButton.styleFrom(foregroundColor: Colors.white70),
                        ),
                      ],
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
}
