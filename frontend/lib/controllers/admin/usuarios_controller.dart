import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../services/usuario_service.dart';
import '../../utils/utilidades_errores.dart';

/// Controlador para la gestión de usuarios
class UsuariosController extends ChangeNotifier {
  final UsuarioService _service;

  UsuariosController({required UsuarioService service}) : _service = service;

  // ========== ESTADO ==========
  List<Usuario> _usuarios = [];
  bool _isLoading = false;
  String _filtroRol = 'todos';
  String _busqueda = '';

  // ========== GETTERS ==========
  List<Usuario> get usuarios => _usuariosFiltrados;
  bool get isLoading => _isLoading;
  String get filtroRol => _filtroRol;
  String get busqueda => _busqueda;

  List<Usuario> get _usuariosFiltrados {
    var filtrados = _usuarios;

    if (_filtroRol != 'todos') {
      filtrados = filtrados.where((u) => u.rol == _filtroRol).toList();
    }

    if (_busqueda.isNotEmpty) {
      final query = _busqueda.toLowerCase();
      filtrados = filtrados.where((u) {
        return u.nombreUsuario.toLowerCase().contains(query) ||
            u.nombreCompleto.toLowerCase().contains(query) ||
            (u.email ?? '').toLowerCase().contains(query);
      }).toList();
    }

    return filtrados;
  }

  // ========== MÉTODOS PÚBLICOS ==========

  /// Cargar usuarios
  Future<void> cargarUsuarios() async {
    _isLoading = true;
    notifyListeners();

    try {
      _usuarios = await _service.getAll();
    } catch (e) {
      throw Exception(ErrorHelper.getErrorMessage(e));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Eliminar usuario
  Future<void> eliminarUsuario(int id) async {
    await _service.deleteUsuario(id);
    await cargarUsuarios();
  }

  /// Cambiar filtro de rol
  void cambiarFiltroRol(String rol) {
    _filtroRol = rol;
    notifyListeners();
  }

  /// Actualizar búsqueda
  void actualizarBusqueda(String query) {
    _busqueda = query;
    notifyListeners();
  }

  /// Activar/Desactivar usuario
  Future<void> toggleActivoUsuario(int id, bool activo) async {
    // Implementar según API
    await cargarUsuarios();
  }
}
