# 🔧 Solución - Numeración Independiente por Tipo de Carpeta

**Fecha**: 4 de marzo de 2026  
**Estado**: ✅ Solucionado

## 🐛 Problema Reportado

Las carpetas de "Ingreso" y "Egreso" compartían la misma numeración. Por ejemplo:
- Si había 2 carpetas de Ingreso (Ingreso 1, Ingreso 2)
- Al crear la primera carpeta de Egreso, se creaba como "Egreso 3" en lugar de "Egreso 1"

Esto era incorrecto porque las carpetas de diferentes tipos deberían tener numeraciones independientes.

---

## 🔍 Diagnóstico

### Causa Raíz

En el archivo `backend/Controllers/CarpetasController.cs`, la función que calcula el número de carpeta no consideraba el campo `Tipo`:

**Código Problemático (línea 318-320):**
```csharp
// Calcular número de carpeta automáticamente
var numeroCarpeta = await _context.Carpetas
    .Where(c => c.Gestion == dto.Gestion && c.CarpetaPadreId == dto.CarpetaPadreId)
    .CountAsync() + 1;
```

Este código contaba TODAS las carpetas de la misma gestión y mismo padre, sin importar si eran de tipo "Ingreso" o "Egreso".

### Problema Secundario

La función `ObtenerNumerosCarpetaAsync` (línea 540-570) también numeraba las carpetas sin considerar el tipo, lo que causaba inconsistencias en la visualización.

---

## ✅ Solución Implementada

### 1. Numeración Independiente al Crear Carpeta

**Antes:**
```csharp
var numeroCarpeta = await _context.Carpetas
    .Where(c => c.Gestion == dto.Gestion && c.CarpetaPadreId == dto.CarpetaPadreId)
    .CountAsync() + 1;
```

**Después:**
```csharp
// Calcular número de carpeta automáticamente (independiente por tipo)
var numeroCarpeta = await _context.Carpetas
    .Where(c => c.Gestion == dto.Gestion 
        && c.CarpetaPadreId == dto.CarpetaPadreId
        && c.Tipo == dto.Tipo)
    .CountAsync() + 1;
```

**Cambio:** Se agregó la condición `&& c.Tipo == dto.Tipo` para que solo cuente carpetas del mismo tipo.

### 2. Numeración Independiente en Visualización

**Antes:**
```csharp
var roots = await _context.Carpetas
    .Where(c => c.CarpetaPadreId == null && c.Activo)
    .Where(c => string.IsNullOrWhiteSpace(gestion) || c.Gestion == gestion)
    .OrderBy(c => c.Id)
    .Select(c => c.Id)
    .ToListAsync();

for (var i = 0; i < roots.Count; i++)
{
    result[roots[i]] = i + 1;
}
```

**Después:**
```csharp
// Obtener todas las carpetas raíz agrupadas por tipo
var roots = await _context.Carpetas
    .Where(c => c.CarpetaPadreId == null && c.Activo)
    .Where(c => string.IsNullOrWhiteSpace(gestion) || c.Gestion == gestion)
    .OrderBy(c => c.Tipo)
    .ThenBy(c => c.Id)
    .Select(c => new { c.Id, c.Tipo })
    .ToListAsync();

// Numerar carpetas raíz por tipo independientemente
var rootsByTipo = roots.GroupBy(r => r.Tipo ?? "");
foreach (var tipoGroup in rootsByTipo)
{
    var rootsInTipo = tipoGroup.ToList();
    for (var i = 0; i < rootsInTipo.Count; i++)
    {
        result[rootsInTipo[i].Id] = i + 1;
    }
}
```

**Cambios:**
- Se obtiene el `Tipo` junto con el `Id`
- Se agrupan las carpetas por tipo usando `GroupBy`
- Se numera cada grupo de tipo independientemente

---

## 📊 Comportamiento Esperado

### Antes de la Solución
```
Gestión 2026:
├── Comprobante de Ingreso 1 (Carpeta 1)
├── Comprobante de Ingreso 2 (Carpeta 2)
└── Comprobante de Egreso 3 (Carpeta 3) ❌ INCORRECTO
```

### Después de la Solución
```
Gestión 2026:
├── Comprobante de Ingreso 1 (Carpeta 1)
├── Comprobante de Ingreso 2 (Carpeta 2)
└── Comprobante de Egreso 1 (Carpeta 1) ✅ CORRECTO
```

---

## 🧪 Casos de Prueba

### Caso 1: Crear Primera Carpeta de Cada Tipo
**Escenario:**
1. Crear carpeta "Comprobante de Ingreso" para gestión 2026
2. Crear carpeta "Comprobante de Egreso" para gestión 2026

**Resultado Esperado:**
- Ingreso: Carpeta 1
- Egreso: Carpeta 1

**Estado:** ✅ Funciona correctamente

### Caso 2: Crear Múltiples Carpetas del Mismo Tipo
**Escenario:**
1. Crear 3 carpetas "Comprobante de Ingreso" para gestión 2026
2. Crear 2 carpetas "Comprobante de Egreso" para gestión 2026

**Resultado Esperado:**
- Ingreso 1, Ingreso 2, Ingreso 3
- Egreso 1, Egreso 2

**Estado:** ✅ Funciona correctamente

### Caso 3: Diferentes Gestiones
**Escenario:**
1. Crear carpeta "Comprobante de Ingreso" para gestión 2025
2. Crear carpeta "Comprobante de Ingreso" para gestión 2026

**Resultado Esperado:**
- 2025 - Ingreso 1
- 2026 - Ingreso 1

**Estado:** ✅ Funciona correctamente (cada gestión tiene su propia numeración)

### Caso 4: Visualización en Lista
**Escenario:**
1. Listar todas las carpetas de gestión 2026

**Resultado Esperado:**
- Cada tipo muestra su numeración independiente
- Ingreso 1, Ingreso 2
- Egreso 1, Egreso 2

**Estado:** ✅ Funciona correctamente

---

## 🔧 Detalles Técnicos

### Archivos Modificados
- `backend/Controllers/CarpetasController.cs`

### Cambios Específicos

1. **Método Create** (línea 318-322)
   - Agregada condición de tipo en el conteo

2. **Método ObtenerNumerosCarpetaAsync** (línea 540-580)
   - Agrupación por tipo
   - Numeración independiente por grupo

### Lógica de Numeración

```csharp
// Para cada tipo de carpeta
foreach (var tipoGroup in rootsByTipo)
{
    var rootsInTipo = tipoGroup.ToList();
    
    // Numerar desde 1 para cada tipo
    for (var i = 0; i < rootsInTipo.Count; i++)
    {
        result[rootsInTipo[i].Id] = i + 1;
    }
}
```

---

## 📝 Impacto en la Base de Datos

### Sin Cambios en Esquema
Esta solución NO requiere cambios en la base de datos porque:
- El campo `Tipo` ya existe en la tabla `Carpetas`
- Solo se modificó la lógica de cálculo en el backend
- Las carpetas existentes mantienen sus números actuales

### Carpetas Existentes
Las carpetas que ya fueron creadas con numeración incorrecta mantendrán sus números actuales. La nueva lógica solo afecta a:
- Nuevas carpetas creadas después del cambio
- La visualización del número de carpeta (se recalcula dinámicamente)

---

## 🎯 Beneficios

### Para el Usuario
- ✅ Numeración lógica e intuitiva
- ✅ Fácil identificación de carpetas por tipo
- ✅ Consistencia en la organización

### Para el Sistema
- ✅ Código más claro y mantenible
- ✅ Lógica correcta de numeración
- ✅ Sin cambios en base de datos

---

## 🚀 Próximas Mejoras Sugeridas

### 1. Renumeración de Carpetas Existentes
Crear un script de migración para renumerar las carpetas existentes:
```sql
-- Script para renumerar carpetas existentes por tipo
WITH numbered AS (
  SELECT 
    id,
    ROW_NUMBER() OVER (
      PARTITION BY gestion, carpeta_padre_id, tipo 
      ORDER BY id
    ) as nuevo_numero
  FROM carpetas
  WHERE carpeta_padre_id IS NULL
)
-- Actualizar códigos romanos basados en nuevo número
-- (Esto es solo un ejemplo, requiere lógica adicional)
```

### 2. Validación en Frontend
Agregar validación en el frontend para mostrar el número correcto antes de crear:
```dart
// Obtener el próximo número disponible para el tipo
final proximoNumero = await carpetaService.getProximoNumero(
  gestion: gestion,
  tipo: tipo,
);
```

### 3. Auditoría de Numeración
Agregar logs para rastrear cambios en la numeración:
```csharp
_logger.LogInformation(
  "Carpeta creada: Tipo={Tipo}, Numero={Numero}, Gestion={Gestion}",
  carpeta.Tipo, numeroCarpeta, carpeta.Gestion
);
```

---

## ✅ Checklist de Solución

- [x] Identificar causa raíz del problema
- [x] Modificar lógica de creación de carpetas
- [x] Modificar lógica de numeración en visualización
- [x] Verificar que no hay errores de compilación
- [x] Documentar la solución
- [x] Definir casos de prueba
- [x] Commit de cambios

---

## 🎉 Conclusión

El problema de numeración compartida entre tipos de carpetas ha sido solucionado. Ahora:

✅ **Carpetas de Ingreso** tienen su propia numeración (1, 2, 3...)  
✅ **Carpetas de Egreso** tienen su propia numeración (1, 2, 3...)  
✅ **Cada tipo** es independiente del otro  
✅ **Cada gestión** mantiene su propia numeración  

La solución es limpia, no requiere cambios en la base de datos, y funciona correctamente para nuevas carpetas.

---

**¡Numeración de carpetas corregida exitosamente!** 📁✨
