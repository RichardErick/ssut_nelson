import 'package:flutter/material.dart';
import '../../../models/carpeta.dart';
import '../../../services/carpeta_service.dart';

/// Controller for managing Carpetas (Folders) business logic
class CarpetasController extends ChangeNotifier {
  final CarpetaService _carpetaService;

  CarpetasController(this._carpetaService);

  // State
  Map<String, List<Carpeta>> _carpetasPorGestion = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  Map<String, List<Carpeta>> get carpetasPorGestion => _carpetasPorGestion;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Constants
  static const String moduloEgresos = 'Comprobante de Egreso';
  static const String moduloIngresos = 'Comprobante de Ingreso';
  static const List<String> gestionesVisibles = ['2025', '2026'];

  /// Check if main folders exist across all gestiones
  bool get hasMainFolder {
    for (final gestion in gestionesVisibles) {
      final carpetas = _carpetasPorGestion[gestion];
      if (carpetas != null &&
          carpetas.any((c) => c.nombre == moduloEgresos || c.nombre == moduloIngresos)) {
        return true;
      }
    }
    return false;
  }

  /// Load all carpetas for all gestiones
  Future<void> loadCarpetas() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final Map<String, List<Carpeta>> tempMap = {};

      await Future.wait(gestionesVisibles.map((gestion) async {
        try {
          final carpetas = await _carpetaService.getArbol(gestion);
          tempMap[gestion] = carpetas;
        } catch (e) {
          print('Error loading gestion $gestion: $e');
          tempMap[gestion] = [];
        }
      }));

      _carpetasPorGestion = tempMap;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error al cargar carpetas: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a carpeta (folder)
  Future<void> deleteCarpeta(int carpetaId, {bool hard = true}) async {
    try {
      await _carpetaService.delete(carpetaId, hard: hard);
      await loadCarpetas(); // Reload after deletion
    } catch (e) {
      _error = 'No se pudo eliminar: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Get carpetas for a specific gestion
  List<Carpeta> getCarpetasForGestion(String gestion) {
    return _carpetasPorGestion[gestion] ?? [];
  }

  /// Check if there are any carpetas across all gestiones
  bool get hasCarpetas {
    return _carpetasPorGestion.values.any((l) => l.isNotEmpty);
  }
}
