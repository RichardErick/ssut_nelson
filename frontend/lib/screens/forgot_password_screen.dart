import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'forgot_password_admin_screen.dart';
import 'forgot_password_pregunta_screen.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_container.dart';

/// Pantalla inicial de recuperación. Solo disponible de 8:00 a 18:00.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  /// Recuperación permitida solo entre 8:00 y 18:00 (hora local del dispositivo).
  static bool get _dentroHorario => _horaActual >= 8 && _horaActual <= 18;
  static int get _horaActual => DateTime.now().hour;

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
                    if (!_dentroHorario) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Text(
                          'La recuperación de contraseña solo está disponible de 8:00 a 18:00. Vuelve en ese horario.',
                          style: GoogleFonts.inter(fontSize: 14, color: Colors.white, height: 1.4),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      Text(
                        'Elige una opción.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      _OptionTile(
                        icon: Icons.admin_panel_settings_rounded,
                        title: 'Que un administrador la restablezca',
                        subtitle: 'El admin pone tu nueva contraseña en Gestión de Usuarios y te la comunica.',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ForgotPasswordAdminScreen()),
                        ),
                      ),
                      const SizedBox(height: 10),

                      _OptionTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Pregunta secreta',
                        subtitle: 'Responde la pregunta que configuraste al registrarte.',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ForgotPasswordPreguntaScreen()),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),
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
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 28, color: Colors.blue.shade200),
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
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
