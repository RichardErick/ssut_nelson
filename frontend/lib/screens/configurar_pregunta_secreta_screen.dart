import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/error_helper.dart';

/// Pantalla para que usuarios antiguos (sin pregunta secreta) configuren su pregunta y respuesta.
class ConfigurarPreguntaSecretaScreen extends StatefulWidget {
  const ConfigurarPreguntaSecretaScreen({super.key});

  @override
  State<ConfigurarPreguntaSecretaScreen> createState() => _ConfigurarPreguntaSecretaScreenState();
}

class _ConfigurarPreguntaSecretaScreenState extends State<ConfigurarPreguntaSecretaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _respuestaController = TextEditingController();

  List<Map<String, dynamic>> _preguntasSecretas = [];
  int _preguntaSecretaId = 0;
  bool _preguntasLoaded = false;
  bool _isLoading = false;
  bool _obscureRespuesta = true;

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
    _respuestaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_preguntaSecretaId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elige una pregunta de seguridad'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.put('auth/mi-pregunta-secreta', data: {
        'preguntaSecretaId': _preguntaSecretaId,
        'respuestaSecreta': _respuestaController.text.trim(),
      });
      if (!mounted) return;
      await Provider.of<AuthProvider>(context, listen: false).setTienePreguntaSecreta();
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pregunta secreta configurada correctamente'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
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
      appBar: AppBar(
        title: const Text('Configurar pregunta secreta'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Por normas de seguridad es necesario que configures tu pregunta secreta por si olvidas la contraseña.',
                        style: GoogleFonts.inter(fontSize: 15, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Elige una pregunta y escribe tu respuesta. Solo tú la conocerás.',
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Pregunta de seguridad', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _preguntaSecretaId > 0 ? _preguntaSecretaId : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                hint: Text(_preguntasLoaded ? 'Elige una pregunta' : 'Cargando...'),
                items: _preguntasSecretas.map((p) {
                  final id = (p['id'] as num?)?.toInt() ?? 0;
                  final texto = p['texto'] as String? ?? '';
                  return DropdownMenuItem<int>(value: id, child: Text(texto));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _preguntaSecretaId = val);
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _respuestaController,
                decoration: InputDecoration(
                  labelText: 'Tu respuesta',
                  hintText: 'La respuesta que recordarás',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureRespuesta ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => setState(() => _obscureRespuesta = !_obscureRespuesta),
                  ),
                ),
                obscureText: _obscureRespuesta,
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return 'La respuesta es obligatoria';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar pregunta secreta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
