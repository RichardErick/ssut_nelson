import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../utils/error_helper.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_container.dart';

/// Recuperar contraseña con pregunta de seguridad (la que eligió al registrarse).
class ForgotPasswordPreguntaScreen extends StatefulWidget {
  const ForgotPasswordPreguntaScreen({super.key});

  @override
  State<ForgotPasswordPreguntaScreen> createState() => _ForgotPasswordPreguntaScreenState();
}

class _ForgotPasswordPreguntaScreenState extends State<ForgotPasswordPreguntaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _respuestaController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  List<Map<String, dynamic>> _preguntasSecretas = [];
  int _preguntaSecretaId = 0;
  bool _preguntasLoaded = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _obscureRespuesta = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPreguntasSecretas();
  }

  Future<void> _loadPreguntasSecretas() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get('/auth/preguntas-secretas');
      final list = response.data is List ? response.data as List : [];
      if (mounted) {
        setState(() {
          _preguntasSecretas = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          if (_preguntasSecretas.isNotEmpty && _preguntaSecretaId == 0) {
            _preguntaSecretaId = (_preguntasSecretas.first['id'] as num?)?.toInt() ?? 1;
          }
          _preguntasLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _preguntasSecretas = [
            {'id': 1, 'texto': '¿Cuál es el nombre de tu madre?'},
            {'id': 2, 'texto': '¿Cuál es el nombre de tu primera mascota?'},
            {'id': 3, 'texto': '¿En qué ciudad naciste?'},
            {'id': 4, 'texto': '¿Cuál es tu color favorito?'},
            {'id': 5, 'texto': '¿Nombre de tu mejor amigo de la infancia?'},
            {'id': 6, 'texto': '¿Cuál fue tu primer trabajo?'},
            {'id': 7, 'texto': '¿Cuál es el segundo nombre de tu padre?'},
            {'id': 8, 'texto': '¿En qué colegio estudiaste la primaria?'},
            {'id': 9, 'texto': '¿Cuál es tu película favorita?'},
            {'id': 10, 'texto': '¿Cuál es tu comida favorita?'},
          ];
          _preguntaSecretaId = 1;
          _preguntasLoaded = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _respuestaController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Recuperación permitida solo entre 8:00 y 18:00 (hora local).
  bool get _dentroHorario {
    final h = DateTime.now().hour;
    return h >= 8 && h <= 18;
  }

  Future<void> _submit() async {
    if (!_dentroHorario) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La recuperación solo está disponible de 8:00 a 18:00.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_preguntaSecretaId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elige la pregunta que configuraste al registrarte'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.post('auth/reset-password-by-pregunta', data: {
        'username': _usernameController.text.trim(),
        'preguntaSecretaId': _preguntaSecretaId,
        'respuesta': _respuestaController.text.trim(),
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
        Navigator.of(context).popUntil((r) => r.isFirst);
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
                        const SizedBox(height: 8),
                        Text(
                          'Ingresa tu usuario, la pregunta que elegiste al registrarte, tu respuesta y la nueva contraseña.',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildField(
                                controller: _usernameController,
                                label: 'Usuario',
                                hint: 'Nombre de usuario',
                                icon: Icons.person_outline_rounded,
                                validator: (v) =>
                                    (v ?? '').trim().isEmpty ? 'Ingresa tu usuario' : null,
                              ),
                              const SizedBox(height: 14),
                              _buildPreguntaDropdown(),
                              const SizedBox(height: 14),
                              _buildField(
                                controller: _respuestaController,
                                label: 'Respuesta de seguridad',
                                hint: 'La respuesta que configuraste al registrarte',
                                icon: Icons.lock_outline_rounded,
                                obscureText: _obscureRespuesta,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureRespuesta ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscureRespuesta = !_obscureRespuesta),
                                ),
                                validator: (v) =>
                                    (v ?? '').trim().isEmpty ? 'Ingresa tu respuesta' : null,
                              ),
                              const SizedBox(height: 14),
                              _buildField(
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
                                validator: (v) =>
                                    (v ?? '').trim().length < 6 ? 'Mínimo 6 caracteres' : null,
                              ),
                              const SizedBox(height: 14),
                              _buildField(
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
                                validator: (v) =>
                                    (v ?? '').trim() != _passwordController.text.trim() ? 'No coinciden' : null,
                              ),
                              const SizedBox(height: 24),
                              if (!_dentroHorario)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    'Fuera de horario: la recuperación solo está disponible de 8:00 a 18:00.',
                                    style: GoogleFonts.inter(fontSize: 12, color: Colors.orange.shade200),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              FilledButton(
                                onPressed: (_isLoading || !_dentroHorario) ? null : _submit,
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
                        const SizedBox(height: 16),
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

  Widget _buildPreguntaDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Pregunta de seguridad',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _preguntaSecretaId > 0 ? _preguntaSecretaId : null,
              isExpanded: true,
              dropdownColor: Colors.blue.shade900,
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              hint: Text(
                _preguntasLoaded ? 'Elige la pregunta que configuraste' : 'Cargando...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              items: _preguntasSecretas.map((p) {
                final id = (p['id'] as num?)?.toInt() ?? 0;
                final texto = p['texto'] as String? ?? '';
                return DropdownMenuItem<int>(
                  value: id,
                  child: Text(texto, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _preguntaSecretaId = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
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
