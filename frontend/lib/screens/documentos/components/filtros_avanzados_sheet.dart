import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/usuario.dart';
import '../../../services/usuario_service.dart';

class FiltrosAvanzadosSheet extends StatefulWidget {
  const FiltrosAvanzadosSheet({
    super.key,
    required this.theme,
    required this.numeroComprobanteController,
    required this.fechaDesde,
    required this.fechaHasta,
    required this.responsableId,
    required this.codigoQrController,
    required this.onAplicar,
    required this.onLimpiar,
  });

  final ThemeData theme;
  final TextEditingController numeroComprobanteController;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final int? responsableId;
  final TextEditingController codigoQrController;
  final void Function(
    String numeroComprobante,
    DateTime? fechaDesde,
    DateTime? fechaHasta,
    int? responsableId,
    String codigoQr,
  )
  onAplicar;
  final VoidCallback onLimpiar;

  @override
  State<FiltrosAvanzadosSheet> createState() => _FiltrosAvanzadosSheetState();
}

class _FiltrosAvanzadosSheetState extends State<FiltrosAvanzadosSheet> {
  late DateTime? _fechaDesde;
  late DateTime? _fechaHasta;
  late int? _responsableId;
  List<Usuario> _usuarios = [];
  bool _loadingUsuarios = true;

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _fechaDesde = widget.fechaDesde;
    _fechaHasta = widget.fechaHasta;
    _responsableId = widget.responsableId;
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    try {
      final service = Provider.of<UsuarioService>(context, listen: false);
      final list = await service.getAll();
      if (mounted) {
        setState(() {
          _usuarios = list;
          _loadingUsuarios = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUsuarios = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Búsqueda avanzada',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Filtre por fecha, responsable y número de comprobante',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              // 1. FECHA (desde / hasta)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _fechaDesde ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null && mounted)
                          setState(() => _fechaDesde = picked);
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 20),
                      label: Text(
                        _fechaDesde == null
                            ? 'Fecha desde'
                            : _dateFormat.format(_fechaDesde!),
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _fechaHasta ?? DateTime.now(),
                          firstDate: _fechaDesde ?? DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null && mounted)
                          setState(() => _fechaHasta = picked);
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 20),
                      label: Text(
                        _fechaHasta == null
                            ? 'Fecha hasta'
                            : _dateFormat.format(_fechaHasta!),
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 2. RESPONSABLE
              if (_loadingUsuarios)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                DropdownButtonFormField<int?>(
                  value: _responsableId,
                  decoration: InputDecoration(
                    labelText: 'Responsable',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todos'),
                    ),
                    ..._usuarios.map(
                      (u) => DropdownMenuItem<int?>(
                        value: u.id,
                        child: Text('${u.nombreCompleto} (${u.nombreUsuario})'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _responsableId = v),
                ),
              const SizedBox(height: 16),
              // 3. NÚMERO DE COMPROBANTE
              TextFormField(
                controller: widget.numeroComprobanteController,
                decoration: InputDecoration(
                  labelText: 'Número de comprobante',
                  hintText: 'Ej: 1, 5, 10',
                  prefixIcon: const Icon(Icons.numbers_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              // Código QR (opcional)
              TextFormField(
                controller: widget.codigoQrController,
                decoration: InputDecoration(
                  labelText: 'Código QR',
                  hintText: 'Parte del código QR del documento',
                  prefixIcon: const Icon(Icons.qr_code_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onLimpiar,
                      icon: const Icon(Icons.clear_all_rounded, size: 20),
                      label: const Text('Limpiar'),
                      style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () {
                      widget.onAplicar(
                        widget.numeroComprobanteController.text.trim(),
                        _fechaDesde,
                        _fechaHasta,
                        _responsableId,
                        widget.codigoQrController.text.trim(),
                      );
                    },
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text('Aplicar filtros'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}
