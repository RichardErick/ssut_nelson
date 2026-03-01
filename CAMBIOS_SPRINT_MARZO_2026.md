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

### 4. Paginador de Fecha - Hoy, Mes, Año ✅

**Archivo modificado:** `frontend/lib/screens/movimientos/movimientos_screen.dart`

**Cambios:**
- Agregado nuevo enum `_FiltroFecha` con opciones: todos, hoy, mes, anio
- Implementado filtrado por rango de fecha en `_movimientosFiltrados`
- Agregada segunda fila de chips de filtro en la UI

**Opciones de filtro:**
1. **Todos**: Muestra todos los movimientos (sin filtro de fecha)
2. **Hoy**: Solo movimientos del día actual
3. **Este mes**: Solo movimientos del mes actual
4. **Este año**: Solo movimientos del año actual

**UI:**
- Primera fila: Filtros de tipo (Todos, Préstamos, Devoluciones)
- Segunda fila: Filtros de fecha (Todos, Hoy, Este mes, Este año)
- Los filtros se pueden combinar (ej: "Préstamos" + "Este mes")

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
2. `frontend/lib/screens/movimientos/movimientos_screen.dart` - Ordenamiento, filtros de fecha y mensaje informativo
3. `frontend/lib/screens/movimientos/prestamo_form_screen.dart` - Filtrado de usuarios y mensaje informativo

### Backend
4. `backend/Controllers/MovimientosController.cs` - Filtrado por rol y validaciones de préstamo

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
- Probar filtro "Este mes" - debe mostrar movimientos del mes actual
- Probar filtro "Este año" - debe mostrar movimientos del año actual
- Combinar filtros (ej: "Préstamos" + "Este mes")

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
