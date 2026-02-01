# Investigación: Cambio de usuario al recargar

## Problema reportado

Al editar permisos desde el usuario **admin** y recargar la página, el sistema muestra que el usuario logueado es **doc_admin** sin haber iniciado sesión con ese usuario.

## Flujo del problema

1. Iniciar sesión como "admin" (admin123)
2. Ir a "Gestión de Permisos"
3. Seleccionar usuario "doc_admin" para editar sus permisos
4. Recargar página (F5)
5. ❌ El sistema muestra que estás logueado como "doc_admin"

## Posibles causas

### 1. Token JWT corrupto o compartido
- El token JWT podría contener información incorrecta
- Al hacer llamadas API, el backend podría estar retornando datos de otro usuario

### 2. SharedPreferences sobrescrito
- Los datos de `user_data`, `user_role`, `user_name` en SharedPreferences podrían estar siendo sobrescritos
- Aunque `permisos_screen.dart` NO guarda en SharedPreferences, otra parte del código podría hacerlo

### 3. Cache del navegador
- El navegador web podría estar cacheando datos incorrectos
- IndexedDB, LocalStorage o SessionStorage podrían tener datos corruptos

## Análisis del código

### ✅ Verificado: permisos_screen.dart NO modifica SharedPreferences
```dart
void _seleccionarUsuario(Usuario usuario) {
  setState(() {
    _usuarioSeleccionado = usuario; // Solo estado local
  });
  // NO hay llamadas a SharedPreferences.setString()
}
```

### ✅ Verificado: api_service.dart NO tiene interceptors sospechosos
- Solo tiene LogInterceptor y manejo de errores 401/403
- NO modifica headers ni datos de usuario

### ⚠️ Punto crítico: _loadAuthState en auth_provider.dart
```dart
Future<void> _loadAuthState() async {
  final prefs = await SharedPreferences.getInstance();
  final userDataString = prefs.getString('user_data');
  _user = jsonDecode(userDataString); // ⚠️ Carga desde SharedPreferences
}
```

## Pasos para diagnosticar

### 1. Agregar logging exhaustivo
Necesitamos ver exactamente QUÉ datos se están cargando al recargar:

```dart
debugPrint('[AUTH] user_data: $userDataString');
debugPrint('[AUTH] user_name: ${prefs.getString('user_name')}');
debugPrint('[AUTH] user_role: ${prefs.getString('user_role')}');
debugPrint('[AUTH] Parsed user: ${_user?['nombreUsuario']}');
```

### 2. Verificar token JWT
El token debe contener el `sub` (user ID) correcto. Verificar en:
- https://jwt.io
- Logs del backend

### 3. Limpiar storage del navegador
Abrir DevTools → Application → Storage:
- Clear IndexedDB
- Clear Local Storage
- Clear Session Storage
- Clear Cookies

### 4. Verificar si hay múltiples sesiones
¿Tienes varias pestañas abiertas con usuarios diferentes?

## Soluciones propuestas

### Solución 1: Agregar validación de token vs datos locales
```dart
Future<void> _loadAuthState() async {
  // ... cargar datos ...
  
  // Validar que el token y los datos coincidan
  final tokenUserId = _getUserIdFromToken(_token);
  final localUserId = _user?['id'];
  
  if (tokenUserId != localUserId) {
    debugPrint('[AUTH] ⚠️ MISMATCH: Token user=$tokenUserId, Local user=$localUserId');
    await logout(); // Forzar logout por seguridad
    return;
  }
}
```

### Solución 2: Endpoint de verificación de sesión
Agregar un endpoint `/auth/verify` que retorne los datos del usuario del token actual:

```dart
Future<void> _loadAuthState() async {
  // ... cargar token ...
  
  // Verificar con el backend
  final response = await apiService.get('/auth/verify');
  final serverUser = response.data['user'];
  
  // Actualizar datos locales con los del servidor
  _user = serverUser;
  await prefs.setString('user_data', jsonEncode(serverUser));
}
```

### Solución 3: Limpiar storage al guardar permisos
En `permisos_screen.dart`, después de guardar:

```dart
Future<void> _guardarCambios() async {
  // ... guardar permisos ...
  
  // Forzar recarga de auth state para evitar corrupción
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  await authProvider.refreshAuthState();
}
```

## Siguiente paso

**URGENTE**: Necesitamos que el usuario ejecute esto en la consola del navegador (F12) cuando ocurra el problema:

```javascript
// Ver datos almacenados
console.log('SharedPreferences keys:', Object.keys(localStorage));
console.log('user_data:', localStorage.getItem('flutter.user_data'));
console.log('user_name:', localStorage.getItem('flutter.user_name'));
console.log('user_role:', localStorage.getItem('flutter.user_role'));
```

Esto nos dirá exactamente qué datos están almacenados cuando el problema ocurre.
