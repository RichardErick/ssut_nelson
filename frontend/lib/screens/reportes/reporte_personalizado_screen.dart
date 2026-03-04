import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

import '../../models/documento.dart';
import '../../services/documento_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helper.dart';
import '../../widgets/app_alert.dart';

class ReportePersonalizadoScreen extends StatefulWidget {
  const ReportePersonalizadoScreen({super.key});

  @override
  State<ReportePersonalizadoScreen> createState() => _ReportePersonalizadoScreenState();
}

class _ReportePersonalizadoScreenState extends State<ReportePersonalizadoScreen> {
  // Columnas disponibles
  final Map<String, ColumnConfig> _columnasDisponibles = {
    'codigo': ColumnConfig('Código', true, 120),
    'numeroCorrelativo': ColumnConfig('Nº Correlativo', true, 120),
    'tipoDocumento': ColumnConfig('Tipo Documento', true, 150),
    'areaOrigen': ColumnConfig('Área Origen', false, 150),
    'gestion': ColumnConfig('Gestión', true, 100),
    'fechaDocumento': ColumnConfig('Fecha Documento', false, 130),
    'descripcion': ColumnConfig('Descripción', false, 200),
    'responsable': ColumnConfig('Responsable', false, 150),
    'ubicacionFisica': ColumnConfig('Ubicación Física', false, 150),
    'estado': ColumnConfig('Estado', true, 100),
    'carpeta': ColumnConfig('Carpeta', false, 150),
    'nivelConfidencialidad': ColumnConfig('Nivel Confid.', false, 120),
    'fechaRegistro': ColumnConfig('Fecha Registro', false, 130),
  };

  List<Documento> _documentos = [];
  List<Documento> _documentosFiltrados = [];
  bool _isLoading = false;
  bool _mostrarFiltros = false;

  // Filtros
  String _filtroTexto = '';
  String? _filtroEstado;
  String? _filtroTipo;
  DateTime? _filtroFechaDesde;
  DateTime? _filtroFechaHasta;

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDocumentos() async {
    setState(() => _isLoading = true);
    try {
      final service = Provider.of<DocumentoService>(context, listen: false);
      final result = await service.buscar(BusquedaDocumentoDTO(
        pageSize: 1000,
        orderBy: 'fechaDocumento',
        orderDirection: 'DESC',
      ));
      
      if (mounted) {
        setState(() {
          _documentos = result.items;
          _aplicarFiltros();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppAlert.error(context, 'Error', ErrorHelper.getErrorMessage(e));
      }
    }
  }

  void _aplicarFiltros() {
    var filtrados = _documentos;

    // Filtro de texto
    if (_filtroTexto.isNotEmpty) {
      final query = _filtroTexto.toLowerCase();
      filtrados = filtrados.where((doc) {
        return doc.codigo.toLowerCase().contains(query) ||
            doc.numeroCorrelativo.toLowerCase().contains(query) ||
            (doc.descripcion ?? '').toLowerCase().contains(query) ||
            (doc.tipoDocumentoNombre ?? '').toLowerCase().contains(query);
      }).toList();
    }

    // Filtro de estado
    if (_filtroEstado != null && _filtroEstado!.isNotEmpty) {
      filtrados = filtrados.where((doc) => doc.estado == _filtroEstado).toList();
    }

    // Filtro de tipo
    if (_filtroTipo != null && _filtroTipo!.isNotEmpty) {
      filtrados = filtrados.where((doc) => doc.tipoDocumentoNombre == _filtroTipo).toList();
    }

    // Filtro de fecha desde
    if (_filtroFechaDesde != null) {
      filtrados = filtrados.where((doc) {
        return doc.fechaDocumento.isAfter(_filtroFechaDesde!) ||
            doc.fechaDocumento.isAtSameMomentAs(_filtroFechaDesde!);
      }).toList();
    }

    // Filtro de fecha hasta
    if (_filtroFechaHasta != null) {
      filtrados = filtrados.where((doc) {
        return doc.fechaDocumento.isBefore(_filtroFechaHasta!.add(const Duration(days: 1)));
      }).toList();
    }

    setState(() => _documentosFiltrados = filtrados);
  }

  void _limpiarFiltros() {
    setState(() {
      _filtroTexto = '';
      _filtroEstado = null;
      _filtroTipo = null;
      _filtroFechaDesde = null;
      _filtroFechaHasta = null;
      _searchController.clear();
      _aplicarFiltros();
    });
  }

  List<String> get _columnasSeleccionadas {
    return _columnasDisponibles.entries
        .where((e) => e.value.selected)
        .map((e) => e.key)
        .toList();
  }

  Future<void> _exportarPDF() async {
    try {
      final pdf = pw.Document();
      final columnas = _columnasSeleccionadas;
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'REPORTE PERSONALIZADO DE DOCUMENTOS',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Text(
              'Total de registros: ${_documentosFiltrados.length}',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              cellStyle: const pw.TextStyle(fontSize: 7),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellHeight: 25,
              cellAlignments: Map.fromIterable(
                columnas,
                key: (col) => columnas.indexOf(col),
                value: (_) => pw.Alignment.centerLeft,
              ),
              headers: columnas.map((col) => _columnasDisponibles[col]!.label).toList(),
              data: _documentosFiltrados.map((doc) {
                return columnas.map((col) => _getColumnValue(doc, col)).toList();
              }).toList(),
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      _downloadFile(bytes, 'reporte_personalizado_${DateTime.now().millisecondsSinceEpoch}.pdf', 'application/pdf');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF generado exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, 'Error', 'No se pudo generar el PDF: $e');
      }
    }
  }

  Future<void> _exportarExcel() async {
    try {
      final columnas = _columnasSeleccionadas;
      final csv = StringBuffer();
      
      // Headers
      csv.writeln(columnas.map((col) => '"${_columnasDisponibles[col]!.label}"').join(','));
      
      // Data
      for (final doc in _documentosFiltrados) {
        csv.writeln(columnas.map((col) => '"${_getColumnValue(doc, col)}"').join(','));
      }

      final bytes = utf8.encode(csv.toString());
      _downloadFile(Uint8List.fromList(bytes), 'reporte_personalizado_${DateTime.now().millisecondsSinceEpoch}.csv', 'text/csv');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV generado exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, 'Error', 'No se pudo generar el CSV: $e');
      }
    }
  }

  void _downloadFile(Uint8List bytes, String filename, String mimeType) {
    if (kIsWeb) {
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  String _getColumnValue(Documento doc, String column) {
    switch (column) {
      case 'codigo':
        return doc.codigo;
      case 'numeroCorrelativo':
        return doc.numeroCorrelativo;
      case 'tipoDocumento':
        return doc.tipoDocumentoNombre ?? '-';
      case 'areaOrigen':
        return doc.areaOrigenNombre ?? '-';
      case 'gestion':
        return doc.gestion;
      case 'fechaDocumento':
        return DateFormat('dd/MM/yyyy').format(doc.fechaDocumento);
      case 'descripcion':
        return doc.descripcion ?? '-';
      case 'responsable':
        return doc.responsableNombre ?? '-';
      case 'ubicacionFisica':
        return doc.ubicacionFisica ?? '-';
      case 'estado':
        return doc.estado;
      case 'carpeta':
        return doc.carpetaNombre ?? '-';
      case 'nivelConfidencialidad':
        return doc.nivelConfidencialidad.toString();
      case 'fechaRegistro':
        return DateFormat('dd/MM/yyyy').format(doc.fechaRegistro);
      default:
        return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1200;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Reporte Personalizado',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_documentos.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Exportar PDF',
              onPressed: _exportarPDF,
            ),
            IconButton(
              icon: const Icon(Icons.table_chart_rounded),
              tooltip: 'Exportar Excel/CSV',
              onPressed: _exportarExcel,
            ),
          ],
        ],
      ),
      body: Row(
        children: [
          // Panel lateral de configuración
          Container(
            width: isDesktop ? 320 : 280,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: theme.dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: _buildConfigPanel(theme),
          ),
          // Área principal con tabla
          Expanded(
            child: _buildMainArea(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigPanel(ThemeData theme) {
    return Column(
      children: [
        // Header del panel
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            border: Border(
              bottom: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.settings_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Configuración',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Lista de columnas
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Columnas a mostrar',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              ..._columnasDisponibles.entries.map((entry) {
                return CheckboxListTile(
                  dense: true,
                  title: Text(
                    entry.value.label,
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  value: entry.value.selected,
                  onChanged: (value) {
                    setState(() {
                      entry.value.selected = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          for (var col in _columnasDisponibles.values) {
                            col.selected = true;
                          }
                        });
                      },
                      icon: const Icon(Icons.check_box, size: 18),
                      label: const Text('Todas'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          for (var col in _columnasDisponibles.values) {
                            col.selected = false;
                          }
                        });
                      },
                      icon: const Icon(Icons.check_box_outline_blank, size: 18),
                      label: const Text('Ninguna'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _documentos.isEmpty ? _cargarDocumentos : null,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded),
                label: Text(_isLoading ? 'Cargando...' : 'Generar Reporte'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainArea(ThemeData theme) {
    if (_documentos.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'Configura las columnas y genera el reporte',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Selecciona las columnas que deseas ver\ny presiona "Generar Reporte"',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Barra de filtros
        _buildFilterBar(theme),
        // Tabla de resultados
        Expanded(
          child: _buildDataTable(theme),
        ),
      ],
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar en resultados...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _filtroTexto = value;
                      _aplicarFiltros();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: () {
                  setState(() => _mostrarFiltros = !_mostrarFiltros);
                },
                icon: Icon(_mostrarFiltros ? Icons.filter_list_off : Icons.filter_list),
                tooltip: 'Filtros avanzados',
              ),
              const SizedBox(width: 8),
              Text(
                '${_documentosFiltrados.length} registros',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          if (_mostrarFiltros) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _filtroEstado,
                    decoration: InputDecoration(
                      labelText: 'Estado',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Todos')),
                      DropdownMenuItem(value: 'Activo', child: Text('Activo')),
                      DropdownMenuItem(value: 'Prestado', child: Text('Prestado')),
                      DropdownMenuItem(value: 'Archivado', child: Text('Archivado')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _filtroEstado = value;
                        _aplicarFiltros();
                      });
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _limpiarFiltros,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Limpiar filtros'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataTable(ThemeData theme) {
    final columnas = _columnasSeleccionadas;
    
    if (columnas.isEmpty) {
      return Center(
        child: Text(
          'Selecciona al menos una columna para mostrar',
          style: GoogleFonts.inter(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            theme.colorScheme.primaryContainer.withOpacity(0.3),
          ),
          columns: columnas.map((col) {
            return DataColumn(
              label: Text(
                _columnasDisponibles[col]!.label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
          rows: _documentosFiltrados.map((doc) {
            return DataRow(
              cells: columnas.map((col) {
                return DataCell(
                  SizedBox(
                    width: _columnasDisponibles[col]!.width,
                    child: Text(
                      _getColumnValue(doc, col),
                      style: GoogleFonts.inter(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class ColumnConfig {
  final String label;
  bool selected;
  final double width;

  ColumnConfig(this.label, this.selected, this.width);
}
