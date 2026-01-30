import 'package:flutter/material.dart';
import '../models/carpeta.dart';
import '../models/documento.dart';

/// Provider para manejar actualizaciones en tiempo real de datos
class DataProvider extends ChangeNotifier {
  // Eventos de carpetas
  void notifyCarpetaCreated(Carpeta carpeta) {
    notifyListeners();
  }

  void notifyCarpetaUpdated(Carpeta carpeta) {
    notifyListeners();
  }

  void notifyCarpetaDeleted(int carpetaId) {
    notifyListeners();
  }

  // Eventos de documentos
  void notifyDocumentoCreated(Documento documento) {
    notifyListeners();
  }

  void notifyDocumentoUpdated(Documento documento) {
    notifyListeners();
  }

  void notifyDocumentoDeleted(int documentoId) {
    notifyListeners();
  }

  // Método para forzar actualización general
  void refresh() {
    notifyListeners();
  }
}