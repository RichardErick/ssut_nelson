enum UserRole {
  administradorSistema,
  administradorDocumentos,
  contador,
  gerente;

  String get displayName {
    switch (this) {
      case UserRole.administradorSistema:
        return 'Administrador de Sistema';
      case UserRole.administradorDocumentos:
        return 'Administrador de Documentos';
      case UserRole.contador:
        return 'Contador';
      case UserRole.gerente:
        return 'Gerente';
    }
  }

  String get codigo {
    switch (this) {
      case UserRole.administradorSistema:
        return 'AdministradorSistema';
      case UserRole.administradorDocumentos:
        return 'AdministradorDocumentos';
      case UserRole.contador:
        return 'Contador';
      case UserRole.gerente:
        return 'Gerente';
    }
  }
}
