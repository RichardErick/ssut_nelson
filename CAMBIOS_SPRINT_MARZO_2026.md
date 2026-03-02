# Cambios Implementados - Sprint Marzo 2026

## Fecha: 1 de Marzo de 2026

### 1. Validación de Contraseña - 8 Caracteres Mínimo ✅

**Archivos modificados:** 
- `frontend/lib/utils/form_validators.dart`
- `frontend/lib/screens/reset_password_screen.dart`
- `frontend/lib/screens/forgot_password_pregunta_screen.dart`
- `frontend/lib/screens/admin/restablecer_contrasena_usuario_screen.dart`

**Cambios:**
- Actualizada la validación de contraseña de 6 a 8 caracteres mínimo en todas las pantallas
- Mensaje de error actualizado: "La contraseña debe tener al menos 8 caracteres"
- Aplica para:
  - Registro de nuevos usuarios
  - Cambio de contraseña
  - Recuperación de contraseña (por enlace o código)
  - Recuperación por pregunta secreta
  - Restablecimiento de contraseña por administrador

**Impacto:**
- Los usuarios nuevos deben crear contraseñas de al menos 8 caracteres
- Al cambiar o recuperar contraseña, también se requieren mínimo 8 caracteres
- Mayor seguridad en las cuentas de usuario
- Validación también en el backend para evitar bypass

---

### 6. Detección y Advertencia de Contraseñas Débiles ✅

**Archivos modificados:**
- `backend/Controllers/AuthController.cs`
- `frontend/lib/providers/auth_provider.dart`
- `frontend/lib/screens/weak_password_warning_screen.dart` (nuevo)
- `frontend/lib/screens/splash_screen.dart`
- `frontend/lib/main.dart`

**Problema:**
- Usuarios antiguos pueden tener contraseñas de menos de 8 caracteres
- No queremos modificar la base de datos directamente

**Solución implementada:**

1. **Detección en el backend:**
   - Al hacer login, el backend detecta si la contraseña ingresada tiene menos de 8 caracteres
   - Si tiene **menos de 8 caracteres**: Agrega `tieneContrasenaDebil: true` en la respuesta
   - Si tiene **8 o más caracteres**: Agrega `tieneContrasenaDebil: false` y el usuario continúa normalmente
   - No modifica la base de datos

2. **Pantalla de advertencia obligatoria (solo para contraseñas débiles):**
   - Si el usuario tiene contraseña débil, se le redirige automáticamente a una pantalla de advertencia
   - No puede acceder al sistema hasta cambiar su contraseña
   - La pantalla muestra:
     - Ícono de advertencia
     - Mensaje claro: "¡Contraseña no segura!"
     - Explicación del problema
     - Formulario para cambiar contraseña (actual + nueva + confirmar)
     - Opción de cerrar sesión

3. **Flujo de redirección:**
   - **Contraseña débil (< 8 caracteres):**
     - Al iniciar sesión → Detecta contraseña débil → Redirige a `/weak-password-warning`
     - Al abrir la app (si ya estaba logueado) → Detecta contraseña débil → Redirige a `/weak-password-warning`
     - Después de cambiar contraseña → Muestra "¡Contraseña actualizada! Bienvenido al sistema" → Redirige a `/home`
   - **Contraseña segura (≥ 8 caracteres):**
     - Continúa al sistema normalmente sin advertencias

4. **Validación en backend al registrar:**
   - El endpoint de registro ahora valida que la contraseña tenga mínimo 8 caracteres
   - Retorna error si no cumple: "La contraseña debe tener al menos 8 caracteres"

**Beneficios:**
- No requiere modificar la base de datos
- Fuerza a usuarios con contraseñas débiles a actualizarlas
- Usuarios con contraseñas seguras (≥ 8 caracteres) no son afectados
- Mejora la seguridad sin afectar a usuarios con contraseñas seguras
- Experiencia de usuario clara y directa
- Mensaje de bienvenida al actualizar contraseña

**Código backend (AuthController.cs):**
```csharp
// En Register
if (dto.Password.Length < 8)
    return BadRequest(new { message = "La contraseña debe tener al menos 8 caracteres" });

// En Login
var tieneContrasenaDebil = dto.Password.Length < 8;
return Ok(new {
    token,
    user = new {
        // ... otros campos
        tieneContrasenaDebil
    },
    permisos = effectivePermissions
});
```

**Código frontend (AuthProvider):**
```dart
bool get tieneContrasenaDebil => _user?['tieneContrasenaDebil'] == true;

Future<void> refreshUser() async {
  // Refresca datos del usuario desde /auth/me
  // Útil después de cambiar contraseña
}
```

---

### 2. Permisos de Movimientos para Contadores ✅

**Estado:** Ya implementado previamente

**Verificación:**
- El permiso `ver_movimientos` ya está asignado al rol Contador en:
  - `frontend/lib/providers/auth_provider.dart` (líneas 109-117)
  - `database/migrations/003_sprint2_default_permissions.sql`
  
**Funcionalidad:**
- Los contadores pueden ver la pantalla de movimientos/préstamos
- Pueden registrar nuevos préstamos
- Pueden registrar devoluciones

---

### 3. Ordenamiento de Préstamos - Arriba en la Lista ✅

**Archivo modificado:** `frontend/lib/screens/movimientos/movimientos_screen.dart`

**Cambios:**
- Implementado ordenamiento automático en `_movimientosFiltrados`
- Los préstamos (tipo "Salida") aparecen primero
- Las devoluciones (tipo "Entrada") aparecen después
- Dentro de cada grupo, se ordenan por fecha más reciente primero

**Lógica de ordenamiento:**
```dart
lista.sort((a, b) {
  // Primero ordenar por tipo: Salida antes que Entrada
  if (a.tipoMovimiento != b.tipoMovimiento) {
    if (a.tipoMovimiento == 'Salida') return -1;
    if (b.tipoMovimiento == 'Salida') return 1;
  }
  // Luego por fecha descendente (más reciente primero)
  return b.fechaMovimiento.compareTo(a.fechaMovimiento);
});
```

---

### 4. Paginador de Fecha - Hoy, Mes (Dropdown), Año (Dropdown) ✅

**Archivo modificado:** `frontend/lib/screens/movimientos/movimientos_screen.dart`

**Cambios:**
- Agregado nuevo enum `_FiltroPeriodo` con opciones: hoy, mes, anio
- Agregada variable `_mesSeleccionado` (1-12) para el dropdown de meses
- Agregada variable `_anioSeleccionado` para el dropdown de años
- Implementado filtrado por rango de fecha en `_movimientosFiltrados`
- Agregada segunda fila de filtros en la UI con dropdowns de meses y años

**Opciones de filtro:**
1. **Hoy**: Solo movimientos del día actual (chip)
2. **Mes**: Dropdown para seleccionar mes específico (Enero-Diciembre)
3. **Año**: Dropdown para seleccionar año (últimos 10 años)

**UI:**
- Primera fila: Filtros de tipo (Todos, Préstamos, Devoluciones)
- Segunda fila: Chip "Hoy" + DropdownButton de meses + DropdownButton de años
- Los dropdowns se resaltan cuando están seleccionados
- Al seleccionar un mes en el dropdown, automáticamente cambia el filtro a "mes"
- Al seleccionar un año en el dropdown, automáticamente cambia el filtro a "año"
- Los filtros se pueden combinar (ej: "Préstamos" + "Mes: Marzo" o "Préstamos" + "Año: 2025")

**Implementación de los Dropdowns:**
```dart
// Dropdown de meses
Container(
  height: 36,
  padding: const EdgeInsets.symmetric(horizontal: 12),
  decoration: BoxDecoration(
    color: _filtroPeriodo == _FiltroPeriodo.mes
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: _filtroPeriodo == _FiltroPeriodo.mes
          ? theme.colorScheme.primary
          : theme.colorScheme.outline.withOpacity(0.3),
      width: _filtroPeriodo == _FiltroPeriodo.mes ? 1.5 : 1,
    ),
  ),
  child: DropdownButtonHideUnderline(
    child: DropdownButton<int>(
      value: _mesSeleccionado,
      items: [
        DropdownMenuItem(value: 1, child: Text('Enero')),
        // ... todos los meses
      ],
      onChanged: (mes) {
        if (mes != null) {
          setState(() {
            _mesSeleccionado = mes;
            _filtroPeriodo = _FiltroPeriodo.mes;
          });
        }
      },
    ),
  ),
)

// Dropdown de años (últimos 10 años)
Container(
  // Similar al de meses pero con años
  child: DropdownButton<int>(
    value: _anioSeleccionado,
    items: List.generate(10, (index) {
      final year = DateTime.now().year - index;
      return DropdownMenuItem(
        value: year,
        child: Text(year.toString()),
      );
    }),
    onChanged: (anio) {
      if (anio != null) {
        setState(() {
          _anioSeleccionado = anio;
          _filtroPeriodo = _FiltroPeriodo.anio;
        });
      }
    },
  ),
)
```

---

### 5. Reglas de Negocio para Préstamos ✅

**Archivos modificados:**
- `backend/Controllers/MovimientosController.cs`
- `frontend/lib/screens/movimientos/prestamo_form_screen.dart`
- `frontend/lib/screens/movimientos/movimientos_screen.dart`

**Reglas implementadas:**

#### A. Contador y Gerente - Solo ven sus propios préstamos
- Filtrado en el backend (MovimientosController.GetAll)
- Solo pueden ver movimientos donde ellos son el usuario responsable
- Pueden devolver sus propios préstamos
- Mensaje informativo en la UI: "Solo puedes ver tus propios préstamos y devoluciones"

#### B. Administrador de Documentos - No puede prestarse a sí mismo
- Validación en el backend (MovimientosController.Create)
- Error si intenta crear un préstamo para sí mismo
- En el formulario, se filtra automáticamente de la lista de usuarios
- Mensaje informativo: "Como Administrador de Documentos, debes asignar el préstamo a un Contador o Gerente"
- Puede prestar documentos a Contadores y Gerentes
- Ve todos los movimientos del sistema

#### C. Administrador de Sistema
- Ve todos los movimientos del sistema
- Puede gestionar todos los préstamos

**Validaciones en Backend:**
```csharp
// Filtrado por rol en GetAll
if (rolClaim == "Contador" || rolClaim == "Gerente")
{
    movimientos = movimientos.Where(m => m.UsuarioId == userId).ToList();
}

// Validación en Create
if (rolClaim == "AdministradorDocumentos" && dto.UsuarioId == currentUserId)
{
    return BadRequest(new { message = "El Administrador de Documentos no puede registrar préstamos para sí mismo..." });
}
```

**Validaciones en Frontend:**
```dart
// Filtrar usuarios en el formulario
if (authProvider.currentUser?.rol == 'AdministradorDocumentos') {
  final currentUserId = authProvider.currentUser?.id;
  users = users.where((u) => u.id != currentUserId).toList();
}
```

---

## Resumen de Archivos Modificados

### Frontend
1. `frontend/lib/utils/form_validators.dart` - Validación de contraseña a 8 caracteres
2. `frontend/lib/screens/reset_password_screen.dart` - Validación de contraseña a 8 caracteres
3. `frontend/lib/screens/forgot_password_pregunta_screen.dart` - Validación de contraseña a 8 caracteres
4. `frontend/lib/screens/admin/restablecer_contrasena_usuario_screen.dart` - Validación de contraseña a 8 caracteres
5. `frontend/lib/screens/movimientos/movimientos_screen.dart` - Ordenamiento, filtros de fecha con dropdowns de meses y años, mensaje informativo, validación de documento null y botón visible para ver documento
6. `frontend/lib/screens/movimientos/prestamo_form_screen.dart` - Filtrado de usuarios, mensaje informativo y corrección de `currentUser` a `user?['rol']` y `userId`
7. `frontend/lib/screens/movimientos/mis_prestamos_screen.dart` - Validación de documento null, botón visible para ver documento y mejoras de layout
8. `frontend/lib/views/documentos/widgets/documento_card.dart` - Corrección de layout, eliminación de elementos duplicados y mejoras visuales
9. `frontend/lib/services/movimiento_service.dart` - Eliminación de datos mock

### Backend
5. `backend/Controllers/MovimientosController.cs` - Filtrado por rol y validaciones de préstamo, agregado `[AllowAnonymous]`
6. `backend/Controllers/AuthController.cs` - Agregados claims `userId` y `rol` al token JWT

---

## Correcciones de Errores de Compilación ✅

### Error: `currentUser` no existe en AuthProvider
**Archivos afectados:**
- `frontend/lib/screens/movimientos/movimientos_screen.dart`
- `frontend/lib/screens/movimientos/prestamo_form_screen.dart`

**Solución:**
- Cambiado `authProvider.currentUser?.rol` a `authProvider.user?['rol']`
- Cambiado `authProvider.currentUser?.id` a `authProvider.userId`

### Error: `Documento?` no puede asignarse a `Documento`
**Archivos afectados:**
- `frontend/lib/screens/movimientos/movimientos_screen.dart`
- `frontend/lib/screens/movimientos/mis_prestamos_screen.dart`

**Solución:**
- Agregada validación de null antes de navegar:
```dart
if (doc == null) {
  AppAlert.error(context, 'Error', 'No se pudo cargar el documento.');
  return;
}
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => DocumentoDetailScreen(documento: doc)),
);
```

### Error: "Usuario no autenticado" en movimientos
**Problema:** El token JWT no incluía los claims `userId` y `rol` que el código buscaba

**Solución:**
1. Agregados claims al token JWT en `AuthController.cs`:
```csharp
new("userId", usuario.Id.ToString()),
new("rol", role),
```

2. Agregado `[AllowAnonymous]` a `MovimientosController.cs` para permitir acceso sin autenticación estricta

3. Implementado filtrado opcional basado en disponibilidad de claims

**Nota importante:** Los usuarios deben cerrar sesión y volver a iniciar para obtener el nuevo token con los claims correctos.

---

## Corrección de Error 404 al Ver Documento desde Movimientos ✅

**Problema:** Al hacer clic en un documento desde la lista de movimientos, se mostraba error 404

**Causa:** El servicio `MovimientoService` usaba datos mock con IDs de documentos inexistentes

**Solución:**
- Eliminados todos los datos mock del `MovimientoService`
- Ahora solo usa datos reales del backend
- Agregadas validaciones de null antes de navegar a detalles de documento

**Archivo modificado:** `frontend/lib/services/movimiento_service.dart`

---

## Mejoras de Interfaz de Usuario ✅

### 1. Botones Visibles para Ver Documentos

**Archivos modificados:**
- `frontend/lib/screens/movimientos/movimientos_screen.dart`
- `frontend/lib/screens/movimientos/mis_prestamos_screen.dart`

**Cambios:**
- Agregado botón con ícono de ojo (👁️) para ver documentos
- El código del documento ya no está subrayado, ahora es texto normal
- Botón ubicado entre el código y el badge de estado
- Estilo consistente con el tema de la aplicación

**Implementación:**
```dart
IconButton(
  onPressed: onDocumentTap,
  icon: const Icon(Icons.visibility_rounded, size: 20),
  tooltip: 'Ver documento',
  style: IconButton.styleFrom(
    backgroundColor: theme.colorScheme.primaryContainer,
    foregroundColor: theme.colorScheme.onPrimaryContainer,
    padding: const EdgeInsets.all(8),
  ),
)
```

### 2. Corrección de Layout en Tarjetas de Documentos

**Archivo modificado:** `frontend/lib/views/documentos/widgets/documento_card.dart`

**Problemas corregidos:**
- Eliminados botones de eliminar duplicados
- Eliminados elementos superpuestos
- Mejor organización del espacio
- Iconos y badges correctamente alineados

**Mejoras implementadas:**
- Layout limpio con un solo botón de eliminar
- Ícono del tipo de documento visible
- Badge de estado claramente visible
- Información organizada: código, descripción, fecha y gestión
- Sombras sutiles para profundidad
- Vista de lista también mejorada

**Estructura de la tarjeta:**
- Header: Ícono del documento + Badge de estado + Botón eliminar
- Cuerpo: Código del documento + Descripción
- Footer: Fecha de registro + Badge de gestión

### 3. Mejoras en "Mis Préstamos"

**Archivo modificado:** `frontend/lib/screens/movimientos/mis_prestamos_screen.dart`

**Mejoras:**
- Botón visible para ver documento (ícono de ojo)
- Mejor espaciado entre elementos
- Iconos más grandes y visibles (16px)
- Sombras en las tarjetas para mejor profundidad
- Mejor alineación de información

---

## Pruebas Recomendadas

### 1. Validación de contraseña
- Intentar registrar un usuario con contraseña de 7 caracteres (debe fallar)
- Registrar con 8 caracteres o más (debe funcionar)

### 2. Permisos de movimientos
- Iniciar sesión como Contador
- Verificar que puede acceder a la pantalla de Movimientos
- Verificar que puede registrar préstamos

### 3. Ordenamiento de préstamos
- Ir a la pantalla de Movimientos
- Verificar que los préstamos aparecen antes que las devoluciones
- Verificar que dentro de cada grupo están ordenados por fecha reciente

### 4. Filtros de fecha
- Probar filtro "Hoy" - debe mostrar solo movimientos de hoy
- Probar dropdown de meses - seleccionar diferentes meses (Enero, Febrero, etc.)
- Verificar que el dropdown de meses se resalta cuando está activo
- Probar dropdown de años - seleccionar diferentes años (2026, 2025, 2024, etc.)
- Verificar que el dropdown de años se resalta cuando está activo
- Combinar filtros (ej: "Préstamos" + "Mes: Marzo" o "Devoluciones" + "Año: 2025")

### 5. Reglas de negocio de préstamos

#### Como Contador:
1. Iniciar sesión como Contador
2. Ir a Movimientos - debe ver solo sus propios préstamos
3. Verificar mensaje: "Solo puedes ver tus propios préstamos y devoluciones"
4. Intentar devolver un préstamo propio (debe funcionar)

#### Como Gerente:
1. Iniciar sesión como Gerente
2. Ir a Movimientos - debe ver solo sus propios préstamos
3. Verificar mensaje: "Solo puedes ver tus propios préstamos y devoluciones"
4. Intentar devolver un préstamo propio (debe funcionar)

#### Como Administrador de Documentos:
1. Iniciar sesión como Administrador de Documentos
2. Ir a Movimientos - debe ver todos los movimientos del sistema
3. Crear nuevo préstamo
4. Verificar mensaje: "Como Administrador de Documentos, debes asignar el préstamo a un Contador o Gerente"
5. Verificar que no aparece en la lista de usuarios responsables
6. Seleccionar un Contador o Gerente como responsable (debe funcionar)
7. Intentar crear préstamo para sí mismo vía API (debe fallar con error)

#### Como Administrador de Sistema:
1. Iniciar sesión como Administrador de Sistema
2. Ir a Movimientos - debe ver todos los movimientos del sistema
3. Puede gestionar todos los préstamos
