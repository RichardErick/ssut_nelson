import 'package:flutter/material.dart';

class DialogFiltroCarpetas extends StatefulWidget {
  final String? gestionActual;
  final List<String> gestiones;
  final void Function(String? gestion) onAplicar;
  final VoidCallback onLimpiar;

  const DialogFiltroCarpetas({
    super.key,
    required this.gestionActual,
    required this.gestiones,
    required this.onAplicar,
    required this.onLimpiar,
  });

  @override
  State<DialogFiltroCarpetas> createState() => _DialogFiltroCarpetasState();
}

class _DialogFiltroCarpetasState extends State<DialogFiltroCarpetas> {
  late String? _gestion;

  @override
  void initState() {
    super.initState();
    _gestion = widget.gestionActual;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtrar carpetas'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Gestión:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            value: _gestion,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas las gestiones'),
              ),
              ...widget.gestiones.map(
                (g) => DropdownMenuItem<String?>(
                  value: g,
                  child: Text('Gestión $g'),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _gestion = v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: widget.onLimpiar, child: const Text('Limpiar')),
        FilledButton(
          onPressed: () => widget.onAplicar(_gestion),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
