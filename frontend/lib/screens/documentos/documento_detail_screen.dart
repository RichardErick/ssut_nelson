import 'dart:html' as html;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/anexo.dart';
import '../../models/documento.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_provider.dart';
import '../../services/anexo_service.dart';
import '../../services/documento_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_helper.dart';
import '../../widgets/animated_card.dart';

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

    // Inicializar QR de forma independiente del puerto
    String? initialQrData = widget.documento.urlQR ?? widget.documento.codigoQR;

    // Si viene como URL, extraer solo el código
    if (initialQrData != null && initialQrData.startsWith('http')) {
      final partes = initialQrData.split('/');
      if (partes.isNotEmpty) {
        initialQrData = partes.last; // Extraer solo el código del documento
      }
    }

    // Si no hay código válido, usar el código del documento
    _qrData = _normalizeQrData(initialQrData ?? widget.documento.codigo);

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

      // Extraer solo el código del documento, no la URL completa
      String? qrContent =
          response['qrContent'] ??
          response['QrContent'] ??
          widget.documento.urlQR ??
          widget.documento.codigoQR;

      // Si viene como URL, extraer solo el código
      if (qrContent != null && qrContent.startsWith('http')) {
        final partes = qrContent.split('/');
        if (partes.isNotEmpty) {
          qrContent = partes.last; // Extraer solo el código del documento
        }
      }

      // Si no hay código, usar el código del documento
      qrContent = qrContent ?? widget.documento.codigo;

      if (mounted) {
        setState(() => _qrData = _normalizeQrData(qrContent));
      }
    } catch (e) {
      if (mounted) {
        // Si falla la generación, usar el código del documento
        setState(() => _qrData = widget.documento.codigo);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'QR generado localmente: ${ErrorHelper.getErrorMessage(e)}',
            ),
            backgroundColor: AppTheme.colorAdvertencia,
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
                      flex: 4,
                      child: _buildLeftColumn(doc, dateFormat, theme),
                    ),
                    const SizedBox(width: 24),
                    Expanded(flex: 3, child: _buildRightColumn(theme)),
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
        if (Provider.of<AuthProvider>(
          context,
        ).hasPermission('borrar_documento'))
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
        if (Provider.of<AuthProvider>(
          context,
        ).hasPermission('editar_metadatos'))
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
                children:
                    doc.palabrasClave
                        .map((tag) => _buildKeywordChip(tag, theme))
                        .toList(),
              ),
            ],
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
                color: theme.colorScheme.primary,
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
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _pickAndUploadAnexo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
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
                  size: 100.0,
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
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
                      const SizedBox(height: 8),
                      Text(
                        'Autenticidad del documento',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Botones simplificados
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _descargarQRSimple(doc),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Descargar QR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _qrData!));
                      _showNotification(
                        'Código QR copiado al portapapeles',
                        background: AppTheme.colorExito,
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copiar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  // Helper methods
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

  // Action methods
  Future<void> _compartirDocumento(Documento doc) async {
    try {
      final linkCompartible = _generarLinkCompartible(doc);
      await Clipboard.setData(ClipboardData(text: linkCompartible));

      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
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
                    await Clipboard.setData(
                      ClipboardData(text: linkCompartible),
                    );
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
    // Usar solo el código del documento, no URLs con puertos
    return 'DOC-SHARE:${doc.codigo}:${doc.id}';
  }

  Future<void> _descargarCodigoQR(Documento doc) async {
    try {
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

      final qrImageBytes = await _generarImagenQRPNG(qrDataSafe, doc);
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

  Future<void> _descargarQRSimple(Documento doc) async {
    try {
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

      // Mostrar opciones de descarga
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.qr_code_rounded, color: Colors.green.shade700),
                  const SizedBox(width: 12),
                  const Text('Descargar Código QR'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Selecciona el formato de descarga:',
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _descargarQRComoPNG(qrDataSafe, doc);
                      },
                      icon: const Icon(Icons.image_rounded),
                      label: const Text('Imagen PNG (Recomendado)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _descargarQRComoPDF(qrDataSafe, doc);
                      },
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('PDF con Información'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple.shade700,
                        side: BorderSide(color: Colors.purple.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
      );
    } catch (e) {
      _showNotification(
        'Error al preparar descarga: ${ErrorHelper.getErrorMessage(e)}',
        background: AppTheme.colorError,
      );
    }
  }

  Future<void> _descargarQRComoPNG(String qrData, Documento doc) async {
    try {
      final pngBytes = await _generarQRBytesPNG(qrData);
      await _descargarArchivo(pngBytes, 'QR_${doc.codigo}.png');
      _showNotification(
        'Imagen PNG descargada: QR_${doc.codigo}.png',
        background: AppTheme.colorExito,
      );
    } catch (e) {
      _showNotification(
        'Error al descargar PNG: ${ErrorHelper.getErrorMessage(e)}',
        background: AppTheme.colorError,
      );
    }
  }

  /// Genera bytes de una imagen PNG del código QR (sin fallback a PDF).
  Future<Uint8List> _generarQRBytesPNG(String qrData) async {
    const int size = 400;
    const int qrSize = 320;
    const int padding = (size - qrSize) ~/ 2;

    final qrPainter = QrPainter(
      data: qrData,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
      gapless: false,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      Paint()..color = Colors.white,
    );
    canvas.save();
    canvas.translate(padding.toDouble(), padding.toDouble());
    qrPainter.paint(canvas, Size(qrSize.toDouble(), qrSize.toDouble()));
    canvas.restore();

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('No se pudo codificar la imagen como PNG');
    }
    return byteData.buffer.asUint8List();
  }

  Future<void> _descargarQRComoPDF(String qrData, Documento doc) async {
    try {
      final qrImageBytes = await _generarImagenQRPNG(qrData, doc);
      await _descargarArchivo(qrImageBytes, 'QR_Info_${doc.codigo}.pdf');

      _showNotification(
        'PDF con información descargado: QR_Info_${doc.codigo}.pdf',
        background: AppTheme.colorExito,
      );
    } catch (e) {
      _showNotification(
        'Error al descargar PDF: ${ErrorHelper.getErrorMessage(e)}',
        background: AppTheme.colorError,
      );
    }
  }

  Future<Uint8List> _capturarQRComoImagen(String qrData, Documento doc) async {
    try {
      // Crear una imagen PNG real del QR tal como se ve en pantalla
      const int size = 400;
      const int qrSize = 320;
      const int padding = (size - qrSize) ~/ 2;

      // Generar el QR usando qr_flutter internamente
      final qrPainter = QrPainter(
        data: qrData,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
        gapless: false,
      );

      // Crear un canvas para dibujar
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      );

      // Fondo blanco
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        Paint()..color = Colors.white,
      );

      // Dibujar el QR centrado
      canvas.save();
      canvas.translate(padding.toDouble(), padding.toDouble());
      qrPainter.paint(canvas, Size(qrSize.toDouble(), qrSize.toDouble()));
      canvas.restore();

      // Convertir a imagen
      final picture = recorder.endRecording();
      final img = await picture.toImage(size, size);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      return byteData!.buffer.asUint8List();
    } catch (e) {
      print('Error generando imagen QR real: $e');
      // Fallback: usar PDF optimizado
      return await _generarPDFOptimizado(qrData, doc);
    }
  }

  Future<Uint8List> _generarImagenQRPNG(String qrData, Documento doc) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(400, 400, marginAll: 20),
          build:
              (context) => pw.Container(
                width: 360,
                height: 360,
                color: PdfColors.white,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'QR - ${doc.codigo}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(20),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.all(color: PdfColors.black, width: 2),
                      ),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: qrData,
                        width: 280,
                        height: 280,
                        drawText: false,
                      ),
                    ),
                    pw.SizedBox(height: 15),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        border: pw.Border.all(color: PdfColors.grey400),
                      ),
                      child: pw.Text(
                        qrData,
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
        ),
      );
      //DEBERIA RETORNAR EL PNG O SALIR ERROR EN TODO CASO
      return pdf.save();
    } catch (e) {
      print('Error generando QR PNG: $e');
      rethrow;
    }
  }

  Future<Uint8List> _generarImagenPNGReal(String qrData, Documento doc) async {
    try {
      return await _generarPDFOptimizado(qrData, doc);
    } catch (e) {
      print('Error generando imagen PNG: $e');
      return await _generarImagenSimplePDF(qrData);
    }
  }

  Future<Uint8List> _generarPDFOptimizado(String qrData, Documento doc) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build:
            (context) => pw.Container(
              color: PdfColors.white,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'QR - ${doc.codigo}',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
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
                  pw.Container(
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Text(
                      qrData,
                      style: const pw.TextStyle(fontSize: 12),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.SizedBox(height: 15),
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
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(400, 400, marginAll: 0),
        build:
            (context) => pw.Container(
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

  Future<void> _descargarArchivo(Uint8List bytes, String fileName) async {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor =
        html.document.createElement('a') as html.AnchorElement
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
      if (_anexos.isNotEmpty) {
        final primerAnexo = _anexos.first;
        final service = Provider.of<AnexoService>(context, listen: false);
        final pdfBytes = await service.descargarBytes(primerAnexo.id);

        await _descargarArchivo(pdfBytes, primerAnexo.nombreArchivo);

        _showNotification(
          'Descarga iniciada: ${primerAnexo.nombreArchivo}',
          background: AppTheme.colorExito,
        );
      } else {
        final pdfBytes = await _buildPdfBytes();
        await _descargarArchivo(
          pdfBytes,
          'Documento_${widget.documento.codigo}.pdf',
        );

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
      builder:
          (context) => AlertDialog(
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

  Future<void> _loadAnexos() async {
    setState(() => _isLoadingAnexos = true);
    try {
      final service = Provider.of<AnexoService>(context, listen: false);
      final anexos = await service.listarPorDocumento(widget.documento.id);
      if (mounted) {
        setState(() => _anexos = anexos);

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
        print(
          'DEBUG: Preview cargado exitosamente para: ${anexo.nombreArchivo}',
        );
      }
    } catch (e) {
      print('DEBUG: Error cargando preview: $e');
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
}
