import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/documento.dart';
import '../../services/documento_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helper.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/loading_shimmer.dart';

class DocumentoDetailScreen extends StatefulWidget {
  final Documento documento;

  const DocumentoDetailScreen({super.key, required this.documento});

  @override
  State<DocumentoDetailScreen> createState() => _DocumentoDetailScreenState();
}

class _DocumentoDetailScreenState extends State<DocumentoDetailScreen> {
  String? _qrData;
  bool _isGeneratingQr = false;

  @override
  void initState() {
    super.initState();
    _qrData = _normalizeQrData(
      widget.documento.urlQR ?? widget.documento.codigoQR,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _qrData == null) {
        _generateQr();
      }
    });
  }


  String? _normalizeQrData(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _generateQr() async {
    if (_isGeneratingQr) return;
    setState(() => _isGeneratingQr = true);
    try {
      final service = Provider.of<DocumentoService>(context, listen: false);
      final response = await service.generarQR(widget.documento.id);
      final qrContent =
          response['qrContent'] ??
          response['QrContent'] ??
          widget.documento.urlQR ??
          widget.documento.codigoQR;
      if (mounted) {
        setState(() => _qrData = _normalizeQrData(qrContent?.toString()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelper.getErrorMessage(e)),
            backgroundColor: AppTheme.colorError,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingQr = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.documento;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: theme.colorScheme.surface.withOpacity(0.95),
      appBar: _buildAppBar(doc, theme),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child:
            isDesktop
                ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildLeftColumn(doc, dateFormat, theme),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 2,
                      child: _buildRightColumn(dateFormat, theme),
                    ),
                  ],
                )
                : Column(
                  children: [
                    _buildLeftColumn(doc, dateFormat, theme),
                    const SizedBox(height: 32),
                    _buildRightColumn(dateFormat, theme),
                  ],
                ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Documento doc, ThemeData theme) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      title: Text(
        'DETALLE DE DOCUMENTO',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.print_rounded),
          onPressed: _printDocumento,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.edit_rounded),
          onPressed: () {},
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.share_rounded),
          onPressed: () {},
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildLeftColumn(
    Documento doc,
    DateFormat dateFormat,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMainInfoCard(doc, theme),
        const SizedBox(height: 32),
        _buildGeneralStats(doc, dateFormat, theme),
      ],
    );
  }

  Widget _buildMainInfoCard(Documento doc, ThemeData theme) {
    return AnimatedCard(
      delay: const Duration(milliseconds: 0),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.colorPrimario,
                        AppTheme.colorSecundario,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.codigo,
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        doc.tipoDocumentoNombre ?? 'TIPO NO DEFINIDO',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(doc.estado),
              ],
            ),
            const SizedBox(height: 40),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 3,
              children: [
                _buildMiniInfo(
                  'Correlativo',
                  doc.numeroCorrelativo,
                  Icons.tag_rounded,
                ),
                _buildMiniInfo(
                  'Área Origen',
                  doc.areaOrigenNombre ?? 'N/A',
                  Icons.location_on_rounded,
                ),
                _buildMiniInfo(
                  'Gestión',
                  doc.gestion,
                  Icons.calendar_today_rounded,
                ),
                _buildMiniInfo(
                  'Responsable',
                  doc.responsableNombre ?? 'No asignado',
                  Icons.person_rounded,
                ),
                _buildMiniInfo(
                  'Carpeta',
                  doc.carpetaNombre ?? 'Sin carpeta',
                  Icons.folder_shared_rounded,
                ),
                _buildMiniInfo(
                  'Ubicación Fís.',
                  doc.ubicacionFisica ?? 'No registrada',
                  Icons.shelves,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printDocumento() async {
    String? qrData = _normalizeQrData(
      _qrData ?? widget.documento.urlQR ?? widget.documento.codigoQR,
    );
    if (qrData == null) {
      await _generateQr();
      qrData = _normalizeQrData(
        _qrData ?? widget.documento.urlQR ?? widget.documento.codigoQR,
      );
    }
    final qrDataSafe =
        (qrData != null && qrData.isNotEmpty) ? qrData : widget.documento.codigo;

    final doc = widget.documento;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build:
            (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.6, color: PdfColors.grey600),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Comprobante de Documento',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              'Correspondiente al ${dateFormat.format(doc.fechaDocumento)}',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            _buildPdfRow('Área', doc.areaOrigenNombre ?? 'N/A'),
                            _buildPdfRow('Tipo', doc.tipoDocumentoNombre ?? 'N/A'),
                            _buildPdfRow('Gestión', doc.gestion),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 0.6, color: PdfColors.grey600),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text('N°', style: pw.TextStyle(fontSize: 10)),
                            pw.Text(
                              doc.numeroCorrelativo,
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              'Estado: ${doc.estado}',
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  'Detalle',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                _buildPdfRow('Código', doc.codigo),
                _buildPdfRow('Correlativo', doc.numeroCorrelativo),
                _buildPdfRow('Tipo', doc.tipoDocumentoNombre ?? 'N/A'),
                _buildPdfRow('Área origen', doc.areaOrigenNombre ?? 'N/A'),
                _buildPdfRow('Gestión', doc.gestion),
                _buildPdfRow(
                  'Fecha documento',
                  dateFormat.format(doc.fechaDocumento),
                ),
                _buildPdfRow(
                  'Responsable',
                  doc.responsableNombre ?? 'No asignado',
                ),
                _buildPdfRow(
                  'Carpeta',
                  doc.carpetaNombre ?? 'Sin carpeta',
                ),
                _buildPdfRow(
                  'Ubicacion fisica',
                  doc.ubicacionFisica ?? 'No registrada',
                ),
                _buildPdfRow('Estado', doc.estado),
                _buildPdfRow(
                  'Descripcion',
                  doc.descripcion ?? 'Sin descripción',
                ),
                pw.SizedBox(height: 16),
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey600, width: 0.6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        color: PdfColors.blue100,
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        child: pw.Row(
                          children: [
                            _pdfHeaderCell('Cuenta', flex: 2),
                            _pdfHeaderCell('Descripción', flex: 4),
                            _pdfHeaderCell('Débitos', flex: 2, alignEnd: true),
                            _pdfHeaderCell('Créditos', flex: 2, alignEnd: true),
                          ],
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        child: pw.Row(
                          children: [
                            _pdfBodyCell('—', flex: 2),
                            _pdfBodyCell(doc.descripcion ?? 'Detalle no registrado', flex: 4),
                            _pdfBodyCell('0.00', flex: 2, alignEnd: true),
                            _pdfBodyCell('0.00', flex: 2, alignEnd: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'QR',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrDataSafe,
                  width: 120,
                  height: 120,
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  qrDataSafe,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
      ),
    );

    try {
      await Printing.layoutPdf(onLayout: (_) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelper.getErrorMessage(e)),
            backgroundColor: AppTheme.colorError,
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String estado) {
    final color = _getStatusColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        estado.toUpperCase(),
        style: GoogleFonts.inter(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildMiniInfo(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfHeaderCell(String text, {int flex = 1, bool alignEnd = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        text,
        textAlign: alignEnd ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _pdfBodyCell(String text, {int flex = 1, bool alignEnd = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        text,
        textAlign: alignEnd ? pw.TextAlign.right : pw.TextAlign.left,
        style: const pw.TextStyle(fontSize: 10),
      ),
    );
  }

  Widget _buildGeneralStats(
    Documento doc,
    DateFormat dateFormat,
    ThemeData theme,
  ) {
    return AnimatedCard(
      delay: const Duration(milliseconds: 200),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DESCRIPCIÓN',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    doc.descripcion ?? 'Sin descripción adicional.',
                    style: GoogleFonts.inter(fontSize: 15, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          if (_qrData != null)
            _buildQRCode(_qrData!, theme)
          else
            _buildQrPlaceholder(theme),
        ],
      ),
    );
  }

  Widget _buildQRCode(String data, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          QrImageView(
            data: data,
            version: QrVersions.auto,
            size: 100.0,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppTheme.colorPrimario,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ESCANEAME',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrPlaceholder(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.qr_code_rounded,
            size: 48,
            color: theme.colorScheme.primary.withOpacity(0.6),
          ),
          const SizedBox(height: 8),
          Text(
            'QR no disponible',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: _isGeneratingQr ? null : _generateQr,
              child: Text(
                _isGeneratingQr ? 'Generando...' : 'Generar QR',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildRightColumn(DateFormat dateFormat, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PREVISUALIZACIÓN DEL DOCUMENTO',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14),
            ],
          ),
          child: SizedBox(
            height: 520,
            child: PdfPreview(
              build: (format) => _buildPdfBytes(),
              allowPrinting: true,
              allowSharing: true,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
            ),
          ),
        ),
      ],
    );
  }

  Future<Uint8List> _buildPdfBytes() async {
    String? qrData = _normalizeQrData(
      _qrData ?? widget.documento.urlQR ?? widget.documento.codigoQR,
    );
    if (qrData == null) {
      await _generateQr();
      qrData = _normalizeQrData(
        _qrData ?? widget.documento.urlQR ?? widget.documento.codigoQR,
      );
    }
    final qrDataSafe =
        (qrData != null && qrData.isNotEmpty) ? qrData : widget.documento.codigo;

    final doc = widget.documento;
    final dateFormat = DateFormat('dd/MM/yyyy');
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build:
            (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.6, color: PdfColors.grey600),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Comprobante de Documento',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              'Correspondiente al ${dateFormat.format(doc.fechaDocumento)}',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            _buildPdfRow('Área', doc.areaOrigenNombre ?? 'N/A'),
                            _buildPdfRow('Tipo', doc.tipoDocumentoNombre ?? 'N/A'),
                            _buildPdfRow('Gestión', doc.gestion),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 0.6, color: PdfColors.grey600),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Text('N°', style: pw.TextStyle(fontSize: 10)),
                            pw.Text(
                              doc.numeroCorrelativo,
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              'Estado: ${doc.estado}',
                              style: pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  doc.descripcion ?? 'Detalle no registrado',
                  style: pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.6, color: PdfColors.grey600),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildPdfRow('Código', doc.codigo),
                            _buildPdfRow('Correlativo', doc.numeroCorrelativo),
                            _buildPdfRow('Responsable', doc.responsableNombre ?? 'No asignado'),
                            _buildPdfRow('Carpeta', doc.carpetaNombre ?? 'Sin carpeta'),
                            _buildPdfRow('Ubicación', doc.ubicacionFisica ?? 'No registrada'),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrDataSafe,
                        width: 80,
                        height: 80,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );

    return pdf.save();
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }


  Color _getStatusColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'activo':
        return AppTheme.colorExito;
      case 'prestado':
        return AppTheme.colorAdvertencia;
      case 'archivado':
        return AppTheme.colorInfo;
      default:
        return Colors.grey;
    }
  }
}
