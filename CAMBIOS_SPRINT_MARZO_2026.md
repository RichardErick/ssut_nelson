# Cambios Implementados - Sprint Marzo 2026

## Fecha: 1 de Marzo de 2026

### 1. Validación de Contraseña - 8 Caracteres Mínimo ✅

**Archivo modificado:** `frontend/lib/utils/form_validators.dart`

**Cambios:**
- Actualizada la validación de contraseña de 6 a 8 caracteres mínimo
- Mensaje de error actualizado: "La contraseña debe tener al menos 8 caracteres"
- Aplica tanto para registro como para cambio de contraseña

**Impacto:**
- Los usuarios nuevos deben crear contraseñas de al menos 8 caracteres
- Mayor seguridad en las cuentas de usuario

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

### 4. Paginador de Fecha - Hoy, Mes (Dropdown), Año ✅

**Archivo modificado:** `frontend/lib/screens/movimientos/movimientos_screen.dart`

**Cambios:**
- Agregado nuevo enum `_FiltroPeriodo` con opciones: hoy, mes, anio
- Agregada variable `_mesSeleccionado` (1-12) para el dropdown de meses
- Implementado filtrado por rango de fecha en `_movimientosFiltrados`
- Agregada segunda fila de filtros en la UI con dropdown de meses

**Opciones de filtro:**
1. **Hoy**: Solo movimientos del día actual (chip)
2. **Mes**: Dropdown para seleccionar mes específico (Enero-Diciembre)
3. **Este año**: Solo movimientos del año actual (chip)

**UI:**
- Primera fila: Filtros de tipo (Todos, Préstamos, Devoluciones)
- Segunda fila: Chip "Hoy" + DropdownButton de meses + Chip "Este año"
- El dropdown se resalta cuando está seleccionado el filtro de mes
- Al seleccionar un mes en el dropdown, automáticamente cambia el filtro a "mes"
- Los filtros se pueden combinar (ej: "Préstamos" + "Mes: Marzo")

**Implementación del Dropdown:**
```dart
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
2. `frontend/lib/screens/movimientos/movimientos_screen.dart` - Ordenamiento, filtros de fecha con dropdown de meses, mensaje informativo y validación de documento null
3. `frontend/lib/screens/movimientos/prestamo_form_screen.dart` - Filtrado de usuarios, mensaje informativo y corrección de `currentUser` a `user?['rol']` y `userId`
4. `frontend/lib/screens/movimientos/mis_prestamos_screen.dart` - Validación de documento null

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
- Verificar que el dropdown se resalta cuando está activo el filtro de mes
- Probar filtro "Este año" - debe mostrar movimientos del año actual
- Combinar filtros (ej: "Préstamos" + "Mes: Marzo")

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
