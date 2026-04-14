import 'permiso.dart';

/// Entry para representar el estado de un permiso de usuario (admin)
class PermisoUsuarioEntry {
  final Permiso permiso;
  final bool roleHas;
  final bool userHas;
  final bool isDenied;

  PermisoUsuarioEntry({
    required this.permiso,
    required this.roleHas,
    required this.userHas,
    required this.isDenied,
  });
}
