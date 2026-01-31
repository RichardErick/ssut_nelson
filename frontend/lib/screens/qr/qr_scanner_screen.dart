import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
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
          codigoLimpio = partes.last;
        }
      }

      print('DEBUG: Código procesado: $codigoLimpio');

      // Intentar buscar por IdDocumento (que es el código)
      Documento? documento;
      try {
        documento = await service.getByIdDocumento(codigoLimpio);
      } catch (e) {
        print('DEBUG: Error buscando por IdDocumento: $e');
        // Si falla, intentar buscar por QR
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

  Future<void> _buscarDesdeImagen() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _isSearching = true);
    try {
      final bytes = await file.readAsBytes();

      // Verificar si es un PDF
      if (bytes.length > 4 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Archivo PDF detectado. Para leer QR de PDFs, abra el PDF y tome una captura de pantalla del código QR, luego seleccione esa imagen.',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.blue.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        }
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
                    'No se pudo leer un QR en la imagen. Asegúrese de que:\n• La imagen sea clara y bien iluminada\n• El código QR esté completo y visible\n• No sea un archivo PDF',
                    maxLines: 4,
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

      _qrCodeController.text = codigo;
      await _buscarPorCodigo(codigo);
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
            content: Text('Error leyendo QR: $e'),
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
                        'Búsqueda por Código QR',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ingrese el código QR del documento o pegue un link compartible para buscarlo rápidamente',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showScanInfo,
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              label: const Text('Escanear QR'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isSearching ? null : _buscarPorQR,
                              icon: const Icon(Icons.search_rounded),
                              label: const Text('Buscar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSearching ? null : _buscarDesdeImagen,
                          icon: const Icon(Icons.photo_library_rounded),
                          label: const Text('Adjuntar foto QR'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Campo de entrada
                      TextField(
                        controller: _qrCodeController,
                        decoration: InputDecoration(
                          labelText: 'Código QR o Link Compartible',
                          hintText:
                              'Pegue el código QR o link del documento aquí',
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
                      const SizedBox(height: 24),
                      // Botón de búsqueda
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
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 24),
                      // Información adicional
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.blue.shade700,
                                  size: 24,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Instrucciones para usar códigos QR',
                                    style: TextStyle(
                                      color: Colors.blue.shade900,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '• Para archivos PDF: Abra el PDF, tome una captura de pantalla del QR y seleccione esa imagen\n'
                              '• Para imágenes PNG/JPG: Seleccione directamente la imagen del QR\n'
                              '• También puede copiar y pegar el código QR manualmente\n'
                              '• Los links compartibles (DOC-SHARE:...) funcionan directamente',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontSize: 13,
                                height: 1.4,
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
