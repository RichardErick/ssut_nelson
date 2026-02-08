import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/animated_background.dart';
import '../widgets/glass_container.dart';

/// Pantalla dedicada: "Pregunta secreta" (no disponible en esta versión).
class ForgotPasswordPreguntaScreen extends StatelessWidget {
  const ForgotPasswordPreguntaScreen({super.key});

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
                        Icon(Icons.help_outline_rounded, size: 48, color: Colors.white.withOpacity(0.9)),
                        const SizedBox(height: 12),
                        Text(
                          'Pregunta secreta',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Text(
                            'Esta opción no está disponible en esta versión. Podrás configurar una pregunta secreta en tu perfil en futuras actualizaciones.',
                            style: GoogleFonts.inter(fontSize: 14, color: Colors.white, height: 1.4),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Por ahora usa "Que un administrador la restablezca".',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
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
