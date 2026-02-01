import 'package:flutter/material.dart';
import '../../models/carpeta.dart';
import '../../services/carpeta_service.dart';
import '../../utils/error_helper.dart';

/// Controlador para la gestión de carpetas
class CarpetasController extends ChangeNotifier {
  final CarpetaService _service;

  CarpetasController({required CarpetaService service}) : _service = service;

  // ========== ESTADO ==========
  List<Carpeta> _carpetas = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String _gestion = DateTime.now().year.toString();

  // ========== GETTERS ==========
  List<Carpeta> get carpetas => _carpetas;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String get gestion => _gestion;

  // ========== MÉTODOS PÚBLICOS ==========

  /// Cargar carpetas
  Future<void> cargarCarpetas() async {
    _isLoading = true;
    notifyListeners();

    try {
      final carpetas = await _service.getArbol(_gestion);
      _carpetas = carpetas;
    } catch (e) {
      throw Exception(ErrorHelper.getErrorMessage(e));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Eliminar carpeta (borrado real en BD, cascada si tiene subcarpetas/documentos).
  Future<void> eliminarCarpeta(Carpeta carpeta) async {
    await _service.delete(carpeta.id, hard: true);
    await cargarCarpetas();
  }

  /// Cambiar gestión
  void cambiarGestion(String nuevaGestion) {
    _gestion = nuevaGestion;
    cargarCarpetas();
  }
}
