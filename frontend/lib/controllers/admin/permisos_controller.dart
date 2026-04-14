import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../models/permiso.dart';
import '../../models/permiso_usuario_registro.dart';
import '../../services/permiso_service.dart';
import '../../services/usuario_service.dart';
import '../../utils/utilidades_errores.dart';

/// Controlador para la gestión de permisos de usuarios
class PermisosController extends ChangeNotifier {
  final PermisoService _permisoService;
  final UsuarioService _usuarioService;

  PermisosController({
    required PermisoService permisoService,
    required UsuarioService usuarioService,
  })  : _permisoService = permisoService,
        _usuarioService = usuarioService;

  // ========== ESTADO ==========
  List<Usuario> _usuarios = [];
  List<Permiso> _permisosDisponibles = [];
  List<PermisoUsuarioEntry> _permisosUsuario = [];
  Usuario? _usuarioSeleccionado;
  Map<int, bool> _cambiosLocales = {};
  Map<int, bool> _userPermOriginal = {};

  bool _isLoading = false;
  bool _isSaving = false;

  // ========== GETTERS ==========
  List<Usuario> get usuarios => _usuarios;
  List<Permiso> get permisosDisponibles => _permisosDisponibles;
  List<PermisoUsuarioEntry> get permisosUsuario => _permisosUsuario;
  Usuario? get usuarioSeleccionado => _usuarioSeleccionado;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get hayCambios => _cambiosLocales.isNotEmpty;

  // ========== MÉTODOS PÚBLICOS ==========

  /// Cargar usuarios
  Future<void> cargarUsuarios() async {
    _isLoading = true;
    notifyListeners();

    try {
      _usuarios = await _usuarioService.getAll();
    } catch (e) {
      throw Exception(ErrorHelper.getErrorMessage(e));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cargar permisos disponibles
  Future<void> cargarPermisosDisponibles() async {
    try {
      _permisosDisponibles = await _permisoService.getAll();
    } catch (e) {
      throw Exception(ErrorHelper.getErrorMessage(e));
    }
  }

  /// Seleccionar usuario
  Future<void> seleccionarUsuario(Usuario usuario) async {
    _usuarioSeleccionado = usuario;
    _cambiosLocales.clear();
    notifyListeners();
    await _cargarPermisosUsuario(usuario);
  }

  /// Cambiar estado de un permiso
  void cambiarPermiso(PermisoUsuarioEntry entry, bool value) {
    final permisoId = entry.permiso.id;
    final originalState = _userPermOriginal[permisoId] ?? false;

    if (value == originalState) {
      _cambiosLocales.remove(permisoId);
    } else {
      _cambiosLocales[permisoId] = value;
    }
    notifyListeners();
  }

  /// Guardar cambios
  Future<void> guardarCambios() async {
    if (_usuarioSeleccionado == null || _isSaving) return;

    _isSaving = true;
    notifyListeners();

    try {
      final usuarioId = _usuarioSeleccionado!.id;
      for (var permisoId in _cambiosLocales.keys) {
        final nuevoEstado = _cambiosLocales[permisoId]!;
        if (nuevoEstado) {
          await _permisoService.asignarPermiso(usuarioId, permisoId);
        } else {
          await _permisoService.revocarPermiso(usuarioId, permisoId);
        }
      }

      await _cargarPermisosUsuario(_usuarioSeleccionado!);
      _cambiosLocales.clear();
    } catch (e) {
      throw Exception(ErrorHelper.getErrorMessage(e));
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Descartar cambios
  void descartarCambios() {
    _cambiosLocales.clear();
    notifyListeners();
  }

  // ========== MÉTODOS PRIVADOS ==========
  Future<void> _cargarPermisosUsuario(Usuario usuario) async {
    try {
      final permisos = await _permisoService.getPermisosUsuarioAdmin(usuario.id);
      _permisosUsuario = permisos;
      
      // Guardar estado original
      _userPermOriginal.clear();
      for (var entry in permisos) {
        _userPermOriginal[entry.permiso.id] = entry.userHas;
      }
      
      notifyListeners();
    } catch (e) {
      throw Exception(ErrorHelper.getErrorMessage(e));
    }
  }
}
