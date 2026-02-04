import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';
import 'package:zxing2/qrcode.dart';

import '../../models/documento.dart';
import '../../services/documento_service.dart';
import '../../utils/error_helper.dart';
import '../../widgets/animated_card.dart';
import '../documentos/documento_detail_screen.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _qrCodeController = TextEditingController();
  bool _isSearching = false;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _qrCodeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Quita el prefijo "QR_" o "QR " del código para buscar por IdDocumento (el backend no usa ese prefijo).
  static String _quitarPrefijoQr(String codigo) {
    final s = codigo.trim();
    if (s.length >= 3) {
      final inicio = s.toUpperCase().substring(0, 3);
      if (inicio == 'QR_' || inicio == 'QR ') return s.substring(3).trim();
    }
    return s;
  }

  Future<void> _buscarPorCodigo(String codigoQr) async {
    setState(() => _isSearching = true);
    try {
      final service = Provider.of<DocumentoService>(context, listen: false);

      // Limpiar el código QR
      String codigoLimpio = codigoQr.trim();

      print('DEBUG: Código QR original: $codigoLimpio');

      // Verificar si es un link compartible
      if (codigoLimpio.startsWith('DOC-SHARE:')) {
        await _procesarLinkCompartible(codigoLimpio);
        return;
      }

      // Si es una URL completa, extraer el código del documento
      if (codigoLimpio.startsWith('http')) {
        // Formato: http://localhost:5286/documentos/ver/CI-CONT-2026-0001
        final partes = codigoLimpio.split('/');
        if (partes.isNotEmpty) {
          codigoLimpio = partes.last.trim();
        }
      }

      // Quitar prefijo "QR_" o "QR " siempre (el backend guarda IdDocumento sin ese prefijo)
      codigoLimpio = _quitarPrefijoQr(codigoLimpio);

      print('DEBUG: Código procesado (sin prefijo QR): $codigoLimpio');

      // Buscar por IdDocumento (código del documento: CI-CONT-2026-4213)
      Documento? documento;
      try {
        documento = await service.getByIdDocumento(codigoLimpio);
      } catch (e) {
        print('DEBUG: Error buscando por IdDocumento: $e');
        // Si falla, intentar por QR (por si el backend tiene endpoint por CodigoQR)
        try {
          documento = await service.getByQRCode(codigoLimpio);
        } catch (e2) {
          print('DEBUG: Error buscando por QR: $e2');
        }
      }

      if (!mounted) return;

      if (documento != null) {
        final doc = documento; // Local variable so closure gets non-null type
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentoDetailScreen(documento: doc),
          ),
        );
        _qrCodeController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Documento encontrado: ${doc.codigo}'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No se encontró documento con código: $codigoLimpio\n\nVerifica que el código sea correcto.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error en búsqueda: ${ErrorHelper.getErrorMessage(e)}',
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _procesarLinkCompartible(String linkCompartible) async {
    try {
      // Formato esperado: DOC-SHARE:{codigo}:{id}
      final partes = linkCompartible.split(':');
      if (partes.length != 3 || partes[0] != 'DOC-SHARE') {
        throw Exception('Formato de link inválido');
      }

      final codigo = partes[1];
      final id = int.tryParse(partes[2]);

      if (id == null) {
        throw Exception('ID de documento inválido');
      }

      final service = Provider.of<DocumentoService>(context, listen: false);

      // Intentar buscar por ID primero
      final documento = await service.getById(id);

      if (!mounted) return;

      if (documento != null) {
        // Verificar que el código coincida para mayor seguridad
        if (documento.codigo == codigo) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DocumentoDetailScreen(documento: documento),
            ),
          );
          _qrCodeController.clear();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Documento encontrado: ${documento.codigo}'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        } else {
          throw Exception('El código del documento no coincide');
        }
      } else {
        throw Exception('Documento no encontrado');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error procesando link compartible: ${e.toString()}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _buscarPorQR() async {
    final codigo = _qrCodeController.text.trim();
    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Ingrese un código QR'),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    await _buscarPorCodigo(codigo);
  }

  /// Selecciona imagen o PDF. Imagen → extrae QR con _extraerQrDeBytes. PDF → extrae QR con _extraerQrDePdf (sin diálogo).
  /// No se muestra ningún diálogo "Buscar por PDF": el PDF se procesa directamente y se busca el documento.
  Future<void> _buscarDesdeArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo leer el archivo. Pruebe con otro.'),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    await _procesarBytesComoImagenOPdf(bytes);
  }

  Future<void> _procesarBytesComoImagenOPdf(Uint8List bytes) async {
    setState(() => _isSearching = true);
    try {
      final esPdf = bytes.length > 4 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46;

      if (esPdf) {
        // Extraer QR de PDF: renderizar páginas y buscar QR en cada una
        final codigo = await _extraerQrDePdf(bytes);
        if (!mounted) return;
        if (codigo != null && codigo.isNotEmpty) {
          final codigoLimpio = _quitarPrefijoQr(codigo);
          _qrCodeController.text = codigoLimpio;
          await _buscarPorCodigo(codigoLimpio);
          return;
        }
        // Si no se encontró QR en el PDF, mostrar mensaje
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No se encontró código QR en las páginas del PDF. Verifique que el QR esté visible.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      final codigo = _extraerQrDeBytes(bytes);

      if (!mounted) return;

      if (codigo == null || codigo.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No se encontró un código QR en la imagen. Use una foto clara del QR o escriba el código abajo.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      final codigoLimpio = _quitarPrefijoQr(codigo);
      _qrCodeController.text = codigoLimpio;
      await _buscarPorCodigo(codigoLimpio);
    } on NotFoundException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se detectó un código QR en la imagen'),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error leyendo archivo: ${ErrorHelper.getErrorMessage(e)}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  /// Extrae código QR de un PDF: renderiza las primeras páginas como imágenes y busca QR en cada una.
  Future<String?> _extraerQrDePdf(Uint8List pdfBytes) async {
    try {
      final document = await PdfDocument.openData(pdfBytes);
      final pageCount = document.pagesCount;
      final maxPagesToScan = pageCount > 5 ? 5 : pageCount;

      for (int i = 1; i <= maxPagesToScan; i++) {
        try {
          final page = await document.getPage(i);
          // Renderizar a 300 DPI para buena calidad
          final pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.png,
          );
          await page.close();

          if (pageImage == null || pageImage.bytes.isEmpty) continue;

          // Intentar extraer QR de esta página
          final codigo = _extraerQrDeBytes(pageImage.bytes);
          if (codigo != null && codigo.isNotEmpty) {
            await document.close();
            return codigo;
          }
        } catch (e) {
          print('Error procesando página $i del PDF: $e');
          continue;
        }
      }
      await document.close();
      return null;
    } catch (e) {
      print('Error abriendo PDF: $e');
      return null;
    }
  }

  String? _extraerQrDeBytes(Uint8List bytes) {
    try {
      // Primero verificar si es un PDF
      if (bytes.length > 4 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46) {
        print('Archivo detectado como PDF - no se puede procesar como imagen');
        return null;
      }

      // Intentar decodificar como imagen
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        print('No se pudo decodificar la imagen');
        return null;
      }

      // Convertir a formato compatible con zxing2
      final image = decoded.convert(numChannels: 4);
      final pixels =
          image.getBytes(order: img.ChannelOrder.abgr).buffer.asInt32List();

      final source = RGBLuminanceSource(image.width, image.height, pixels);

      // Intentar con HybridBinarizer primero
      try {
        final bitmap = BinaryBitmap(HybridBinarizer(source));
        final result = QRCodeReader().decode(bitmap);
        return result.text.trim();
      } catch (e) {
        print('Error decodificando QR con HybridBinarizer: $e');

        // Si falla, intentar con GlobalHistogramBinarizer
        try {
          final bitmap2 = BinaryBitmap(GlobalHistogramBinarizer(source));
          final result2 = QRCodeReader().decode(bitmap2);
          return result2.text.trim();
        } catch (e2) {
          print('Error con GlobalHistogramBinarizer: $e2');

          // Último intento: mejorar la imagen y probar de nuevo
          try {
            final enhancedImage = _mejorarImagenParaQR(decoded);
            final enhancedPixels =
                enhancedImage
                    .getBytes(order: img.ChannelOrder.abgr)
                    .buffer
                    .asInt32List();

            final enhancedSource = RGBLuminanceSource(
              enhancedImage.width,
              enhancedImage.height,
              enhancedPixels,
            );
            final enhancedBitmap = BinaryBitmap(
              HybridBinarizer(enhancedSource),
            );
            final result3 = QRCodeReader().decode(enhancedBitmap);
            return result3.text.trim();
          } catch (e3) {
            print('Error con imagen mejorada: $e3');
            return null;
          }
        }
      }
    } catch (e) {
      print('Error general extrayendo QR: $e');
      return null;
    }
  }

  img.Image _mejorarImagenParaQR(img.Image original) {
    // Convertir a escala de grises
    var processed = img.grayscale(original);

    // Aumentar contraste significativamente
    processed = img.contrast(processed, contrast: 200);

    // Aplicar un filtro de mediana para reducir ruido
    processed = img.gaussianBlur(processed, radius: 1);

    // Binarización manual (convertir a blanco y negro)
    for (int y = 0; y < processed.height; y++) {
      for (int x = 0; x < processed.width; x++) {
        final pixel = processed.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        final newPixel =
            luminance > 128
                ? img.ColorRgb8(255, 255, 255) // Blanco
                : img.ColorRgb8(0, 0, 0); // Negro
        processed.setPixel(x, y, newPixel);
      }
    }

    return processed;
  }

  void _showScanInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('Escaneo disponible en dispositivos móviles')),
          ],
        ),
        backgroundColor: Colors.blueGrey.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // UI optimizada: campo de código → un solo botón "Buscar Documento" → fila "Subir imagen o PDF" + "Escanear".
    // No hay "Solo imagen (galería)" ni "Foto, PDF o archivo" por separado. Si ves la versión antigua, haz flutter clean y vuelve a ejecutar.
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: AnimatedCard(
                delay: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icono QR animado
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.blue.shade600,
                                    Colors.blue.shade400,
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 64,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Búsqueda por código, foto o PDF',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Escriba el código, pegue un link o suba una foto/PDF del QR para encontrar el documento',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      // Campo de entrada
                      TextField(
                        controller: _qrCodeController,
                        decoration: InputDecoration(
                          labelText: 'Código o link del documento',
                          hintText:
                              'Escriba o pegue el código, link compartible o URL',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.qr_code_rounded,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          suffixIcon:
                              _qrCodeController.text.isNotEmpty
                                  ? IconButton(
                                    icon: Icon(
                                      Icons.clear_rounded,
                                      color: Colors.grey.shade600,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _qrCodeController.clear();
                                      });
                                    },
                                  )
                                  : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.blue.shade700,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          setState(() {});
                        },
                        onSubmitted: (_) => _buscarPorQR(),
                      ),
                      const SizedBox(height: 20),
                      // Botón de búsqueda principal
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isSearching ? null : _buscarPorQR,
                          icon:
                              _isSearching
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Icon(Icons.search_rounded),
                          label: Text(
                            _isSearching ? 'Buscando...' : 'Buscar Documento',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: Colors.blue.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      // Opciones alternativas
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSearching ? null : _buscarDesdeArchivo,
                              icon: const Icon(Icons.photo_library_rounded, size: 20),
                              label: const Text('Subir imagen o PDF'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showScanInfo,
                              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                              label: const Text('Escanear'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Información simplificada
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Escriba el código, pegue un link o suba una imagen/PDF con QR para buscar el documento',
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
