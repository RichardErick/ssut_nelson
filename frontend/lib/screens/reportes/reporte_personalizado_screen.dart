import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;

import '../../models/documento.dart';
import '../../services/documento_service.dart';
import '../../theme/tema_aplicacion.dart';
import '../../utils/utilidades_errores.dart';
import '../../widgets/alerta_app.dart';

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
  String? _filtroArea;
  DateTime? _filtroFechaDesde;
  DateTime? _filtroFechaHasta;

  // Ordenamiento
  String? _sortColumn;
  bool _sortAscending = true;

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
            (doc.tipoDocumentoNombre ?? '').toLowerCase().contains(query) ||
            (doc.areaOrigenNombre ?? '').toLowerCase().contains(query);
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

    // Filtro de área
    if (_filtroArea != null && _filtroArea!.isNotEmpty) {
      filtrados = filtrados.where((doc) => doc.areaOrigenNombre == _filtroArea).toList();
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

    // Aplicar ordenamiento
    if (_sortColumn != null) {
      filtrados.sort((a, b) {
        final aValue = _getColumnValue(a, _sortColumn!);
        final bValue = _getColumnValue(b, _sortColumn!);
        final comparison = aValue.compareTo(bValue);
        return _sortAscending ? comparison : -comparison;
      });
    }

    setState(() => _documentosFiltrados = filtrados);
  }

  void _limpiarFiltros() {
    setState(() {
      _filtroTexto = '';
      _filtroEstado = null;
      _filtroTipo = null;
      _filtroArea = null;
      _filtroFechaDesde = null;
      _filtroFechaHasta = null;
      _searchController.clear();
      _aplicarFiltros();
    });
  }

  void _sortBy(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
      _aplicarFiltros();
    });
  }

  List<String> get _tiposDocumentoDisponibles {
    return _documentos
        .map((doc) => doc.tipoDocumentoNombre ?? '')
        .where((tipo) => tipo.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> get _areasDisponibles {
    return _documentos
        .map((doc) => doc.areaOrigenNombre ?? '')
        .where((area) => area.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> get _columnasSeleccionadas {
    return _columnasDisponibles.entries
        .where((e) => e.value.selected)
        .map((e) => e.key)
        .toList();
  }

  Future<void> _exportarPDF() async {
    final columnas = _columnasSeleccionadas;
    
    // Validaciones
    if (columnas.isEmpty) {
      if (mounted) {
        AppAlert.error(context, 'Error', 'Selecciona al menos una columna para exportar');
      }
      return;
    }
    
    if (_documentosFiltrados.isEmpty) {
      if (mounted) {
        AppAlert.error(context, 'Error', 'No hay datos para exportar');
      }
      return;
    }

    try {
      final pdf = pw.Document();
      
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
      final filename = 'reporte_personalizado_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      if (kIsWeb) {
        _downloadFile(bytes, filename, 'application/pdf');
      } else {
        // Para plataformas móviles/desktop, mostrar mensaje
        if (mounted) {
          AppAlert.error(context, 'Información', 'La descarga de PDF solo está disponible en la versión web');
        }
        return;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF generado exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, 'Error', 'No se pudo generar el PDF: ${e.toString()}');
      }
    }
  }

  Future<void> _exportarExcel() async {
    final columnas = _columnasSeleccionadas;
    
    // Validaciones
    if (columnas.isEmpty) {
      if (mounted) {
        AppAlert.error(context, 'Error', 'Selecciona al menos una columna para exportar');
      }
      return;
    }
    
    if (_documentosFiltrados.isEmpty) {
      if (mounted) {
        AppAlert.error(context, 'Error', 'No hay datos para exportar');
      }
      return;
    }

    try {
      final csv = StringBuffer();
      
      // BOM para UTF-8 (ayuda a Excel a reconocer caracteres especiales)
      csv.write('\uFEFF');
      
      // Headers
      csv.writeln(columnas.map((col) => '"${_columnasDisponibles[col]!.label}"').join(','));
      
      // Data
      for (final doc in _documentosFiltrados) {
        csv.writeln(columnas.map((col) {
          final value = _getColumnValue(doc, col);
          // Escapar comillas dobles
          return '"${value.replaceAll('"', '""')}"';
        }).join(','));
      }

      final bytes = utf8.encode(csv.toString());
      final filename = 'reporte_personalizado_${DateTime.now().millisecondsSinceEpoch}.csv';
      
      if (kIsWeb) {
        _downloadFile(Uint8List.fromList(bytes), filename, 'text/csv;charset=utf-8');
      } else {
        // Para plataformas móviles/desktop, mostrar mensaje
        if (mounted) {
          AppAlert.error(context, 'Información', 'La descarga de Excel solo está disponible en la versión web');
        }
        return;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel/CSV generado exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppAlert.error(context, 'Error', 'No se pudo generar el Excel: ${e.toString()}');
      }
    }
  }

  void _downloadFile(Uint8List bytes, String filename, String mimeType) {
    if (kIsWeb) {
      try {
        final blob = html.Blob([bytes], mimeType);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..style.display = 'none';
        
        html.document.body?.append(anchor);
        anchor.click();
        
        // Limpiar después de un pequeño delay
        Future.delayed(const Duration(milliseconds: 100), () {
          anchor.remove();
          html.Url.revokeObjectUrl(url);
        });
      } catch (e) {
        debugPrint('Error al descargar archivo: $e');
        rethrow;
      }
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
              const SizedBox(height: 12),
              ExpansionTile(
                title: Text(
                  'Configuraciones rápidas',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                dense: true,
                childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: [
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.summarize_outlined, size: 18),
                    title: const Text('Vista Básica', style: TextStyle(fontSize: 12)),
                    onTap: () {
                      setState(() {
                        _columnasDisponibles.forEach((key, value) {
                          value.selected = ['codigo', 'numeroCorrelativo', 'tipoDocumento', 'gestion', 'estado'].contains(key);
                        });
                      });
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.article_outlined, size: 18),
                    title: const Text('Vista Completa', style: TextStyle(fontSize: 12)),
                    onTap: () {
                      setState(() {
                        for (var col in _columnasDisponibles.values) {
                          col.selected = true;
                        }
                      });
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined, size: 18),
                    title: const Text('Vista Ubicación', style: TextStyle(fontSize: 12)),
                    onTap: () {
                      setState(() {
                        _columnasDisponibles.forEach((key, value) {
                          value.selected = ['codigo', 'numeroCorrelativo', 'ubicacionFisica', 'carpeta', 'estado'].contains(key);
                        });
                      });
                    },
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.calendar_today_outlined, size: 18),
                    title: const Text('Vista Temporal', style: TextStyle(fontSize: 12)),
                    onTap: () {
                      setState(() {
                        _columnasDisponibles.forEach((key, value) {
                          value.selected = ['codigo', 'numeroCorrelativo', 'fechaDocumento', 'fechaRegistro', 'gestion', 'estado'].contains(key);
                        });
                      });
                    },
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
                onPressed: _columnasSeleccionadas.isEmpty || _documentosFiltrados.isEmpty 
                    ? null 
                    : _exportarPDF,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                label: const Text('PDF'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  disabledBackgroundColor: Colors.grey.shade400,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _columnasSeleccionadas.isEmpty || _documentosFiltrados.isEmpty 
                    ? null 
                    : _exportarExcel,
                icon: const Icon(Icons.table_chart_rounded, size: 20),
                label: const Text('Excel'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  disabledBackgroundColor: Colors.grey.shade400,
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
    final hasActiveFilters = _filtroTexto.isNotEmpty ||
        _filtroEstado != null ||
        _filtroTipo != null ||
        _filtroArea != null ||
        _filtroFechaDesde != null ||
        _filtroFechaHasta != null;

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
                    hintText: 'Buscar por código, correlativo, descripción, tipo o área...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: _filtroTexto.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _filtroTexto = '';
                                _aplicarFiltros();
                              });
                            },
                          )
                        : null,
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
                style: IconButton.styleFrom(
                  backgroundColor: hasActiveFilters
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primaryContainer,
                  foregroundColor: hasActiveFilters
                      ? Colors.white
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_documentosFiltrados.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'registros',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasActiveFilters && !_mostrarFiltros) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_filtroEstado != null)
                  Chip(
                    label: Text('Estado: $_filtroEstado'),
                    onDeleted: () {
                      setState(() {
                        _filtroEstado = null;
                        _aplicarFiltros();
                      });
                    },
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                if (_filtroTipo != null)
                  Chip(
                    label: Text('Tipo: $_filtroTipo'),
                    onDeleted: () {
                      setState(() {
                        _filtroTipo = null;
                        _aplicarFiltros();
                      });
                    },
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                if (_filtroArea != null)
                  Chip(
                    label: Text('Área: $_filtroArea'),
                    onDeleted: () {
                      setState(() {
                        _filtroArea = null;
                        _aplicarFiltros();
                      });
                    },
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                if (_filtroFechaDesde != null)
                  Chip(
                    label: Text('Desde: ${DateFormat('dd/MM/yyyy').format(_filtroFechaDesde!)}'),
                    onDeleted: () {
                      setState(() {
                        _filtroFechaDesde = null;
                        _aplicarFiltros();
                      });
                    },
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                if (_filtroFechaHasta != null)
                  Chip(
                    label: Text('Hasta: ${DateFormat('dd/MM/yyyy').format(_filtroFechaHasta!)}'),
                    onDeleted: () {
                      setState(() {
                        _filtroFechaHasta = null;
                        _aplicarFiltros();
                      });
                    },
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
              ],
            ),
          ],
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
                      prefixIcon: const Icon(Icons.info_outline, size: 18),
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
                if (_tiposDocumentoDisponibles.isNotEmpty)
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      value: _filtroTipo,
                      decoration: InputDecoration(
                        labelText: 'Tipo Documento',
                        prefixIcon: const Icon(Icons.description_outlined, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todos')),
                        ..._tiposDocumentoDisponibles.map((tipo) {
                          return DropdownMenuItem(value: tipo, child: Text(tipo));
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filtroTipo = value;
                          _aplicarFiltros();
                        });
                      },
                    ),
                  ),
                if (_areasDisponibles.isNotEmpty)
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String>(
                      value: _filtroArea,
                      decoration: InputDecoration(
                        labelText: 'Área',
                        prefixIcon: const Icon(Icons.business_outlined, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Todas')),
                        ..._areasDisponibles.map((area) {
                          return DropdownMenuItem(value: area, child: Text(area));
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filtroArea = value;
                          _aplicarFiltros();
                        });
                      },
                    ),
                  ),
                SizedBox(
                  width: 200,
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Fecha Desde',
                      prefixIcon: const Icon(Icons.calendar_today, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      suffixIcon: _filtroFechaDesde != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  _filtroFechaDesde = null;
                                  _aplicarFiltros();
                                });
                              },
                            )
                          : null,
                    ),
                    readOnly: true,
                    controller: TextEditingController(
                      text: _filtroFechaDesde != null
                          ? DateFormat('dd/MM/yyyy').format(_filtroFechaDesde!)
                          : '',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _filtroFechaDesde ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          _filtroFechaDesde = date;
                          _aplicarFiltros();
                        });
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Fecha Hasta',
                      prefixIcon: const Icon(Icons.calendar_today, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      suffixIcon: _filtroFechaHasta != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                setState(() {
                                  _filtroFechaHasta = null;
                                  _aplicarFiltros();
                                });
                              },
                            )
                          : null,
                    ),
                    readOnly: true,
                    controller: TextEditingController(
                      text: _filtroFechaHasta != null
                          ? DateFormat('dd/MM/yyyy').format(_filtroFechaHasta!)
                          : '',
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _filtroFechaHasta ?? DateTime.now(),
                        firstDate: _filtroFechaDesde ?? DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          _filtroFechaHasta = date;
                          _aplicarFiltros();
                        });
                      }
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _limpiarFiltros,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Limpiar filtros'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.view_column_outlined,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Selecciona al menos una columna para mostrar',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_documentosFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontraron resultados',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta ajustar los filtros de búsqueda',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _limpiarFiltros,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Limpiar filtros'),
            ),
          ],
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
          sortColumnIndex: _sortColumn != null ? columnas.indexOf(_sortColumn!) : null,
          sortAscending: _sortAscending,
          columns: columnas.map((col) {
            return DataColumn(
              label: Row(
                children: [
                  Text(
                    _columnasDisponibles[col]!.label,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (_sortColumn == col) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
              onSort: (columnIndex, ascending) => _sortBy(col),
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
