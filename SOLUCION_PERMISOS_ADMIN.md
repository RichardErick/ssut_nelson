# Solución: Admin perdió acceso a Roles y Permisos al recargar

## Problema

Al modificar permisos de un usuario en la pantalla "Gestión de Permisos" y **recargar la página**, el administrador perdía acceso a las secciones:
- **Roles y Permisos**
- **Gestión de Permisos**

Mostraba el mensaje: *"No tienes permisos para acceder a esta sección, Rol actual: Administrador de Documentos"* cuando el usuario debería ser "Administrador del Sistema".

## Causa raíz

Había **dos problemas**:

### 1. Rol mal interpretado al recargar (YA CORREGIDO)
En `auth_provider.dart`, la función `_loadAuthState()` llamaba a `_parseRole()` sin contexto del usuario (username y nombre completo vacíos). Esto causaba que el rol genérico "Administrador" se interpretara incorrectamente como "AdministradorDocumentos" en lugar de "AdministradorSistema".

**Flujo del error:**
1. Usuario recarga la página
2. `_loadAuthState()` lee rol "Administrador" de SharedPreferences
3. Llama a `_parseRole()` que usa contexto vacío
4. El parser no puede determinar si es admin sistema o documentos
5. Por defecto asigna "AdministradorDocumentos"
6. `canManageUserPermissions` retorna `false`
7. Pantalla muestra "No tienes permisos"

### 2. Guardado de permisos no implementado (YA CORREGIDO)
La función `_guardarCambios()` en `permisos_screen.dart` solo mostraba un mensaje de éxito pero **no guardaba nada** en el backend.

## ✅ Solución implementada (ya en el código)

### 1. Mantener contexto de usuario al recargar
**Archivo:** `frontend/lib/providers/auth_provider.dart`

Se modificó `_loadAuthState()` para:
1. Cargar los datos del usuario (username y nombre completo) ANTES de parsear el rol
2. Llamar a `_parseRoleWithContext()` con el contexto correcto
3. Ahora el rol "Administrador" se interpreta correctamente según el usuario

```dart
// Antes (INCORRECTO):
if (roleString != null) {
  _role = _parseRole(roleString); // Sin contexto ❌
}

// Ahora (CORRECTO):
if (roleString != null) {
  final userUsername = (_user?['nombreUsuario'] as String?) ?? '';
  final fullName = (_user?['nombreCompleto'] as String?) ?? '';
  _role = _parseRoleWithContext(roleString, userUsername, fullName); // Con contexto ✅
}
```

### 2. Implementar guardado real de permisos
**Archivo:** `frontend/lib/screens/admin/permisos_screen.dart`

Se implementó la lógica completa en `_guardarCambios()`:
- Compara permisos actuales vs permisos del rol base
- Llama a `PermisoService.asignarPermiso()` o `revocarPermiso()` según corresponda
- Muestra cantidad de cambios aplicados

## Solución alternativa: Corregir en la base de datos (si persiste)

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
