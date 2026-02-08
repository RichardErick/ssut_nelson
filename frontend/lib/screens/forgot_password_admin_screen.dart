import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../utils/error_helper.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_container.dart';

/// Pantalla dedicada: "Que un administrador la restablezca". Instrucciones + copiar + notificar al admin (envía solicitud que llega por notificaciones).
class ForgotPasswordAdminScreen extends StatefulWidget {
  const ForgotPasswordAdminScreen({super.key});

  @override
  State<ForgotPasswordAdminScreen> createState() => _ForgotPasswordAdminScreenState();
}

class _ForgotPasswordAdminScreenState extends State<ForgotPasswordAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _notificarAdmin() async {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    if (email.isEmpty && username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indica tu correo o tu usuario para que el administrador pueda ayudarte.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.post('auth/solicitud-recuperacion', data: {
        'tipo': 'password',
        if (email.isNotEmpty) 'email': email,
        if (username.isNotEmpty) 'username': username,
      });
      if (mounted) {
        setState(() {
          _isLoading = false;
          _sent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Solicitud enviada. Los administradores la verán en Notificaciones y podrán generarte un código o cambiar tu contraseña.',
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
                        Icon(Icons.admin_panel_settings_rounded, size: 48, color: Colors.white.withOpacity(0.9)),
                        const SizedBox(height: 12),
                        Text(
                          'Que un administrador la restablezca',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: Text(
                            'Pasos para el administrador: Gestión de Usuarios y Roles → buscar tu usuario → Editar → Nueva contraseña → Guardar. Te comunicará la nueva contraseña.',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () async {
                            const texto = 'Necesito restablecer mi contraseña del sistema SSUT. Pasos: Gestión de Usuarios y Roles → buscar mi usuario → Editar → Nueva contraseña → Guardar. Gracias.';
                            await Clipboard.setData(const ClipboardData(text: texto));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Instrucciones copiadas. Puedes pegarlas y enviarlas a tu administrador.'),
                                  backgroundColor: Colors.green.shade700,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copiar instrucciones para enviar al admin'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white38),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'O notifica al administrador desde aquí (recibirá una notificación):',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                enabled: !_isLoading && !_sent,
                                decoration: InputDecoration(
                                  labelText: 'Tu correo (opcional)',
                                  hintText: 'Para que el admin te identifique',
                                  prefixIcon: Icon(Icons.email_outlined, color: Colors.white70, size: 22),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.08),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  hintStyle: TextStyle(color: Colors.white54),
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _usernameController,
                                enabled: !_isLoading && !_sent,
                                decoration: InputDecoration(
                                  labelText: 'Tu usuario (opcional)',
                                  hintText: 'Si lo recuerdas',
                                  prefixIcon: Icon(Icons.person_outline_rounded, color: Colors.white70, size: 22),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.08),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  hintStyle: TextStyle(color: Colors.white54),
                                ),
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: (_isLoading || _sent) ? null : _notificarAdmin,
                                icon: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Icon(_sent ? Icons.check_circle_rounded : Icons.notifications_active_rounded, size: 20),
                                label: Text(_sent ? 'Solicitud enviada' : 'Notificar al administrador'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
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
