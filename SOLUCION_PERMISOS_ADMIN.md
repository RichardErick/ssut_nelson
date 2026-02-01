# Solución: Admin perdió acceso a Roles y Permisos

## Problema

Al modificar permisos de un usuario en la pantalla "Gestión de Permisos" o "Roles y Permisos", el administrador cambió accidentalmente el rol del usuario **admin** (o modificó su propio rol), causando que perdiera acceso a las secciones:
- **Roles y Permisos**
- **Gestión de Permisos** (dependiendo del nuevo rol)

## Causa

El menú "Roles y Permisos" solo se muestra cuando `canManageUserPermissions = true`, que significa `_role == UserRole.administradorSistema`. Si el rol del admin cambió de "AdministradorSistema" o "Administrador" a otro rol (ej. "AdministradorDocumentos", "Contador"), pierde ese acceso.

## Solución rápida: Corregir en la base de datos

1. **Conectar a PostgreSQL:**
   ```bash
   psql -U postgres -d sistema_gestion_documental
   ```

2. **Verificar el usuario admin:**
   ```sql
   SELECT id, nombre_usuario, rol, activo FROM usuarios WHERE nombre_usuario = 'admin';
   ```

3. **Restaurar el rol correcto:**
   ```sql
   UPDATE usuarios 
   SET rol = 'Administrador'  -- o 'AdministradorSistema' según tu esquema
   WHERE nombre_usuario = 'admin';
   ```

4. **Cerrar sesión y volver a iniciar sesión** en la app para que el cambio se aplique.

## Prevención: Protección en el frontend

Para evitar que un admin cambie su propio rol accidentalmente, se debe agregar una validación en `roles_permissions_screen.dart`:

### Opción 1: Advertencia al cambiar rol propio

```dart
Future<void> _updateRol(Usuario usuario, String nuevoRol) async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final currentUserId = authProvider.user?['id'];
  
  // Si está modificando su propio usuario
  if (usuario.id == currentUserId) {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Cambiar tu propio rol'),
        content: const Text(
          'Estás a punto de cambiar tu propio rol. '
          'Podrías perder permisos de administrador.\n\n'
          '¿Estás seguro?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Sí, cambiar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
  }
  
  // Resto del código...
}
```

### Opción 2: Bloquear cambio de rol propio

```dart
Future<void> _updateRol(Usuario usuario, String nuevoRol) async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final currentUserId = authProvider.user?['id'];
  
  if (usuario.id == currentUserId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No puedes cambiar tu propio rol'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  
  // Resto del código...
}
```

## Nota

Las opciones de protección deben implementarse también en:
- La pantalla de gestión de permisos individuales (si permite cambiar roles)
- Cualquier endpoint del backend que modifique roles (validar que el usuario no esté modificando su propio rol si es crítico)
