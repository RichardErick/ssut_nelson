import 'package:flutter/material.dart';
import '../../models/documento.dart';
import '../../services/documento_service.dart';
import '../../utils/utilidades_errores.dart';

/// Controlador para el detalle de un documento
class DocumentoDetailController extends ChangeNotifier {
  final DocumentoService _service;
  final Documento documento;

  DocumentoDetailController({
    required DocumentoService service,
    required this.documento,
  }) : _service = service;

  // ========== ESTADO ==========
  String? _qrData;
  bool _isGeneratingQr = false;

  // ========== GETTERS ==========
  String? get qrData => _qrData;
  bool get isGeneratingQr => _isGeneratingQr;

  // ========== MÉTODOS PÚBLICOS ==========

  /// Inicializar QR
  void initQr() {
    _qrData = _normalizeQrData(documento.urlQR ?? documento.codigoQR);
    if (_qrData == null) {
      generateQr();
    }
  }

  /// Generar código QR
  Future<void> generateQr() async {
    if (_isGeneratingQr) return;

    _isGeneratingQr = true;
    notifyListeners();

    try {
      final response = await _service.generarQR(documento.id);
      final qrContent = response['qrContent'] ??
          response['QrContent'] ??
          documento.urlQR ??
          documento.codigoQR;
      _qrData = _normalizeQrData(qrContent?.toString());
    } catch (e) {
      throw Exception(ErrorHelper.getErrorMessage(e));
    } finally {
      _isGeneratingQr = false;
      notifyListeners();
    }
  }

  /// Eliminar documento
  Future<void> eliminarDocumento() async {
    await _service.delete(documento.id);
  }

  // ========== MÉTODOS PRIVADOS ==========
  String? _normalizeQrData(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
