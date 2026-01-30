import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:html' as html;
import 'package:image/image.dart' as img;

import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/anexo.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../models/documento.dart';
import '../../services/anexo_service.dart';
import '../../services/documento_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helper.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  List<Anexo> _anexos = [];
  bool _isLoadingAnexos = false;
  bool _isUploadingAnexo = false;
  Uint8List? _previewPdfBytes;
  String? _previewFileName;
  bool _anexosLoaded = false;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_anexosLoaded) {
      _anexosLoaded = true;
      _loadAnexos();
    }
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
        padding: const EdgeInsets.all(24.0),
        child:
            isDesktop
                ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4, // Aumentado para dar más espacio a los detalles
                      child: _buildLeftColumn(doc, dateFormat, theme),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 3,
                      child: _buildRightColumn(theme),
                    ),
                  ],
                )
                : Column(
                  children: [
                    _buildLeftColumn(doc, dateFormat, theme),
                    const SizedBox(height: 24),
                    _buildRightColumn(theme),
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
        if (Provider.of<AuthProvider>(context).hasPermission('borrar_documento'))
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _confirmarEliminarDocumento(doc),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade700,
            ),
            tooltip: 'Eliminar documento',
          ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.qr_code_rounded),
          onPressed: () => _descargarCodigoQR(doc),
          style: IconButton.styleFrom(
            backgroundColor: Colors.purple.shade50,
            foregroundColor: Colors.purple.shade700,
          ),
          tooltip: 'Descargar código QR',
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.download_rounded),
          onPressed: _descargarDocumento,
          style: IconButton.styleFrom(
            backgroundColor: Colors.green.shade50,
            foregroundColor: Colors.green.shade700,
          ),
          tooltip: 'Descargar documento',
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.print_rounded),
          onPressed: _printDocumento,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          ),
          tooltip: 'Imprimir documento',
        ),
        const SizedBox(width: 8),
        if (Provider.of<AuthProvider>(context).hasPermission('editar_metadatos'))
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () {},
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            ),
            tooltip: 'Editar documento',
          ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.share_rounded),
          onPressed: () => _compartirDocumento(doc),
          style: IconButton.styleFrom(
            backgroundColor: Colors.orange.shade50,
            foregroundColor: Colors.orange.shade700,
          ),
          tooltip: 'Compartir documento',
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
        const SizedBox(height: 16),
        _buildDescriptionCard(doc, theme),
      ],
    );
  }

  Widget _buildMainInfoCard(Documento doc, ThemeData theme) {
    return AnimatedCard(
      delay: const Duration(milliseconds: 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.colorPrimario,
                        AppTheme.colorSecundario.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.description_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.codigo,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        doc.tipoDocumentoNombre ?? 'TIPO NO DEFINIDO',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildConfidentialityBadge(doc.nivelConfidencialidad),
                        const SizedBox(width: 8),
                        _buildStatusChip(doc.estado),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24, thickness: 1),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 4.5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 16,
              children: [
                _buildMiniInfo(
                  'Número Correlativo',
                  doc.numeroCorrelativo,
                  Icons.tag_rounded,
                  theme,
                ),
                _buildMiniInfo(
                  'Área de Origen',
                  doc.areaOrigenNombre ?? 'N/A',
                  Icons.business_center_rounded,
                  theme,
                ),
                _buildMiniInfo(
                  'Gestión / Año',
                  doc.gestion,
                  Icons.calendar_today_rounded,
                  theme,
                ),
                _buildMiniInfo(
                  'Responsable Asignado',
                  doc.responsableNombre ?? 'Sin asignar',
                  Icons.person_pin_rounded,
                  theme,
                ),
                _buildMiniInfo(
                  'Carpeta de Archivo',
                  doc.carpetaNombre ?? 'Sin carpeta',
                  Icons.inventory_2_rounded,
                  theme,
                ),
                _buildMiniInfo(
                  'Ubicación Física',
                  doc.ubicacionFisica ?? 'No registrada',
                  Icons.shelves,
                  theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactQR(String data) {
    return Tooltip(
      message: 'Código QR de validación',
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: QrImageView(
          data: data,
          version: QrVersions.auto,
          size: 60.0,
          eyeStyle: QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: AppTheme.colorPrimario,
          ),
        ),
      ),
    );
  }

  Widget _buildQrButton() {
    return ElevatedButton(
      onPressed: _isGeneratingQr ? null : _generateQr,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        _isGeneratingQr ? '...' : 'Generar QR',
        style: const TextStyle(fontSize: 10),
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
        (qrData != null && qrData.isNotEmpty)
            ? qrData
            : widget.documento.codigo;

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
                            _buildPdfRow(
                              'Tipo',
                              doc.tipoDocumentoNombre ?? 'N/A',
                            ),
                            _buildPdfRow('Gestión', doc.gestion),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            width: 0.6,
                            color: PdfColors.grey600,
                          ),
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
                _buildPdfRow('Carpeta', doc.carpetaNombre ?? 'Sin carpeta'),
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
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
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
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        child: pw.Row(
                          children: [
                            _pdfBodyCell('—', flex: 2),
                            _pdfBodyCell(
                              doc.descripcion ?? 'Detalle no registrado',
                              flex: 4,
                            ),
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
                pw.Text(qrDataSafe, style: const pw.TextStyle(fontSize: 10)),
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

  Future<void> _confirmarEliminarDocumento(Documento doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar documento'),
        content: Text(
          '¿Estás seguro de eliminar el documento "${doc.codigo}"?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _eliminarDocumento(doc);
    }
  }

  Future<void> _eliminarDocumento(Documento doc) async {
    try {
      final service = Provider.of<DocumentoService>(context, listen: false);
      await service.delete(doc.id);
      
      if (!mounted) return;
      
      // Notificar al DataProvider
      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      dataProvider.notifyDocumentoDeleted(doc.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Documento "${doc.codigo}" eliminado correctamente'),
            ],
          ),
          backgroundColor: AppTheme.colorExito,
        ),
      );
      
      // Regresar a la pantalla anterior
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: ${ErrorHelper.getErrorMessage(e)}'),
          backgroundColor: AppTheme.colorError,
        ),
      );
    }
  }

  Future<void> _compartirDocumento(Documento doc) async {
    try {
      // Generar el link compartible del documento
      final linkCompartible = _generarLinkCompartible(doc);
      
      // Copiar al portapapeles
      await Clipboard.setData(ClipboardData(text: linkCompartible));
      
      // Mostrar diálogo con el link
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.share_rounded, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              const Text('Compartir Documento'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Link del documento copiado al portapapeles:',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  linkCompartible,
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cualquier usuario puede pegar este link en el buscador QR para encontrar el documento.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: linkCompartible));
                if (context.mounted) {
                  Navigator.pop(context);
                  _showNotification(
                    'Link copiado nuevamente al portapapeles',
                    background: AppTheme.colorExito,
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar otra vez'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
      
      _showNotification(
        'Link del documento copiado al portapapeles',
        background: AppTheme.colorExito,
      );
      
    } catch (e) {
      _showNotification(
        'Error al generar link: ${ErrorHelper.getErrorMessage(e)}',
        background: AppTheme.colorError,
      );
    }
  }

  String _generarLinkCompartible(Documento doc) {
    // Generar un link que sea reconocible por el QR scanner
    // Formato: DOC-SHARE:{codigo}:{id}
    return 'DOC-SHARE:${doc.codigo}:${doc.id}';
  }

  Future<void> _descargarCodigoQR(Documento doc) async {
    try {
      // Asegurar que tenemos un código QR
      String? qrData = _normalizeQrData(
        _qrData ?? widget.documento.urlQR ?? widget.documento.codigoQR,
      );
      
      if (qrData == null) {
        await _generateQr();
        qrData = _normalizeQrData(
          _qrData ?? widget.documento.urlQR ?? widget.documento.codigoQR,
        );
      }
      
      final qrDataSafe = (qrData != null && qrData.isNotEmpty) 
          ? qrData 
          : widget.documento.codigo;
      
      // Generar imagen QR como PNG
      final qrImageBytes = await _generarImagenQRPNG(qrDataSafe, doc);
      
      // Descargar como PDF (no PNG, ya que estamos generando PDF)
      await _descargarArchivo(qrImageBytes, 'QR_${doc.codigo}.pdf');
      
      _showNotification(
        'Código QR descargado: QR_${doc.codigo}.pdf',
        background: AppTheme.colorExito,
      );
      
    } catch (e) {
      _showNotification(
        'Error al descargar QR: ${ErrorHelper.getErrorMessage(e)}',
        background: AppTheme.colorError,
      );
    }
  }

  Future<Uint8List> _generarImagenQRPNG(String qrData, Documento doc) async {
    try {
      // Crear un widget QR
      final qrWidget = QrImageView(
        data: qrData,
        version: QrVersions.auto,
        size: 400.0,
        backgroundColor: Colors.white,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      );

      // Crear un PDF simple con solo el QR (más compatible)
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                // Título
                pw.Text(
                  'CÓDIGO QR - ${doc.codigo}',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // Información básica
                pw.Text(
                  '${doc.tipoDocumentoNombre ?? 'Documento'} - Gestión ${doc.gestion}',
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.Text(
                  doc.areaOrigenNombre ?? 'N/A',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 30),
                
                // QR Code grande y centrado
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 2),
                    color: PdfColors.white,
                  ),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrData,
                    width: 300,
                    height: 300,
                    drawText: false,
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                // Código como texto
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Text(
                    qrData,
                    style: pw.TextStyle(
                      fontSize: 10,
                      font: pw.Font.courier(),
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                // Instrucciones simples
                pw.Text(
                  'Escanee este código QR o copie el texto para buscar el documento',
                  style: const pw.TextStyle(fontSize: 12),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
      
      return pdf.save();
    } catch (e) {
      print('Error generando QR PNG: $e');
      rethrow;
    }
  }

  Future<void> _descargarCodigoQRImagen(Documento doc) async {
    try {
      // Asegurar que tenemos un código QR
      String? qrData = _normalizeQrData(
        _qrData ?? widget.documento.urlQR ?? widget.documento.codigoQR,
      );
      
      if (qrData == null) {
        await _generateQr();
        qrData = _normalizeQrData(
          _qrData ?? widget.documento.urlQR ?? widget.documento.codigoQR,
        );
      }
      
      final qrDataSafe = (qrData != null && qrData.isNotEmpty) 
          ? qrData 
          : widget.documento.codigo;
      
      // Generar imagen PNG real
      final qrImageBytes = await _generarImagenPNGReal(qrDataSafe, doc);
      
      // Descargar como PDF optimizado
      await _descargarArchivo(qrImageBytes, 'QR_${doc.codigo}_optimizado.pdf');
      
      _showNotification(
        'QR descargado: QR_${doc.codigo}_optimizado.pdf (compatible con scanner)',
        background: AppTheme.colorExito,
      );
      
    } catch (e) {
      _showNotification(
        'Error al descargar imagen QR: ${ErrorHelper.getErrorMessage(e)}',
        background: AppTheme.colorError,
      );
    }
  }

  Future<Uint8List> _generarImagenPNGReal(String qrData, Documento doc) async {
    try {
      // Enfoque más simple: usar solo la librería image para crear una imagen básica
      // y luego usar el PDF como fallback
      
      // Por ahora, vamos a generar un PDF optimizado que sea más compatible
      return await _generarPDFOptimizado(qrData, doc);
      
    } catch (e) {
      print('Error generando imagen: $e');
      // Fallback: PDF simple
      return await _generarImagenSimplePDF(qrData);
    }
  }

  Future<Uint8List> _generarPDFOptimizado(String qrData, Documento doc) async {
    // PDF optimizado para ser más compatible con lectores
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Container(
          color: PdfColors.white,
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              // Título simple
              pw.Text(
                'QR - ${doc.codigo}',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              
              // QR Code grande con fondo blanco
              pw.Container(
                padding: const pw.EdgeInsets.all(30),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border.all(color: PdfColors.black, width: 2),
                ),
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrData,
                  width: 400,
                  height: 400,
                  drawText: false,
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Código como texto para copiar manualmente
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Text(
                  qrData,
                  style: pw.TextStyle(
                    fontSize: 12,
                    font: pw.Font.courier(),
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              
              pw.SizedBox(height: 15),
              
              // Instrucciones
              pw.Text(
                'Escanee el código QR o copie el texto para buscar el documento',
                style: const pw.TextStyle(fontSize: 11),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
    
    return pdf.save();
  }

  Future<Uint8List> _generarImagenSimplePDF(String qrData) async {
    // Método de respaldo: PDF simple con solo QR
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(400, 400, marginAll: 0),
        build: (context) => pw.Container(
          width: 400,
          height: 400,
          color: PdfColors.white,
          child: pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrData,
              width: 350,
              height: 350,
              drawText: false,
            ),
          ),
        ),
      ),
    );
    
    return pdf.save();
  }
    // En Flutter Web, esto creará un enlace de descarga
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = fileName;
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _descargarArchivo(Uint8List bytes, String fileName) async {
    // En Flutter Web, esto creará un enlace de descarga
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = fileName;
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _descargarDocumento() async {
    try {
      // Si hay anexos, descargar el primer PDF
      if (_anexos.isNotEmpty) {
        final primerAnexo = _anexos.first;
        final service = Provider.of<AnexoService>(context, listen: false);
        final pdfBytes = await service.descargarBytes(primerAnexo.id);
        
        // Descargar el archivo
        await _descargarArchivo(pdfBytes, primerAnexo.nombreArchivo);
        
        _showNotification(
          'Descarga iniciada: ${primerAnexo.nombreArchivo}',
          background: AppTheme.colorExito,
        );
      } else {
        // Si no hay anexos, generar PDF con la información del documento
        final pdfBytes = await _buildPdfBytes();
        await _descargarArchivo(pdfBytes, 'Documento_${widget.documento.codigo}.pdf');
        
        _showNotification(
          'PDF del documento generado y descargado',
          background: AppTheme.colorExito,
        );
      }
    } catch (e) {
      _showNotification(
        'Error en descarga: ${ErrorHelper.getErrorMessage(e)}',
        background: AppTheme.colorError,
      );
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

  Widget _buildMiniInfo(
    String label,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfHeaderCell(String text, {int flex = 1, bool alignEnd = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Text(
        text,
        textAlign: alignEnd ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
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

  Widget _buildDescriptionCard(Documento doc, ThemeData theme) {
    return AnimatedCard(
      delay: const Duration(milliseconds: 200),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notes_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'DESCRIPCIÓN Y DETALLES',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              doc.descripcion ?? 'Sin descripción adicional registrada.',
              style: GoogleFonts.inter(
                fontSize: 15,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
            if (doc.palabrasClave.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: doc.palabrasClave.map((tag) => _buildKeywordChip(tag, theme)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordChip(String label, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
      ),
      child: Text(
        '#$label',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildConfidentialityBadge(int level) {
    Color color;
    String text;
    switch (level) {
      case 3:
        color = Colors.red.shade700;
        text = 'CRÍTICO';
        break;
      case 2:
        color = Colors.orange.shade700;
        text = 'RESERVADO';
        break;
      default:
        color = Colors.blue.shade700;
        text = 'PÚBLICO';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
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

  Widget _buildAnexosSection(ThemeData theme) {
    return AnimatedCard(
      delay: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Anexos',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isUploadingAnexo ? null : _pickAndUploadAnexo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon:
                      _isUploadingAnexo
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Icon(Icons.attach_file_rounded, size: 18),
                  label: Text(
                    _isUploadingAnexo ? 'Subiendo...' : 'Subir anexo',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoadingAnexos)
              const Center(child: CircularProgressIndicator())
            else if (_anexos.isEmpty)
              Text(
                'No hay anexos cargados',
                style: GoogleFonts.inter(color: Colors.grey),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _anexos.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final anexo = _anexos[index];
                  return InkWell(
                    onTap: () => _handleAnexoLink(anexo),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.picture_as_pdf_outlined,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  anexo.nombreArchivo,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatFileSize(anexo.tamano),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightColumn(ThemeData theme) {
    final hasPreview = _previewPdfBytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.visibility_rounded, 
                size: 20, 
                color: theme.colorScheme.primary
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'VISUALIZACIÓN',
              style: GoogleFonts.poppins(
                fontSize: 14, 
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        hasPreview
            ? _buildPdfPreview(theme)
            : _buildAttachDocumentPlaceholder(theme),
        const SizedBox(height: 16),
        _buildQrCard(widget.documento, theme),
      ],
    );
  }

  Widget _buildAttachDocumentPlaceholder(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return InkWell(
          onTap: _isUploadingAnexo ? null : _pickAndUploadAnexo,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
                width: 2,
                style: BorderStyle.solid,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 180),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_upload_rounded,
                        size: constraints.maxWidth < 400 ? 40 : 56,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Subir Documento Digital',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: constraints.maxWidth < 400 ? 16 : 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Arrastra tu PDF aquí o haz clic para seleccionar',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: constraints.maxWidth < 400 ? 12 : 14,
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isUploadingAnexo)
                      Column(
                        children: [
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Subiendo...',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700),
                          )
                        ],
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _pickAndUploadAnexo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.folder_open_rounded, size: 18),
                        label: Text(
                          'Seleccionar Archivo',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPdfPreview(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 520,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14),
            ],
          ),
          child: PdfPreview(
            build: (_) => _previewPdfBytes!,
            allowPrinting: true,
            allowSharing: true,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _previewFileName ?? 'PDF adjunto',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _isUploadingAnexo ? null : _pickAndUploadAnexo,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(
                'Reemplazar PDF',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
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
        (qrData != null && qrData.isNotEmpty)
            ? qrData
            : widget.documento.codigo;

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
                            _buildPdfRow(
                              'Tipo',
                              doc.tipoDocumentoNombre ?? 'N/A',
                            ),
                            _buildPdfRow('Gestión', doc.gestion),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            width: 0.6,
                            color: PdfColors.grey600,
                          ),
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
                            _buildPdfRow(
                              'Responsable',
                              doc.responsableNombre ?? 'No asignado',
                            ),
                            _buildPdfRow(
                              'Carpeta',
                              doc.carpetaNombre ?? 'Sin carpeta',
                            ),
                            _buildPdfRow(
                              'Ubicación',
                              doc.ubicacionFisica ?? 'No registrada',
                            ),
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

  Future<void> _loadAnexos() async {
    setState(() => _isLoadingAnexos = true);
    try {
      final service = Provider.of<AnexoService>(context, listen: false);
      final anexos = await service.listarPorDocumento(widget.documento.id);
      if (mounted) {
        setState(() => _anexos = anexos);
        
        // Si hay anexos y no tenemos preview, cargar el primer PDF automáticamente
        if (anexos.isNotEmpty && _previewPdfBytes == null) {
          _loadFirstPdfPreview(anexos.first);
        }
      }
    } catch (e) {
      if (mounted) {
        _showNotification(
          ErrorHelper.getErrorMessage(e),
          background: Colors.red.shade600,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAnexos = false);
      }
    }
  }

  Future<void> _loadFirstPdfPreview(Anexo anexo) async {
    try {
      print('DEBUG: Cargando preview del anexo: ${anexo.nombreArchivo}');
      final service = Provider.of<AnexoService>(context, listen: false);
      final pdfBytes = await service.descargarBytes(anexo.id);
      
      if (mounted && pdfBytes != null) {
        setState(() {
          _previewPdfBytes = pdfBytes;
          _previewFileName = anexo.nombreArchivo;
        });
        print('DEBUG: Preview cargado exitosamente para: ${anexo.nombreArchivo}');
      }
    } catch (e) {
      print('DEBUG: Error cargando preview: $e');
      // No mostrar error al usuario, solo log para debug
    }
  }

  Future<void> _pickAndUploadAnexo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final file = result?.files.first;
    if (file == null) return;
    final pdfBytes = file.bytes;
    if (pdfBytes == null) {
      _showNotification(
        'No se pudo leer el archivo PDF',
        background: Colors.red.shade600,
      );
      return;
    }

    setState(() => _isUploadingAnexo = true);
    try {
      final service = Provider.of<AnexoService>(context, listen: false);
      final anexo = await service.subirArchivo(widget.documento.id, file);
      if (mounted) {
        setState(() {
          _previewPdfBytes = pdfBytes;
          _previewFileName = file.name;
        });
        _showNotification(
          'Anexo "${anexo.nombreArchivo}" cargado',
          background: AppTheme.colorExito,
        );
        await _loadAnexos();
      }
    } catch (e) {
      if (mounted) {
        _showNotification(
          ErrorHelper.getErrorMessage(e),
          background: Colors.red.shade600,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAnexo = false);
      }
    }
  }

  void _handleAnexoLink(Anexo anexo) {
    final url = anexo.urlArchivo;
    final message =
        url != null
            ? 'Descarga disponible: ${url.replaceAll('\\', '/')} '
            : 'Anexo sin URL disponible';
    _showNotification(message, background: AppTheme.colorPrimario);
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return 'Tamaño desconocido';
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    var index = 0;
    while (size >= 1024 && index < units.length - 1) {
      size /= 1024;
      index++;
    }
    return '${size.toStringAsFixed(size < 10 ? 2 : 1)} ${units[index]}';
  }

  void _showNotification(
    String mensaje, {
    Color background = AppTheme.colorPrimario,
  }) {
    if (!mounted) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje, maxLines: 3, overflow: TextOverflow.ellipsis),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    });
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

  Widget _buildQrCard(Documento doc, ThemeData theme) {
    if (_qrData == null) return const SizedBox.shrink();
    return AnimatedCard(
      delay: const Duration(milliseconds: 100),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                QrImageView(
                  data: _qrData!,
                  version: QrVersions.auto,
                  size: 80.0,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppTheme.colorPrimario,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CÓDIGO QR',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _qrData!,
                          style: GoogleFonts.robotoMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Autenticidad del documento',
                        style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _descargarCodigoQR(doc),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: const Text('PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple.shade700,
                      side: BorderSide(color: Colors.purple.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Botón Imagen PNG (verde) - COMPATIBLE CON SCANNER
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _descargarCodigoQRImagen(doc),
                    icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                    label: const Text('QR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _qrData!));
                      _showNotification(
                        'Código QR copiado al portapapeles',
                        background: AppTheme.colorExito,
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copiar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
