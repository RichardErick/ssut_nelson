import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/documento.dart';
import '../../services/documento_service.dart';
import '../../utils/error_helper.dart';
import 'documento_detail_screen.dart';

class DocumentoSearchScreen extends StatefulWidget {
  final String? query;

  const DocumentoSearchScreen({super.key, this.query});

  @override
  State<DocumentoSearchScreen> createState() => _DocumentoSearchScreenState();
}

class _DocumentoSearchScreenState extends State<DocumentoSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  final _numeroCorrelativoController = TextEditingController();
  final _codigoQRController = TextEditingController();

  String? _selectedGestion;
  int? _selectedTipoDocumento;
  int? _selectedArea;
  String? _selectedEstado;
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;

  List<Documento> _resultados = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    if (widget.query != null) {
      _codigoController.text = widget.query!;
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _numeroCorrelativoController.dispose();
    _codigoQRController.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSearching = true);
    try {
      final service = Provider.of<DocumentoService>(context, listen: false);
      final busqueda = BusquedaDocumentoDTO(
        codigo: _codigoController.text.isEmpty ? null : _codigoController.text,
        numeroCorrelativo:
            _numeroCorrelativoController.text.isEmpty
                ? null
                : _numeroCorrelativoController.text,
        codigoQR:
            _codigoQRController.text.isEmpty ? null : _codigoQRController.text,
        tipoDocumentoId: _selectedTipoDocumento,
        areaOrigenId: _selectedArea,
        gestion: _selectedGestion,
        fechaDesde: _fechaDesde,
        fechaHasta: _fechaHasta,
        estado: _selectedEstado,
      );

      final resultados = await service.buscar(busqueda);
      setState(() {
        _resultados = resultados.items;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ErrorHelper.getErrorMessage(e),
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isDesde) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isDesde) {
          _fechaDesde = picked;
        } else {
          _fechaHasta = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Búsqueda Avanzada')),
      body: Row(
        children: [
          // Panel de filtros
          Container(
            width: 350,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  const Text(
                    'Filtros de Búsqueda',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codigoController,
                    decoration: const InputDecoration(
                      labelText: 'Código',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _numeroCorrelativoController,
                    decoration: const InputDecoration(
                      labelText: 'Número Correlativo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _codigoQRController,
                    decoration: const InputDecoration(
                      labelText: 'Código QR',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedGestion,
                    decoration: const InputDecoration(
                      labelText: 'Gestión',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    items:
                        ['2025', '2024', '2023', '2022']
                            .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() => _selectedGestion = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedEstado,
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.info),
                    ),
                    items:
                        ['Activo', 'Prestado', 'Archivado']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() => _selectedEstado = value),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            _fechaDesde == null
                                ? 'Desde'
                                : DateFormat('dd/MM/yyyy').format(_fechaDesde!),
                          ),
                          onPressed: () => _selectDate(context, true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(
                            _fechaHasta == null
                                ? 'Hasta'
                                : DateFormat('dd/MM/yyyy').format(_fechaHasta!),
                          ),
                          onPressed: () => _selectDate(context, false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSearching ? null : _buscar,
                      icon:
                          _isSearching
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.search),
                      label: Text(_isSearching ? 'Buscando...' : 'Buscar'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Resultados
          Expanded(
            child:
                _resultados.isEmpty && !_isSearching
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Ingrese criterios de búsqueda',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'Resultados',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Chip(
                                label: Text('${_resultados.length}'),
                                avatar: const Icon(Icons.description, size: 18),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _resultados.length,
                            itemBuilder: (context, index) {
                              final doc = _resultados[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: const Icon(Icons.description),
                                  title: Text(doc.codigo),
                                  subtitle: Text(
                                    '${doc.tipoDocumentoNombre} - ${doc.areaOrigenNombre}',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => DocumentoDetailScreen(
                                              documento: doc,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}
