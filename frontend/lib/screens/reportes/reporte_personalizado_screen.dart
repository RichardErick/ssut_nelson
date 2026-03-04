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
      body: Row(
        children: [
          // Panel lateral de configuración
          Container(
            width: isDesktop ? 320 : 280,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
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
        // Header del panel con gradiente
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.8),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.table_chart_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reportes',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Personaliza tu reporte',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.9),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Columnas a mostrar',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '${_columnasSeleccionadas.length}/13',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._columnasDisponibles.entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: entry.value.selected
                        ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CheckboxListTile(
                    dense: true,
                    title: Text(
                      entry.value.label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: entry.value.selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    value: entry.value.selected,
                    onChanged: (value) {
                      setState(() {
                        entry.value.selected = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: theme.colorScheme.primary,
                  ),
                );
              }),
              const SizedBox(height: 16),
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
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
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
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _documentos.isEmpty ? _cargarDocumentos : null,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search_rounded),
                label: Text(_isLoading ? 'Cargando...' : 'Generar Reporte'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.primary,
                ),
              ),
              if (_documentos.isNotEmpty) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _cargarDocumentos,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Actualizar Datos'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainArea(ThemeData theme) {
    if (_documentos.isEmpty && !_isLoading) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primaryContainer.withOpacity(0.1),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.analytics_outlined,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Genera tu Reporte Personalizado',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Selecciona las columnas que deseas ver',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'y presiona "Generar Reporte"',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildFeatureItem(
                      Icons.check_circle_outline,
                      'Selecciona columnas',
                      'Elige qué información mostrar',
                      theme,
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      Icons.filter_list_rounded,
                      'Filtra resultados',
                      'Busca y filtra por estado',
                      theme,
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      Icons.download_rounded,
                      'Exporta datos',
                      'Descarga en PDF o Excel',
                      theme,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Cargando documentos...',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header con título y botones de exportación
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.table_view_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reporte de Documentos',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Visualiza y exporta tus datos',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _exportarPDF,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                label: const Text('PDF'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _exportarExcel,
                icon: const Icon(Icons.table_chart_rounded, size: 20),
                label: const Text('Excel'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        // Barra de filtros
        _buildFilterBar(theme),
        // Tabla de resultados
        Expanded(
          child: _buildDataTable(theme),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle, ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
